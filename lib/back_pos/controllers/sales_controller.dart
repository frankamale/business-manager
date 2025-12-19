import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:bac_pos/back_pos/database/db_helper.dart';
import 'package:bac_pos/back_pos/services/api_services.dart';
import 'package:bac_pos/back_pos/models/sale_transaction.dart';
import 'package:bac_pos/back_pos/models/inventory_item.dart';
import 'package:bac_pos/back_pos/utils/network_helper.dart';
import 'payment_controller.dart';

class SalesController extends GetxController {
  final _dbHelper = DatabaseHelper();
  final _apiService = PosApiService();

  // Reactive list of sale transactions
  var salesTransactions = <SaleTransaction>[].obs;
  var groupedSales = <Map<String, dynamic>>[].obs; 

  // Loading state
  var isLoadingSales = false.obs;

  @override
  void onInit() {
    super.onInit();
  }

  // Load sales transactions from database (cache)
  Future<void> loadSalesFromCache() async {
    try {
      isLoadingSales.value = true;

      final transactions = await _dbHelper.getSaleTransactions();
      salesTransactions.value = transactions;

      final grouped = await _dbHelper.getGroupedSales();
      groupedSales.value = grouped;

      isLoadingSales.value = false;
    } catch (e) {
      isLoadingSales.value = false;
    }
  }

  // Refresh sales from local cache only
  Future<void> refreshSales() async {
    await loadSalesFromCache();
    Get.snackbar(
      'Success', "Refreshed successfully",
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 2),
    );
  }

  // Get sales transactions by salesId (all items in a sale)
  Future<List<SaleTransaction>> getSaleTransactionsBySalesId(String salesId) async {
    try {
      return await _dbHelper.getSaleTransactionsBySalesId(salesId);
    } catch (e) {
      return [];
    }
  }

  // Get grouped sales (one entry per receipt)
  Future<List<Map<String, dynamic>>> getGroupedSales() async {
    try {
      return await _dbHelper.getGroupedSales();
    } catch (e) {
      return [];
    }
  }

  // Get daily summary for a specific date
  Future<Map<String, dynamic>> getDailySummary(DateTime date) async {
    try {
      return await _dbHelper.getDailySummary(date.millisecondsSinceEpoch);
    } catch (e) {
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
      return [];
    }
  }

  // Get sales count
  Future<int> getSalesCount() async {
    try {
      return await _dbHelper.getSalesCount();
    } catch (e) {
      return 0;
    }
  }

  // Clear all sales data (useful for re-sync)
  Future<void> clearAllSales() async {
    try {
      await _dbHelper.deleteAllSaleTransactions();
      salesTransactions.clear();
      groupedSales.clear();
    } catch (e) {
      rethrow;
    }
  }

  // Upload sale to server
  Future<void> uploadSaleToServer(String salesId) async {
    try {
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

      // Check if sale already exists on server
      bool saleExistsOnServer = false;
      try {
        final existingSale = await _apiService.fetchSingleTransaction(salesId);
        saleExistsOnServer = existingSale != null && existingSale.isNotEmpty;
        print('Sale $salesId already exists on server: $saleExistsOnServer');
      } catch (e) {
        print('Error checking if sale exists on server: $e');
        saleExistsOnServer = false;
      }

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

      // Create or update sale on server
      if (!saleExistsOnServer) {
        // Log the sale payload being sent to server
        print('=== SALE PAYLOAD BEING SENT TO SERVER ===');
        print('Sale ID: $salesId');
        print('Receipt Number: ${firstTransaction.receiptnumber}');
        print('Sale Payload JSON:');
        print(salePayload);
        print('=== END SALE PAYLOAD ===');

        // Create sale via API
        await _apiService.createSale(salePayload);
      } else {
        // Log the update payload being sent to server
        print('=== SALE UPDATE PAYLOAD BEING SENT TO SERVER ===');
        print('Sale ID: $salesId');
        print('Receipt Number: ${firstTransaction.receiptnumber}');
        print('Update Payload JSON:');
        print(salePayload);
        print('=== END SALE UPDATE PAYLOAD ===');

        // Update sale via API
        await _apiService.updateSale(salesId, salePayload);
      }

      // If payment was made, create and post payment
      final totalPaid = saleTransactions.fold<double>(
        0.0,
        (sum, transaction) => sum + transaction.amountpaid,
      );

      print('=== PAYMENT INFO ===');
      print('Sale ID: $salesId');
      print('Total Paid in Local Transactions: $totalPaid');
      print('=== END PAYMENT INFO ===');

      if (totalPaid > 0) {
        // Fetch transaction details from server to get proper data
        final transactionData = await _apiService.fetchSingleTransaction(salesId);

        // Calculate outstanding balance from server data
        final lineItemsList = transactionData['lineItems'] as List<dynamic>? ?? [];
        final totalAmount = lineItemsList.fold<double>(
          0.0,
          (sum, item) => sum + ((item['sellingprice'] ?? 0.0) * (item['quantity'] ?? 0.0)),
        );
        final currentPaid = double.tryParse(
          transactionData['amountpaid']?.toString() ??
          transactionData['amountPaid']?.toString() ?? '0'
        ) ?? 0.0;
        final outstandingBalance = totalAmount - currentPaid;

        // Only pay up to the outstanding balance
        final paymentAmount = totalPaid < outstandingBalance
          ? totalPaid
          : outstandingBalance;

        // Only send payment if there's an outstanding balance
        if (paymentAmount > 0) {
          // Get transaction date
          int invoiceTimestamp = firstTransaction.transactiondate;
          if (transactionData['transactiondate'] != null) {
            invoiceTimestamp = transactionData['transactiondate'];
          }

          // Add 2 seconds buffer
          final paymentTimestamp = invoiceTimestamp + 2000;

          // Create payment payload using PaymentController to fetch currencyid from database
          final paymentController = Get.find<PaymentController>();
          final paymentPayload = await paymentController.createPaymentPayload(
            saleId: salesId,
            paymentAmount: paymentAmount,
            paymentTimestamp: paymentTimestamp,
            servicePointId: servicePointId,
            customerId: customerId,
            companyId: companyId,
            currencyid: null, 
          );

          // Log the payment payload being sent to server
          print('=== PAYMENT PAYLOAD BEING SENT TO SERVER ===');
          print('Sale ID: $salesId');
          print('Payment Amount: $paymentAmount');
          print('Payment Payload JSON:');
          print(paymentPayload);
          print('=== END PAYMENT PAYLOAD ===');

          await _apiService.postSale(paymentPayload);
        } else {
          print('=== NO PAYMENT SENT ===');
          print('Sale ID: $salesId');
          print('Reason: Payment amount is 0 or no outstanding balance');
          print('=== END NO PAYMENT ===');
        }
      } else {
        print('=== NO PAYMENT TO PROCESS ===');
        print('Sale ID: $salesId');
        print('Reason: No payment recorded in local transactions');
        print('=== END NO PAYMENT ===');
      }

      // Update upload status to 'uploaded'
      await _dbHelper.updateSaleUploadStatus(salesId, 'uploaded');

      // Reload sales to reflect updated status
      await loadSalesFromCache();
    } catch (e) {
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
