import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/sync_tracker.dart';
import '../services/api_services.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../../../back_pos/services/api_services.dart' as pos_api;

/// KPI Sync Service
/// 
/// Dedicated service for KPI data synchronization with monthly partitioning.
/// Handles today's KPI metrics fetch, historical data fetch, and incremental sync.
class KpiSyncService extends GetxService {
  static final KpiSyncService _instance = KpiSyncService._internal();
  static KpiSyncService get instance => _instance;

  final MonitorApiService _apiService = Get.find<MonitorApiService>();
  final UnifiedDatabaseHelper _dbHelper = UnifiedDatabaseHelper.instance;

  KpiSyncService();

  KpiSyncService._internal();

  /// KPI type definitions matching the API specification
  static const List<Map<String, dynamic>> kpiTypes = [
    {'id': 0, 'name': 'all_transactions'},
    {'id': 1, 'name': 'cash'},
    {'id': 2, 'name': 'pending_payment'},
    {'id': 3, 'name': 'payment_modes'},
    {'id': 4, 'name': 'salesperson'},
    {'id': 5, 'name': 'profit'},
    {'id': 6, 'name': 'efris_status'},
    {'id': 7, 'name': 'stock_category'},
    {'id': 8, 'name': 'by_item'},
  ];

  /// Fetches KPI metrics for the current day only.
  /// This is the first data fetch operation during splash screen.
  /// 
  /// Returns: Map of kpiId to list of records for quick access
  Future<Map<int, List<Map<String, dynamic>>>> fetchTodayKpiMetrics() async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    
    final results = <int, List<Map<String, dynamic>>>{};
    int totalRecords = 0;

    for (final kpiType in kpiTypes) {
      try {
        debugPrint('[KpiSyncService] Fetching KPI ${kpiType['name']} (id=${kpiType['id']}) for $today');
        
        final response = await _apiService.getWithAuth(
          '/sales/reports/kpi?startDate=$today&endDate=$today&kpiId=${kpiType['id']}&timeframe=1',
        );
        
        final data = await compute(_decodeJsonList, response.body);
        final records = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        
        results[kpiType['id'] as int] = records;
        totalRecords += records.length;
        
        debugPrint('[KpiSyncService] Fetched ${records.length} records for ${kpiType['name']}');
      } catch (e) {
        debugPrint('[KpiSyncService] Error fetching KPI ${kpiType['name']}: $e');
        results[kpiType['id'] as int] = [];
      }
    }

    // Store to database using the existing syncAllKpiData pattern
    if (totalRecords > 0) {
      try {
        await _apiService.syncAllKpiData(now, now);
        debugPrint('[KpiSyncService] Stored $totalRecords KPI records to database');
      } catch (e) {
        debugPrint('[KpiSyncService] Error storing KPI records: $e');
      }
    }

    return results;
  }

  /// Fetches historical KPI data for the past N months.
  /// Partitions data into monthly intervals to minimize server load.
  /// 
  /// [monthsBack] - Number of months to fetch (default: 12)
  /// [onProgress] - Callback for progress updates (0.0 to 1.0)
  Future<void> fetchHistoricalData({
    int monthsBack = 12,
    void Function(double progress)? onProgress,
  }) async {
    final now = DateTime.now();
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final totalMonths = monthsBack;
    int completedMonths = 0;

    debugPrint('[KpiSyncService] Starting historical data fetch for $totalMonths months');

    for (int i = 0; i < totalMonths; i++) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);

      final startDateStr = dateFormatter.format(monthStart);
      final endDateStr = dateFormatter.format(monthEnd);

      try {
        // Check if this month's data already exists
        final hasData = await _dbHelper.hasKpiDataForDateRange(startDateStr, endDateStr);
        if (hasData) {
          debugPrint('[KpiSyncService] Month $startDateStr already has data, skipping');
          completedMonths++;
          onProgress?.call(completedMonths / totalMonths);
          continue;
        }

        // Fetch all KPI types for this month
        debugPrint('[KpiSyncService] Fetching data for month: $startDateStr to $endDateStr');
        await _apiService.syncAllKpiData(monthStart, monthEnd);

        completedMonths++;
        onProgress?.call(completedMonths / totalMonths);

        // Small delay between months to prevent server overload
        if (i < totalMonths - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        debugPrint('[KpiSyncService] Error fetching month $startDateStr: $e');
        // Continue with next month - don't fail the entire operation
        completedMonths++;
        onProgress?.call(completedMonths / totalMonths);
      }
    }

    debugPrint('[KpiSyncService] Historical data fetch complete for $totalMonths months');
  }

  /// Performs incremental sync fetching only records newer than last sync point.
  /// Only fetches KPI data - baseline data (customers, inventory, service points)
  /// is only fetched during first login.
  /// 
  /// Returns: IncrementalSyncResult with counts of new/updated records
  Future<IncrementalSyncResult> performIncrementalSync() async {
    final lastSync = await _dbHelper.getLastSyncTimestamp();
    final now = DateTime.now();

    // Check if sync is needed (30-minute cache window)
    if (lastSync != null) {
      final timeSinceLastSync = now.difference(lastSync);
      if (timeSinceLastSync < const Duration(minutes: 30)) {
        debugPrint('[KpiSyncService] Sync skipped - last sync was ${timeSinceLastSync.inMinutes} minutes ago');
        return IncrementalSyncResult(
          syncType: 'skipped',
          recordsFetched: 0,
          lastSyncTimestamp: lastSync,
        );
      }
    }

    // Fetch delta - only KPI records since last sync
    int totalRecords = 0;

    try {
      // Fetch today's KPI data (most likely to have new records)
      debugPrint('[KpiSyncService] Performing incremental KPI sync from $lastSync');
      
      final today = DateFormat('yyyy-MM-dd').format(now);
      
      // Only fetch KPI data - NOT baseline data (customers, inventory, service points)
      // Baseline data is only fetched during first login via fetchBaselineDatasets()
      for (final kpiType in kpiTypes) {
        try {
          debugPrint('[KpiSyncService] Fetching KPI ${kpiType['name']} (id=${kpiType['id']}) for $today');
          
          final response = await _apiService.getWithAuth(
            '/sales/reports/kpi?startDate=$today&endDate=$today&kpiId=${kpiType['id']}&timeframe=1',
          );
          
          final data = await compute(_decodeJsonList, response.body);
          final records = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          
          totalRecords += records.length;
          
          debugPrint('[KpiSyncService] Fetched ${records.length} records for ${kpiType['name']}');
        } catch (e) {
          debugPrint('[KpiSyncService] Error fetching KPI ${kpiType['name']}: $e');
        }
      }
      
      // Store today's KPI data
      if (totalRecords > 0) {
        await _apiService.syncAllKpiData(now, now);
      }

      // Record sync completion
      await _dbHelper.insertSyncRecord(SyncRecord(
        syncType: 'incremental',
        syncStatus: 'completed',
        completedAt: now,
        recordsFetched: totalRecords,
        dateRangeStart: today,
        dateRangeEnd: today,
      ));

      debugPrint('[KpiSyncService] Incremental KPI sync complete - fetched $totalRecords records');
    } catch (e) {
      debugPrint('[KpiSyncService] Incremental sync failed: $e');
      // Record failed sync
      await _dbHelper.insertSyncRecord(SyncRecord(
        syncType: 'incremental',
        syncStatus: 'failed',
        completedAt: now,
        errorMessage: e.toString(),
      ));
    }

    return IncrementalSyncResult(
      syncType: 'incremental',
      recordsFetched: totalRecords,
      lastSyncTimestamp: now,
    );
  }

  /// Checks if sync is needed based on last successful sync timestamp.
  /// 
  /// [cacheMinutes] - Cache validity duration in minutes (default: 30)
  /// Returns: true if sync is needed, false if cache is still valid
  Future<bool> isSyncNeeded({int cacheMinutes = 30}) async {
    final lastSync = await _dbHelper.getLastSyncTimestamp();
    if (lastSync == null) {
      debugPrint('[KpiSyncService] Sync needed - no previous sync found');
      return true;
    }

    final now = DateTime.now();
    final timeSinceLastSync = now.difference(lastSync);
    final needsSync = timeSinceLastSync > Duration(minutes: cacheMinutes);
    
    debugPrint('[KpiSyncService] Last sync was ${timeSinceLastSync.inMinutes} minutes ago, sync needed: $needsSync');
    return needsSync;
  }

  /// Fetches baseline datasets concurrently.
  /// Called after today's KPI metrics are secured.
  Future<BaselineSyncResult> fetchBaselineDatasets() async {
    debugPrint('[KpiSyncService] Fetching baseline datasets');

    List<dynamic> servicePoints = [];
    Map<String, dynamic> companyDetails = {};
    List<dynamic> inventory = [];
    List<dynamic> customers = [];

    // Fetch company details
    try {
      final response = await _apiService.getWithAuth('/company/details');
      final body = response.body;
      if (body.isNotEmpty) {
        companyDetails = await compute(_decodeJsonMap, body);
        debugPrint('[KpiSyncService] Fetched company details');
      }
    } catch (e) {
      debugPrint('[KpiSyncService] Company details fetch failed (optional): $e');
    }

    // Fetch inventory
    try {
      final response = await _apiService.getWithAuth('/inventory/');
      final body = response.body;
      if (body.isNotEmpty) {
        inventory = await compute(_decodeJsonList, body);
        debugPrint('[KpiSyncService] Fetched ${inventory.length} inventory items');
      }
    } catch (e) {
      debugPrint('[KpiSyncService] Inventory fetch failed: $e');
    }

    // Fetch service points (optional)
    try {
      final response = await _apiService.getWithAuth('/servicepoints');
      final body = response.body;
      if (body.isNotEmpty) {
        servicePoints = await compute(_decodeJsonList, body);
        debugPrint('[KpiSyncService] Fetched ${servicePoints.length} service points');
      }
    } catch (e) {
      debugPrint('[KpiSyncService] Service points fetch failed (optional): $e');
    }

    // Fetch customers via PosApiService
    try {
      final posApiService = Get.find<pos_api.PosApiService>();
      customers = await posApiService.fetchCustomers();
      debugPrint('[KpiSyncService] Fetched ${customers.length} customers');
    } catch (e) {
      debugPrint('[KpiSyncService] Customers fetch failed: $e');
    }

    return BaselineSyncResult(
      servicePoints: servicePoints,
      companyDetails: companyDetails,
      inventory: inventory,
      customers: customers,
    );
  }
}

/// Top-level function for isolate-based JSON decoding
List<dynamic> _decodeJsonList(String jsonString) {
  return json.decode(jsonString) as List<dynamic>;
}

Map<String, dynamic> _decodeJsonMap(String jsonString) {
  return json.decode(jsonString) as Map<String, dynamic>;
}
