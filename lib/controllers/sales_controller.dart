import 'package:get/get.dart';
import '../database/db_helper.dart';
import '../services/api_services.dart';
import '../models/sale_transaction.dart';
import '../utils/network_helper.dart';

class SalesController extends GetxController {
  final _dbHelper = DatabaseHelper();
  final _apiService = ApiService();

  // Reactive list of sale transactions
  var salesTransactions = <SaleTransaction>[].obs;
  var groupedSales = <Map<String, dynamic>>[].obs;

  // Loading state
  var isLoadingSales = false.obs;
  var isSyncingSales = false.obs;

  @override
  void onInit() {
    super.onInit();
  }

  // Load sales transactions from database (cache)
  Future<void> loadSalesFromCache() async {
    try {
      print('🧾 Loading sales transactions from cache...');
      isLoadingSales.value = true;

      final transactions = await _dbHelper.getSaleTransactions();
      salesTransactions.value = transactions;

      final grouped = await _dbHelper.getGroupedSales();
      groupedSales.value = grouped;

      isLoadingSales.value = false;

      print('✅ Loaded ${transactions.length} sale transactions from cache');
      print('📊 Grouped into ${grouped.length} unique sales/receipts');
    } catch (e) {
      isLoadingSales.value = false;
      print('❌ Error loading sales transactions from cache: $e');
    }
  }

  // Sync sales transactions from API to local database
  Future<void> syncSalesTransactionsFromAPI({bool showMessage = false}) async {
    try {
      print('🧾 Syncing sales transactions from API...');
      isSyncingSales.value = true;

      // Fetch sales transactions from API (this also saves to database)
      final transactions = await _apiService.fetchAndStoreSalesTransactions();

      // Update sync metadata
      await _dbHelper.updateSyncMetadata('sales_transactions', 'success', transactions.length);

      print('✅ Successfully synced ${transactions.length} sale transactions to database');

      // Reload sales after sync
      await loadSalesFromCache();

      isSyncingSales.value = false;

      if (showMessage) {
        Get.snackbar(
          'Success',
          '${transactions.length} sales transactions refreshed',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      isSyncingSales.value = false;
      await _dbHelper.updateSyncMetadata('sales_transactions', 'failed', 0, e.toString());
      print('❌ Error syncing sales transactions from API: $e');

      if (showMessage) {
        Get.snackbar(
          'Error',
          'Failed to refresh sales: $e',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      rethrow;
    }
  }

  // Refresh sales (pull-to-refresh)
  Future<void> refreshSales() async {
    final hasNetwork = await NetworkHelper.hasConnection();
    if (!hasNetwork) {
      Get.snackbar(
        'Offline',
        'Cannot refresh without internet connection',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    await syncSalesTransactionsFromAPI(showMessage: true);
  }

  // Get sales transactions by salesId (all items in a sale)
  Future<List<SaleTransaction>> getSaleTransactionsBySalesId(String salesId) async {
    try {
      return await _dbHelper.getSaleTransactionsBySalesId(salesId);
    } catch (e) {
      print('❌ Error getting sale transactions by salesId: $e');
      return [];
    }
  }

  // Get grouped sales (one entry per receipt)
  Future<List<Map<String, dynamic>>> getGroupedSales() async {
    try {
      return await _dbHelper.getGroupedSales();
    } catch (e) {
      print('❌ Error getting grouped sales: $e');
      return [];
    }
  }

  // Get daily summary for a specific date
  Future<Map<String, dynamic>> getDailySummary(DateTime date) async {
    try {
      return await _dbHelper.getDailySummary(date.millisecondsSinceEpoch);
    } catch (e) {
      print('❌ Error getting daily summary: $e');
      return {
        'paymentSummary': [],
        'categorySummary': [],
        'complementaryTotal': 0.0,
        'overallTotal': {},
      };
    }
  }

  // Get sales by date range
  Future<List<SaleTransaction>> getSalesByDateRange(DateTime start, DateTime end) async {
    try {
      return await _dbHelper.getSaleTransactionsByDateRange(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      );
    } catch (e) {
      print('❌ Error getting sales by date range: $e');
      return [];
    }
  }

  // Get sales count
  Future<int> getSalesCount() async {
    try {
      return await _dbHelper.getSalesCount();
    } catch (e) {
      print('❌ Error getting sales count: $e');
      return 0;
    }
  }

  // Clear all sales data (useful for re-sync)
  Future<void> clearAllSales() async {
    try {
      await _dbHelper.deleteAllSaleTransactions();
      salesTransactions.clear();
      groupedSales.clear();
      print('🗑️ All sales transactions cleared from database');
    } catch (e) {
      print('❌ Error clearing sales transactions: $e');
      rethrow;
    }
  }
}
