import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import '../models/sync_tracker.dart';
import '../services/kpi_sync_service.dart';
import '../services/api_services.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../../../initialise/splashscreen.dart';

/// MonDataSyncController
/// 
/// Controller that orchestrates the staged data synchronization process.
/// Manages sync state and provides progress updates to the UI.
class MonDataSyncController extends GetxController {
  final KpiSyncService _kpiSyncService = Get.find<KpiSyncService>();
  final MonitorApiService _apiService = Get.find<MonitorApiService>();
  final UnifiedDatabaseHelper _dbHelper = UnifiedDatabaseHelper.instance;

  // Sync state observables
  final isSyncing = false.obs;
  final syncProgress = 0.0.obs;           // 0.0 to 1.0
  final syncStatusMessage = ''.obs;       // Current status message
  final syncPhase = SyncPhase.idle.obs;   // Current sync phase
  final hasSyncError = false.obs;
  final syncErrorMessage = ''.obs;

  // Sync result tracking
  final recordsFetched = 0.obs;
  final lastSyncTime = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    _loadLastSyncTime();
  }

  Future<void> _loadLastSyncTime() async {
    try {
      lastSyncTime.value = await _dbHelper.getLastSyncTimestamp();
    } catch (e) {
      debugPrint('[MonDataSyncController] Error loading last sync time: $e');
    }
  }

  /// Gets the current sync state as an immutable object
  SyncState getSyncState() {
    return SyncState(
      phase: syncPhase.value,
      progress: syncProgress.value,
      message: syncStatusMessage.value,
      recordsFetched: recordsFetched.value,
      lastSyncTime: lastSyncTime.value,
      errorMessage: hasSyncError.value ? syncErrorMessage.value : null,
    );
  }

  /// Executes the complete staged sync process.
  /// Called from SplashPage during initialization.
  Future<void> performInitialSync() async {
    if (isSyncing.value) {
      debugPrint('[MonDataSyncController] Sync already in progress, skipping');
      return;
    }

    isSyncing.value = true;
    hasSyncError.value = false;
    syncProgress.value = 0.0;
    syncPhase.value = SyncPhase.kpiFetch;

    try {
      // Phase 1: Fetch today's KPI metrics (priority)
      await _fetchTodayKpiMetrics();
      syncProgress.value = 0.3;

      // Phase 2: Fetch baseline datasets (concurrent)
      syncPhase.value = SyncPhase.baselineFetch;
      await _fetchBaselineDatasets();
      syncProgress.value = 0.6;

      // Phase 3: Record sync completion
      syncPhase.value = SyncPhase.complete;
      await _recordSyncCompletion();
      syncProgress.value = 1.0;

      debugPrint('[MonDataSyncController] Initial sync completed successfully');

    } catch (e) {
      hasSyncError.value = true;
      syncErrorMessage.value = e.toString();
      syncPhase.value = SyncPhase.error;
      debugPrint('[MonDataSyncController] Initial sync failed: $e');
    } finally {
      isSyncing.value = false;
    }
  }

  /// Executes initial sync with ONLY today's KPI + baseline data.
  /// This is used on first app launch to get minimal data for the UI.
  /// Historical data is fetched later via pull-to-refresh on respective pages.
  Future<void> performInitialSyncWithBaseline() async {
    if (isSyncing.value) {
      debugPrint('[MonDataSyncController] Sync already in progress, skipping');
      return;
    }

    isSyncing.value = true;
    hasSyncError.value = false;
    syncProgress.value = 0.0;
    syncPhase.value = SyncPhase.kpiFetch;

    try {
      // Phase 1: Fetch today's KPI metrics only
      syncStatusMessage.value = 'Fetching today\'s metrics...';
      await _fetchTodayKpiMetrics();
      syncProgress.value = 0.4;

      // Phase 2: Fetch baseline datasets (service points, inventory, company details)
      syncPhase.value = SyncPhase.baselineFetch;
      syncStatusMessage.value = 'Syncing baseline data...';
      await _fetchAndStoreBaselineData();
      syncProgress.value = 0.8;

      // Phase 3: Record sync completion
      syncPhase.value = SyncPhase.complete;
      await _recordSyncCompletion();
      syncProgress.value = 1.0;

      debugPrint('[MonDataSyncController] Initial sync with baseline completed successfully');

    } catch (e) {
      hasSyncError.value = true;
      syncErrorMessage.value = e.toString();
      syncPhase.value = SyncPhase.error;
      debugPrint('[MonDataSyncController] Initial sync with baseline failed: $e');
    } finally {
      isSyncing.value = false;
    }
  }

  /// Fetch and store baseline data (service points, inventory, company details)
  Future<void> _fetchAndStoreBaselineData() async {
    try {
      final result = await _kpiSyncService.fetchBaselineDatasets();
      
      // Store service points to database
      if (result.servicePoints.isNotEmpty) {
        // Filter service points to only include columns that exist in the local service_point table
        // service_point table schema: id, name, code, fullName, servicepointtype, facilityName, sales, stores, production, booking
        final servicePoints = result.servicePoints
            .map((e) {
              final sp = Map<String, dynamic>.from(e as Map);
              return {
                'id': sp['id'],
                'name': sp['name'],
                'code': sp['code'],
                'fullName': sp['fullName'] ?? sp['name'] ?? '',
                'servicepointtype': sp['servicepointtype'] ?? '',
                'facilityName': sp['facilityName'] ?? '',
                'sales': _toInt(sp['sales'] ?? 0),
                'stores': _toInt(sp['stores'] ?? 0),
                'production': _toInt(sp['production'] ?? 0),
                'booking': _toInt(sp['booking'] ?? 0),
              };
            })
            .toList();
        await _dbHelper.deleteAllMonServicePoints();
        await _dbHelper.insertServicePoints(servicePoints);
        debugPrint('[MonDataSyncController] Stored ${servicePoints.length} service points');
      }
      
      // Store company details to database
      if (result.companyDetails.isNotEmpty) {
        await _dbHelper.deleteAllCompanyDetails();
        await _dbHelper.insertCompanyDetails(result.companyDetails);
        debugPrint('[MonDataSyncController] Stored company details');
      }
      
      // Store inventory to database (chunked + batched to prevent memory exhaustion)
      if (result.inventory.isNotEmpty) {
        final totalItems = result.inventory.length;
        debugPrint('[MonDataSyncController] Processing $totalItems inventory items in chunks');
        
        await _dbHelper.deleteAllMonInventoryItems();
        
        // Process in chunks of 1000 for mapping, then insert in batches of 500
        const mapChunkSize = 1000;
        const insertBatchSize = 500;
        int stored = 0;
        
        for (int chunkStart = 0; chunkStart < totalItems; chunkStart += mapChunkSize) {
          final chunkEnd = (chunkStart + mapChunkSize < totalItems) 
              ? chunkStart + mapChunkSize 
              : totalItems;
          final chunk = result.inventory.sublist(chunkStart, chunkEnd);
          
          // Use compute() isolate for JSON map conversion to avoid main thread blocking
          final mappedChunk = await compute(
            (List<dynamic> items) => items
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
            chunk,
          );
          
          // Insert mapped chunk in smaller batches
          for (int i = 0; i < mappedChunk.length; i += insertBatchSize) {
            final batch = mappedChunk.skip(i).take(insertBatchSize).toList();
            await _dbHelper.insertMonInventoryItems(batch);
            stored += batch.length;
            debugPrint('[MonDataSyncController] Inventory progress: $stored/$totalItems');
            
            // Longer delay between batches for GC to run
            if (stored < totalItems) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
          }
          
          // Allow GC to collect the mapped chunk before processing next chunk
          await Future.delayed(const Duration(milliseconds: 50));
        }
        debugPrint('[MonDataSyncController] Stored $totalItems inventory items in chunks');
      }
      
      debugPrint('[MonDataSyncController] Baseline data fetch and store completed');
    } catch (e) {
      debugPrint('[MonDataSyncController] Baseline data fetch and store failed: $e');
      // Continue with cached data - not fatal
    }
  }

  /// Fetches historical data in background (12 months, monthly partitioned).
  /// Called after UI is mounted to avoid blocking the splash screen.
  Future<void> performHistoricalSyncInBackground() async {
    if (isSyncing.value) {
      debugPrint('[MonDataSyncController] Sync already in progress, skipping historical sync');
      return;
    }

    isSyncing.value = true;
    syncPhase.value = SyncPhase.historicalFetch;
    syncStatusMessage.value = 'Loading historical data...';

    try {
      await _kpiSyncService.fetchHistoricalData(
        monthsBack: 12,
        onProgress: (progress) {
          syncProgress.value = 0.6 + (progress * 0.4); // 60-100% range
        },
      );

      // Record historical sync completion
      await _dbHelper.insertSyncRecord(SyncRecord(
        syncType: 'historical',
        syncStatus: 'completed',
        completedAt: DateTime.now(),
        recordsFetched: recordsFetched.value,
      ));

      lastSyncTime.value = DateTime.now();
      syncPhase.value = SyncPhase.complete;
      debugPrint('[MonDataSyncController] Historical sync completed');

    } catch (e) {
      debugPrint('[MonDataSyncController] Historical sync failed: $e');
      // Non-critical - user can still use the app
      syncPhase.value = SyncPhase.complete;
    } finally {
      isSyncing.value = false;
    }
  }

  /// Performs incremental sync for subsequent app launches.
  Future<void> performIncrementalSync() async {
    syncStatusMessage.value = 'Checking for updates...';
    syncPhase.value = SyncPhase.kpiFetch;

    try {
      final result = await _kpiSyncService.performIncrementalSync();

      if (!result.wasSkipped) {
        recordsFetched.value = result.recordsFetched;
        lastSyncTime.value = result.lastSyncTimestamp ?? DateTime.now();
        debugPrint('[MonDataSyncController] Incremental sync completed: ${result.syncType}, ${result.recordsFetched} records');
      } else {
        debugPrint('[MonDataSyncController] Incremental sync skipped - cache still valid');
      }
    } catch (e) {
      debugPrint('[MonDataSyncController] Incremental KPI sync failed: $e');
    }

    // Also sync service points in incremental mode (they're small)
    syncPhase.value = SyncPhase.baselineFetch;
    syncStatusMessage.value = 'Syncing service points...';
    try {
      await _fetchAndStoreBaselineData();
    } catch (e) {
      debugPrint('[MonDataSyncController] Service points sync failed: $e');
    }
  }

  Future<void> _fetchTodayKpiMetrics() async {
    syncPhase.value = SyncPhase.kpiFetch;
    syncStatusMessage.value = 'Fetching today\'s metrics...';

    try {
      final results = await _kpiSyncService.fetchTodayKpiMetrics();
      recordsFetched.value = results.values.expand((e) => e).length;
      debugPrint('[MonDataSyncController] Fetched ${recordsFetched.value} KPI records for today');
    } catch (e) {
      debugPrint('[MonDataSyncController] KPI metrics fetch failed: $e');
      // Continue with empty data - not fatal
    }
  }

  Future<void> _fetchBaselineDatasets() async {
    syncPhase.value = SyncPhase.baselineFetch;
    syncStatusMessage.value = 'Syncing baseline data...';

    try {
      final result = await _kpiSyncService.fetchBaselineDatasets();
      debugPrint('[MonDataSyncController] Baseline sync completed: ${result.totalRecords} records');
    } catch (e) {
      debugPrint('[MonDataSyncController] Baseline data fetch failed: $e');
      // Continue with cached data - not fatal
    }
  }

  Future<void> _recordSyncCompletion() async {
    syncStatusMessage.value = 'Finalizing sync...';

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    await _dbHelper.insertSyncRecord(SyncRecord(
      syncType: 'staged',
      syncStatus: 'completed',
      completedAt: now,
      recordsFetched: recordsFetched.value,
      dateRangeStart: today,
      dateRangeEnd: today,
    ));

    lastSyncTime.value = now;
    debugPrint('[MonDataSyncController] Sync completion recorded');
  }

  /// Checks if sync is needed based on cache window
  Future<bool> isSyncNeeded({int cacheMinutes = 30}) async {
    return await _kpiSyncService.isSyncNeeded(cacheMinutes: cacheMinutes);
  }

  /// Perform offline login - loads data from local database without API calls
  /// 
  /// This method is used when the user is offline but has previously logged in.
  /// It loads all cached data from the local SQLite database into the controllers.
  /// 
  /// Returns true if data was loaded successfully, false if no cached data exists.
  Future<bool> performOfflineLogin() async {
    debugPrint('[MonDataSyncController] Starting offline login...');
    
    try {
      // Check if we have any cached data
      final hasData = await _checkCachedData();
      
      if (!hasData) {
        debugPrint('[MonDataSyncController] No cached data available for offline mode');
        return false;
      }
      
      // Load last sync time for display
      await _loadLastSyncTime();
      
      debugPrint('[MonDataSyncController] Offline login completed successfully');
      return true;
    } catch (e) {
      debugPrint('[MonDataSyncController] Offline login failed: $e');
      return false;
    }
  }

  /// Check if we have cached data in the database
  Future<bool> _checkCachedData() async {
    try {
      final db = _dbHelper.database;
      
      // Check if we have any sales data
      final salesCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM mon_sales',
      );
      final hasSales = (salesCount.first['count'] as int? ?? 0) > 0;
      
      // Check if we have service points
      final servicePointsCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM mon_service_points',
      );
      final hasServicePoints = (servicePointsCount.first['count'] as int? ?? 0) > 0;
      
      // Check if we have company details
      final companyCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM company_details',
      );
      final hasCompany = (companyCount.first['count'] as int? ?? 0) > 0;
      
      debugPrint(
        '[MonDataSyncController] Cached data check - Sales: $hasSales, '
        'ServicePoints: $hasServicePoints, Company: $hasCompany',
      );
      
      return hasSales || hasServicePoints || hasCompany;
    } catch (e) {
      debugPrint('[MonDataSyncController] Error checking cached data: $e');
      return false;
    }
  }

  /// Get a human-readable message showing when data was last synced
  /// 
  /// Returns a message like "Last synced: 5 minutes ago" or 
  /// "No cached data available. Please connect to the internet first."
  Future<String> getLastSyncMessage() async {
    final lastSync = await _dbHelper.getLastSyncTimestamp();
    
    if (lastSync == null) {
      return 'No cached data available. Please connect to the internet first.';
    }
    
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    String timeAgo;
    if (difference.inMinutes < 1) {
      timeAgo = 'just now';
    } else if (difference.inMinutes < 60) {
      timeAgo = '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      timeAgo = '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      timeAgo = '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
    
    return 'Last synced: $timeAgo';
  }

  /// Helper method to convert values to int for SQLite compatibility
  /// SQLite only supports num, String, and Uint8List - not bool
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }
}
