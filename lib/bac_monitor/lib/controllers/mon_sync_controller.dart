import 'dart:async';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/api_services.dart';
import '../services/kpi_sync_service.dart';
import '../models/sync_tracker.dart';
import 'mon_kpi_overview_controller.dart';
import 'mon_salestrends_controller.dart';
import 'mon_data_sync_controller.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../../../back_pos/services/api_services.dart' as pos_api;
import '../../../back_pos/utils/network_helper.dart';

class MonSyncController extends GetxController {
  final MonitorApiService _apiService = Get.find<MonitorApiService>();
  Timer? _syncTimer;
  
  // Track sync state
  var isSyncPaused = false.obs;
  var connectivityStatus = 'unknown'.obs;
  StreamSubscription<InternetConnectionStatus>? _connectivitySubscription;

  // Reference to data sync controller for incremental sync
  MonDataSyncController? get dataSyncController => 
    Get.isRegistered<MonDataSyncController>() 
      ? Get.find<MonDataSyncController>() 
      : null;

  @override
  void onInit() {
    super.onInit();
    // Start listening to connectivity changes
    _startConnectivityListener();
  }

  /// Start listening to connectivity changes
  void _startConnectivityListener() {
    _connectivitySubscription = InternetConnectionChecker.instance.onStatusChange.listen((status) {
      _handleConnectivityChange(status);
    });
  }

  /// Handle connectivity state changes
  void _handleConnectivityChange(InternetConnectionStatus status) {
    final wasOnline = connectivityStatus.value == 'connected';

    if (status == InternetConnectionStatus.disconnected) {
      connectivityStatus.value = 'disconnected';
      debugPrint('MonSyncController: Network disconnected - pausing sync');
      pausePeriodicSync();


    } else {
      connectivityStatus.value = 'connected';
      debugPrint('MonSyncController: Network reconnected - resuming sync');
      resumePeriodicSync();

    }
  }

  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      debugPrint("MonSyncController: Periodic incremental sync triggered.");
      await _performPeriodicSync();
      debugPrint("MonSyncController: Periodic sync completed.");
    });
  }

  /// Perform periodic incremental sync using delta-based fetching
  Future<void> _performPeriodicSync() async {
    try {
      // Use KpiSyncService for incremental sync
      final kpiSyncService = Get.isRegistered<KpiSyncService>()
          ? Get.find<KpiSyncService>()
          : null;

      if (kpiSyncService != null) {
        final result = await kpiSyncService.performIncrementalSync();
        
        if (!result.wasSkipped) {
          // Refresh UI controllers with new data
          await _refreshUiControllers();
          debugPrint("MonSyncController: Periodic sync fetched ${result.recordsFetched} records");
        } else {
          debugPrint("MonSyncController: Periodic sync skipped - cache valid");
        }
      } else {
        // Fallback to legacy sync
        await _legacyPeriodicSync();
      }
    } catch (e) {
      debugPrint("MonSyncController: Periodic sync failed: $e");
    }
  }

  /// Legacy periodic sync (fallback)
  Future<void> _legacyPeriodicSync() async {
    await _apiService.syncAllKpiData(
      DateTime.now().subtract(const Duration(days: 30)),
      DateTime.now(),
    );
    await _refreshUiControllers();
  }

  /// Refresh UI controllers after sync
  Future<void> _refreshUiControllers() async {
    if (Get.isRegistered<MonKpiOverviewController>()) {
      await Get.find<MonKpiOverviewController>().fetchKpiData();
    }
    if (Get.isRegistered<MonSalesTrendsController>()) {
      await Get.find<MonSalesTrendsController>().fetchAllData();
    }
  }

  /// Trigger a one-time sync manually
  Future<void> syncNow() async {
    debugPrint("MonSyncController: Manual sync triggered.");
    
    try {
      final kpiSyncService = Get.isRegistered<KpiSyncService>()
          ? Get.find<KpiSyncService>()
          : null;

      if (kpiSyncService != null) {
        final result = await kpiSyncService.performIncrementalSync();
        await _refreshUiControllers();
        debugPrint("MonSyncController: Manual sync completed - ${result.syncType}, ${result.recordsFetched} records");
      } else {
        // Fallback to legacy sync
        await _apiService.syncAllKpiData(
          DateTime.now().subtract(const Duration(days: 30)),
          DateTime.now(),
        );
        await _refreshUiControllers();
        debugPrint("MonSyncController: Manual sync completed (legacy)");
      }
    } catch (e) {
      debugPrint("MonSyncController: Manual sync failed: $e");
    }
  }

  /// Get last sync time for display
  Future<DateTime?> getLastSyncTime() async {
    return await UnifiedDatabaseHelper.instance.getLastSyncTimestamp();
  }

  /// Pause the periodic sync timer
  void pausePeriodicSync() {
    isSyncPaused.value = true;
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('MonSyncController: Periodic sync paused');
  }

  /// Resume the periodic sync timer
  void resumePeriodicSync() {
    isSyncPaused.value = false;
    startPeriodicSync();
    debugPrint('MonSyncController: Periodic sync resumed');
  }

  /// Check current connectivity and update sync state
  Future<void> checkConnectivityAndUpdateSync() async {
    final isOnline = await NetworkHelper.hasConnection();
    if (isOnline) {
      connectivityStatus.value = 'connected';
      if (isSyncPaused.value) {
        resumePeriodicSync();
      }
    } else {
      connectivityStatus.value = 'disconnected';
      if (!isSyncPaused.value) {
        pausePeriodicSync();
      }
    }
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.onClose();
  }
}