import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../database/db_helper.dart';
import '../services/api_services.dart';
import '../models/sale_transaction.dart';
import '../models/inventory_item.dart';
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

  // Upload sale to server
  Future<void> uploadSaleToServer(String salesId) async {
    try {
      print('📤 Uploading sale $salesId to server...');

      // Get sale transactions from database
      final saleTransactions = await _dbHelper.getSaleTransactionsBySalesId(salesId);

      if (saleTransactions.isEmpty) {
        throw Exception('No sale transactions found for salesId: $salesId');
      }

      // Get the first transaction for common fields
      final firstTransaction = saleTransactions.first;

      // Use stored IDs from the local transaction
      final companyId = firstTransaction.companyid ?? '';
      final branchId = firstTransaction.branchid ?? '';
      final servicePointId = firstTransaction.servicepointid ?? '';
      final customerId = firstTransaction.clientid;
      final salespersonId = firstTransaction.salespersonid ?? "00000000-0000-0000-0000-000000000000";

      // Reconstruct line items from transactions
      const uuid = Uuid();
      final lineItems = saleTransactions.asMap().entries.map((entry) {
        final index = entry.key;
        final transaction = entry.value;

        return {
          "id": uuid.v4(),
          "salesid": salesId,
          "inventoryid": transaction.inventoryid ?? "00000000-0000-0000-0000-000000000000",
          "ipdid": transaction.ipdid ?? "00000000-0000-0000-0000-000000000000",
          "quantity": transaction.quantity.toInt(),
          "sellingprice": transaction.sellingprice.toInt(),
          "ordernumber": index,
          "remarks": "",
          "transactionstatusid": 1,
          "sellingprice_original": transaction.sellingpriceOriginal.toInt(),
        };
      }).toList();

      // Create sale payload
      final salePayload = {
        "id": salesId,
        "transactionDate": firstTransaction.transactiondate,
        "transactionstatusid": 1,
        "receiptnumber": firstTransaction.receiptnumber,
        "clientid": customerId,
        "remarks": firstTransaction.remarks,
        "otherRemarks": "",
        "companyId": companyId,
        "branchId": branchId,
        "servicepointid": servicePointId,
        "salespersonid": salespersonId,
        "modeid": 2,
        "glproxySubCategoryId": "44444444-4444-4444-4444-444444444444",
        "lineItems": lineItems,
        "saleActionId": 1,
      };

      // Create sale via API
      print('📤 Sending sale to API...');
      await _apiService.createSale(salePayload);
      print('✅ Sale created on server');

      // If payment was made, create and post payment
      final totalPaid = saleTransactions.fold<double>(
        0.0,
        (sum, transaction) => sum + transaction.amountpaid,
      );

      if (totalPaid > 0) {
        print('💵 Posting payment of $totalPaid...');

        // Fetch transaction details from server to get proper data
        final transactionData = await _apiService.fetchSingleTransaction(salesId);

        // Get transaction date
        int invoiceTimestamp = firstTransaction.transactiondate;
        if (transactionData['transactiondate'] != null) {
          invoiceTimestamp = transactionData['transactiondate'];
        }

        // Add 2 seconds buffer
        final paymentTimestamp = invoiceTimestamp + 2000;

        // Create payment payload
        final paymentPayload = {
          "id": uuid.v4(),
          "currencyid": "3a0e97b4-c13a-4a49-9205-182e62039a5a",
          "referenceid": salesId,
          "servicepointid": servicePointId,
          "transactiontypeid": 1,
          "amount": totalPaid,
          "method": "Cash",
          "methodId": 1,
          "chequeno": "",
          "cashaccountid": "11111111-1111-1111-1111-111111111111",
          "paydate": paymentTimestamp,
          "receipt": true,
          "currency": "Uganda Shillings",
          "type": "Sales",
          "bp": customerId ?? "",
          "direction": 1,
          "glproxySubCategoryId": "44444444-4444-4444-4444-444444444444",
        };

        await _apiService.postSale(paymentPayload);
        print('✅ Payment posted to server');
      }

      // Update upload status to 'uploaded'
      await _dbHelper.updateSaleUploadStatus(salesId, 'uploaded');
      print('✅ Sale $salesId uploaded successfully');

      // Reload sales to reflect updated status
      await loadSalesFromCache();
    } catch (e) {
      print('❌ Error uploading sale: $e');

      // Update upload status to 'failed' with error message
      await _dbHelper.updateSaleUploadStatus(
        salesId,
        'failed',
        errorMessage: e.toString(),
      );

      // Reload sales to reflect updated status
      await loadSalesFromCache();

      rethrow;
    }
  }
}
