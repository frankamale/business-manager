import 'dart:async';
import 'package:get/get.dart';
import 'api_services.dart';
import '../database/db_helper.dart';
import '../utils/network_helper.dart';

class SalesSyncService extends GetxService {
  final ApiService _apiService = Get.find<ApiService>();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Timer? _syncTimer;
  static const Duration _syncInterval = Duration(minutes: 5); 

  var isSyncing = false.obs;
  var lastSyncTime = Rx<DateTime?>(null);
  var lastSyncError = Rx<String?>(null);

  @override
  void onInit() {
    super.onInit();
    startPeriodicSync();
  }

  @override
  void onClose() {
    stopPeriodicSync();
    super.onClose();
  }

  // Start periodic sync
  void startPeriodicSync() {
    // Initial sync
    syncSalesData();

    // Set up periodic sync
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      syncSalesData();
    });
  }

  // Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Manual sync trigger
  Future<void> manualSync() async {
    await syncSalesData();
  }

  // Main sync function
  Future<void> syncSalesData() async {
    if (isSyncing.value) return;

    try {
      isSyncing.value = true;
      lastSyncError.value = null;

      // Check network connectivity
      final hasConnection = await NetworkHelper.hasConnection();
      if (!hasConnection) {
        print('No network connection - skipping sales sync');
        return;
      }

      print('Starting sales data sync...');

      // Get today's date range
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day).toIso8601String().split('T')[0];
      final endDate = startDate; // Same day for now, can be expanded

      // Fetch sales data from server
      final salesData = await _apiService.fetchSalesForSync(
        startDate: startDate,
        endDate: endDate,
        pageSize: 20, // Get 20 items at a time as requested
      );

      print('Fetched ${salesData.length} sales records from server');

      await _dbHelper.insertServerSales(salesData);

      await _dbHelper.syncLocalSalesWithServerData();

      // Update sync metadata
      await _dbHelper.updateSyncMetadata(
        'server_sales',
        'success',
        salesData.length,
      );

      lastSyncTime.value = DateTime.now();
      print('Sales sync completed successfully');

    } catch (e) {
      lastSyncError.value = e.toString();
      print('Sales sync failed: $e');

      // Update sync metadata with error
      await _dbHelper.updateSyncMetadata(
        'server_sales',
        'error',
        0,
        e.toString(),
      );
    } finally {
      isSyncing.value = false;
    }
  }

  // Get sync status
  Future<Map<String, dynamic>?> getSyncStatus() async {
    return await _dbHelper.getSyncMetadata('server_sales');
  }
}