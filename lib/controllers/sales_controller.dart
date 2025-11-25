import 'package:get/get.dart';
import '../database/db_helper.dart';
import '../services/api_services.dart';
import '../models/sale_transaction.dart';

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
    loadSalesTransactions();
  }

  // Load sales transactions from database
  Future<void> loadSalesTransactions() async {
    try {
      print('🧾 Loading sales transactions from database...');
      isLoadingSales.value = true;

      final transactions = await _dbHelper.getSaleTransactions();
      salesTransactions.value = transactions;

      final grouped = await _dbHelper.getGroupedSales();
      groupedSales.value = grouped;

      isLoadingSales.value = false;

      print('✅ Successfully loaded ${transactions.length} sale transactions from database');
      print('📊 Grouped into ${grouped.length} unique sales/receipts');
    } catch (e) {
      isLoadingSales.value = false;
      print('❌ Error loading sales transactions from database: $e');
    }
  }

  // Sync sales transactions from API to local database
  Future<void> syncSalesTransactionsFromAPI() async {
    try {
      print('🔄 Starting sales transactions sync from API to database...');
      isSyncingSales.value = true;

      // Fetch sales transactions from API (this also saves to database)
      final transactions = await _apiService.fetchAndStoreSalesTransactions();

      print('✅ Successfully synced ${transactions.length} sale transactions to database');

      // Reload sales after sync
      await loadSalesTransactions();

      isSyncingSales.value = false;
    } catch (e) {
      isSyncingSales.value = false;
      print('❌ Error syncing sales transactions from API: $e');
      rethrow;
    }
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
