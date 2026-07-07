import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../../../back_pos/utils/network_helper.dart';

/// Sync scenario types for splash page decision making
enum SyncScenario {
  firstLogin,       // No data at all - need today + baseline
  subsequentLogin,  // Has data - need today only if missing
  offline,          // No network - use cache only
  cacheValid,       // Recent sync - skip entirely
}

/// SyncStateManager - Central coordinator for sync logic
/// 
/// Tracks what data has been loaded into controllers during this session
/// and determines the appropriate sync scenario based on database state
/// and network connectivity.
/// 
/// Usage:
/// 1. Register in splash page: Get.put(SyncStateManager(), permanent: true)
/// 2. Determine scenario: final scenario = await syncManager.determineSyncScenario()
/// 3. Check if fetch needed: syncManager.shouldFetchTodayData()
/// 4. Mark loaded: syncManager.markTodayDataLoaded()
class SyncStateManager extends GetxService {
  final _dbHelper = UnifiedDatabaseHelper.instance;

  // Track what data has been loaded into controllers during this session
  final _todayDataLoaded = false.obs;
  final _baselineLoaded = false.obs;
  final _historicalMonthsLoaded = <String>[].obs;
  
  // Sync timestamps
  DateTime? _lastTodaySync;
  DateTime? _lastBaselineSync;
  DateTime? _lastHistoricalSync;
  
  /// Determine what sync scenario we're in based on DB state and connectivity
  Future<SyncScenario> determineSyncScenario() async {
    // Check connectivity first
    final hasConnection = await _hasConnection();
    if (!hasConnection) {
      debugPrint('[SyncStateManager] Offline - using cache');
      return SyncScenario.offline;
    }
    
    // Check if this is first login (no data in DB)
    final hasData = await _hasAnyData();
    if (!hasData) {
      debugPrint('[SyncStateManager] First login - no data found');
      return SyncScenario.firstLogin;
    }
    
    // For subsequent logins, always refresh today's data
    debugPrint('[SyncStateManager] Subsequent login - always refreshing today\'s data');
    return SyncScenario.subsequentLogin;
  }
  
  /// Check if controllers should fetch data or use cache
  bool shouldFetchTodayData() {
    if (_todayDataLoaded.value) {
      debugPrint('[SyncStateManager] Today data already loaded this session - skipping fetch');
      return false;
    }
    return true;
  }
  
  /// Mark that today's data has been loaded into controllers
  void markTodayDataLoaded() {
    _todayDataLoaded.value = true;
    _lastTodaySync = DateTime.now();
    debugPrint('[SyncStateManager] Today data marked as loaded');
  }
  
  /// Check if baseline data needs fetching
  Future<bool> needsBaselineFetch() async {
    if (_baselineLoaded.value) return false;
    
    final hasCompany = await _dbHelper.hasCompanyDetails();
    final hasServicePoints = await _dbHelper.hasServicePoints();
    final hasInventory = await _dbHelper.hasInventory();
    
    return !hasCompany || !hasServicePoints || !hasInventory;
  }
  
  /// Mark baseline as loaded
  void markBaselineLoaded() {
    _baselineLoaded.value = true;
    _lastBaselineSync = DateTime.now();
    debugPrint('[SyncStateManager] Baseline data marked as loaded');
  }
  
  /// Get the next historical month that needs fetching
  /// Returns null if all months have data
  Future<String?> getNextHistoricalMonthToFetch() async {
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);
      final monthKey = DateFormat('yyyy-MM').format(monthStart);
      
      // Skip current month (handled separately)
      if (i == 0) continue;
      
      // Check if already loaded this session
      if (_historicalMonthsLoaded.contains(monthKey)) continue;
      
      // Check if exists in DB
      final hasData = await _dbHelper.hasKpiDataForDateRange(
        DateFormat('yyyy-MM-dd').format(monthStart),
        DateFormat('yyyy-MM-dd').format(monthEnd),
      );
      
      if (!hasData) {
        debugPrint('[SyncStateManager] Next month to fetch: $monthKey');
        return monthKey;
      }
      
      // Mark as checked so we don't re-check
      _historicalMonthsLoaded.add(monthKey);
    }
    return null; // All months have data
  }
  
  /// Mark a historical month as loaded
  void markHistoricalMonthLoaded(String monthKey) {
    _historicalMonthsLoaded.add(monthKey);
    _lastHistoricalSync = DateTime.now();
    debugPrint('[SyncStateManager] Historical month marked as loaded: $monthKey');
  }
  
  /// Check if sync is needed based on last sync timestamp
  Future<bool> isSyncNeeded({int cacheMinutes = 30}) async {
    final lastSync = await _dbHelper.getLastSyncTimestamp();
    if (lastSync == null) return true;
    
    final timeSince = DateTime.now().difference(lastSync);
    return timeSince > Duration(minutes: cacheMinutes);
  }
  
  /// Get last sync time for display
  DateTime? get lastTodaySync => _lastTodaySync;
  DateTime? get lastBaselineSync => _lastBaselineSync;
  DateTime? get lastHistoricalSync => _lastHistoricalSync;
  
  // Private helpers
  
  Future<bool> _hasConnection() async {
    try {
      return await NetworkHelper.hasConnection();
    } catch (e) {
      debugPrint('[SyncStateManager] Error checking connection: $e');
      return false;
    }
  }
  
  Future<bool> _hasAnyData() async {
    try {
      // Check if we have any KPI data at all
      final yesterday = DateFormat('yyyy-MM-dd').format(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final hasSales = await _dbHelper.hasKpiDataForDateRange(yesterday, today);
      final hasCompany = await _dbHelper.hasCompanyDetails();
      
      return hasSales || hasCompany;
    } catch (e) {
      debugPrint('[SyncStateManager] Error checking data: $e');
      return false;
    }
  }
}
