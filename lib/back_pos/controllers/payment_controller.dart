import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:bac_pos/back_pos/models/customer.dart';
import 'package:bac_pos/back_pos/services/api_services.dart';
import 'package:bac_pos/back_pos/models/inventory_item.dart';
import 'package:bac_pos/back_pos/models/users.dart';
import 'package:bac_pos/shared/database/unified_db_helper.dart';
import 'package:bac_pos/back_pos/utils/network_helper.dart';
import 'auth_controller.dart';
import 'sales_controller.dart';
import 'package:bac_pos/back_pos/services/settings_service.dart';

class PaymentController extends GetxController {
  final PosApiService _apiService = Get.find<PosApiService>();
  final SettingsService _settingsService = SettingsService();
  final _dbHelper = UnifiedDatabaseHelper.instance;

  // Reactive state
  var isProcessing = false.obs;
  var receiptCounter = 1.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeReceiptCounter();
  }

  // Initialize receipt counter from database
  Future<void> _initializeReceiptCounter() async {
    try {
      final latestReceiptNumber = await _getLatestReceiptNumber();
      if (latestReceiptNumber != null) {
        // Extract numeric part from receipt number (e.g., "REC-0005" -> 5)
        final numericPart = latestReceiptNumber.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );
        if (numericPart.isNotEmpty) {
          final latestNumber = int.tryParse(numericPart) ?? 0;
          receiptCounter.value = latestNumber + 1;
        }
      }
    } catch (e) {
      receiptCounter.value = 1;
    }
  }

  /// Opens the last known company database when it is closed so local
  /// queries (cash accounts, saving sales) keep working offline instead of
  /// throwing "Database not opened".
  Future<void> _ensureDatabaseOpen() async {
    if (_dbHelper.isDatabaseOpen) return;

    String? companyId;
    try {
      final companyInfo = await _apiService.getCompanyInfo();
      companyId = companyInfo['companyId'];
    } catch (e) {
      companyId = null;
    }

    if (companyId == null || companyId.isEmpty) {
      try {
        companyId = GetStorage().read('last_company_id') as String?;
      } catch (e) {
        companyId = null;
      }
    }

    if (companyId != null && companyId.isNotEmpty) {
      await _dbHelper.openForCompany(companyId);
    }
  }

  /// Resolves the acting user's info from offline-safe sources first (the
  /// locally logged-in user in SQLite), then stored server data. Only throws
  /// when neither source is available.
  Map<String, dynamic> _resolveUserContext({
    required String? requestedSalespersonId,
    required Map<String, String> companyInfo,
    Map<String, dynamic>? userData,
    User? localUser,
  }) {
    if (userData == null && localUser == null) {
      throw Exception(
        'User information not available. Please refresh and try again.',
      );
    }

    String? firstNonEmpty(List<String?> values) {
      for (final value in values) {
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final userId =
        firstNonEmpty([userData?['userId']?.toString(), localUser?.id]) ??
            '00000000-0000-0000-0000-000000000000';

    final salespersonId = firstNonEmpty([
      requestedSalespersonId,
      localUser?.salespersonid,
      localUser?.staffid,
      userData?['salespersonid']?.toString(),
      userData?['staffid']?.toString(),
      userId,
    ])!;

    final issuedByName =
        firstNonEmpty([
          localUser?.staff,
          localUser?.name,
          userData?['username']?.toString(),
        ]) ??
        '';

    final branchId =
        firstNonEmpty([companyInfo['branchId'], localUser?.branch]) ?? '';

    final companyId =
        firstNonEmpty([
          companyInfo['companyId'],
          localUser?.companyid,
          _dbHelper.currentCompanyId,
        ]) ??
        '';

    return {
      'userId': userId,
      'salespersonId': salespersonId,
      'issuedByName': issuedByName,
      'branchId': branchId,
      'companyId': companyId,
    };
  }

  Future<Map<String, dynamic>> _getDefaultCashAccount() async {
    debugPrint('=== DEBUG: _getDefaultCashAccount START ===');
    await _ensureDatabaseOpen();
    final db = await _dbHelper.database;
    debugPrint('Database instance: ${db != null ? "available" : "NULL"}');

    final result = await db.query(
      'cash_accounts',
      where: 'pos = 1 AND main_currency = 1',
      limit: 1,
    );
    debugPrint('Cash accounts query result count: ${result.length}');
    debugPrint('Cash accounts query result: $result');

    if (result.isEmpty) {
      debugPrint('=== DEBUG: ERROR - No POS cash account configured ===');
      throw Exception('No POS cash account configured');
    }

    debugPrint('=== DEBUG: _getDefaultCashAccount END ===');
    return result.first;
  }

  /// POS payment methods (one per cash account) from the offline cache.
  Future<List<Map<String, dynamic>>> getPosCashAccounts() async {
    await _ensureDatabaseOpen();
    return _dbHelper.getPosCashAccounts();
  }

  /// The selected cash account, or the default POS account when none is chosen.
  Future<Map<String, dynamic>> _resolveCashAccount(String? cashAccountId) async {
    if (cashAccountId != null && cashAccountId.isNotEmpty) {
      await _ensureDatabaseOpen();
      final account = await _dbHelper.getCashAccountById(cashAccountId);
      if (account != null) return account;
    }
    return _getDefaultCashAccount();
  }

  static String cashAccountLabel(Map<String, dynamic> account) {
    for (final key in ['accountname', 'accountnumber', 'reference']) {
      final value = account[key]?.toString() ?? '';
      if (value.isNotEmpty) return value;
    }
    return 'Account';
  }

  // Get the latest receipt number from database
  Future<String?> _getLatestReceiptNumber() async {
    try {
      final db = await _dbHelper.database;

      final result = await db.rawQuery(
        'SELECT receiptnumber FROM sales_transactions ORDER BY transactiondate DESC LIMIT 1',
      );

      if (result.isNotEmpty) {
        return result.first['receiptnumber'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Generate unique receipt number
  String generateReceiptNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Convert timestamp to 6 digits using modulo
    final shortNumber = timestamp % 1000000;

    // Pad with leading zeros if needed
    final receiptNumber = shortNumber.toString().padLeft(6, '0');

    return 'REC-$receiptNumber';
  }

  // Create sale payload
  Map<String, dynamic> createSalePayload({
    required String saleId,
    required List<Map<String, dynamic>> cartItems,
    required String receiptnumber,
    required String? customerId,
    required String? salespersonId,
    required String remarks,
    required String branchId,
    required String companyId,
    required String servicePointId,
  }) {
    const uuid = Uuid();
    final transactionTimestamp = DateTime.now().millisecondsSinceEpoch;

    // Create line items
    final lineItems = cartItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final inventoryItem = item['item'] as InventoryItem;
      final sellingPrice =
          (item['price'] as num?)?.toDouble() ?? inventoryItem.price;

      return {
        "id": uuid.v4(),
        "salesid": saleId,
        "inventoryid": inventoryItem.id,
        "ipdid": inventoryItem.ipdid,
        "quantity": (item['quantity'] as num).toInt(),
        "sellingprice": sellingPrice.toInt(),
        "ordernumber": index,
        "remarks": item['notes'] ?? "",
        "transactionstatusid": 1,
        "sellingprice_original": inventoryItem.price.toInt(),
        "complimentaryid": item['complimentary'] == true ? 1 : 0,
      };
    }).toList();

    // Create sale payload
    return {
      "id": saleId,
      "transactionDate": transactionTimestamp,
      "transactionstatusid": 1,
      "receiptnumber": receiptnumber,
      "clientid": customerId,
      "remarks": remarks.isNotEmpty ? remarks : "",
      "otherRemarks": "",
      "companyId": companyId,
      "branchId": branchId,
      "servicepointid": servicePointId,
      "salespersonid": salespersonId ?? "00000000-0000-0000-0000-000000000000",
      "modeid": 2,
      "gLProxySubCategoryId": "44444444-1111-1111-1111-111111111111",
      "lineItems": lineItems,
      "saleActionId": 1,
      "categoryid": "44444444-1111-1111-1111-111111111111",
    };
  }

  // Create payment payload
  Future<Map<String, dynamic>> createPaymentPayload({
    required String saleId,
    required double paymentAmount,
    required int paymentTimestamp,
    required String servicePointId,
    required String? customerId,
    required String? companyId,
    required String? currencyid,
    required String? categoryid,
    String? cashAccountId,
  }) async {
    debugPrint('=== DEBUG: createPaymentPayload START ===');
    debugPrint('saleId: $saleId');
    debugPrint('paymentAmount: $paymentAmount');
    debugPrint('paymentTimestamp: $paymentTimestamp');
    debugPrint('servicePointId: $servicePointId');
    
    const uuid = Uuid();

    debugPrint('Getting cash account (selected: $cashAccountId)...');
    final cashAccount = await _resolveCashAccount(cashAccountId);
    debugPrint('Cash account found: ${cashAccount['id']} - ${cashAccount['paymentmode_name']}');

    final paymentPayload = {
      "id": uuid.v4(),
      "currencyid": cashAccount['currency_id'],
      "categoryid": "44444444-1111-1111-1111-111111111111",
      "referenceid": saleId,
      "servicepointid": servicePointId,
      "transactiontypeid": 1,
      "amount": paymentAmount,
      "method": cashAccount['paymentmode_name'] ?? "Cash",
      "methodId": cashAccount['paymentmode_id'] ?? 1,
      "chequeno": "",
      "cashaccountid": cashAccount['id'],
      "paydate": paymentTimestamp,
      "receipt": true,
      "currency": cashAccount['currency_name'],
      "type": "Sales",
      "bp": customerId ?? "",
      "direction": 1,
      "gLProxySubCategoryId": "44444444-1111-1111-1111-111111111111",

    };
    
    debugPrint('Payment payload created: $paymentPayload');
    debugPrint('=== DEBUG: createPaymentPayload END ===');
    return paymentPayload;
  }

  // Save sale and payment locally to SQLite
  Future<Map<String, dynamic>> _saveSaleLocally({
    required String saleId,
    required String receiptnumber,
    required List<Map<String, dynamic>> cartItems,
    required double amountTendered,
    required String? customerId,
    required String? reference,
    required String? notes,
    required String actualSalespersonId,
    required String branchId,
    required String companyId,
    required String actualServicePointId,
    required String issuedByName,
    required String customerName,
    Map<String, dynamic>? cashAccount,
  }) async {
    const uuid = Uuid();
    final transactionTimestamp = DateTime.now().millisecondsSinceEpoch;

    // Calculate totals
    final totalAmount = calculateTotalAmount(cartItems);
    // Cap payment at total amount - excess is change returned to customer, not recorded as payment
    final paymentAmount = amountTendered > totalAmount ? totalAmount : amountTendered;
    final String accountModeName =
        cashAccount?['paymentmode_name']?.toString() ?? 'Cash';
    final paymentModeName = paymentAmount > 0 ? accountModeName : 'Pending';

    // Create sale transaction for each line item
    final List<Map<String, dynamic>> saleTransactions = [];

    for (int i = 0; i < cartItems.length; i++) {
      final item = cartItems[i];
      final inventoryItem = item['item'] as InventoryItem;
      final sellingPrice =
          (item['price'] as num?)?.toDouble() ?? inventoryItem.price;
      final quantity = (item['quantity'] as num).toDouble();
      final itemAmount = sellingPrice * quantity;
      // Calculate this item's share of the payment
      final itemPaymentShare = totalAmount > 0
          ? (itemAmount / totalAmount) * paymentAmount
          : 0.0;
      final itemBalance = itemAmount - itemPaymentShare;

      final transaction = {
        'id': uuid.v4(),
        'purchaseordernumber': reference ?? '',
        'internalrefno': 0,
        'issuedby': issuedByName,
        'receiptnumber': receiptnumber,
        'receivedby': '',
        'remarks': notes ?? '',
        'transactiondate': transactionTimestamp,
        'costcentre': '',
        'destinationbp': customerName,
        'paymentmode': paymentModeName,
        'sourcefacility': branchId,
        'genno': reference ?? '',
        'paymenttype': paymentModeName,
        'validtill': transactionTimestamp,
        'currency': 'Uganda Shillings',
        'quantity': quantity,
        'unitquantity': quantity,
        'amount': itemAmount,
        'amountpaid': itemPaymentShare,
        'balance': itemBalance,
        'sellingprice': sellingPrice,
        'costprice': inventoryItem.costprice ?? 0.0,
        'sellingprice_original': inventoryItem.price,
        'inventoryname': inventoryItem.name,
        'category': inventoryItem.category,
        'subcategory': '',
        'gnrtd': 0,
        'printed': 0,
        'redeemed': 0,
        'cancelled': 0,
        'patron': '',
        'department': '',
        'packsize': inventoryItem.packsize.toInt(),
        'packaging': inventoryItem.packaging,
        'complimentaryid': item['complimentary'] == true ? 1 : 0,
        'salesId': saleId,
        'upload_status': 'pending',
        'uploaded_at': null,
        'upload_error': null,
        'inventoryid': inventoryItem.id,
        'ipdid': inventoryItem.ipdid,
        'clientid': customerId,
        'companyid': companyId,
        'branchid': branchId,
        'servicepointid': actualServicePointId,
        'salespersonid': actualSalespersonId,
        'cashaccountid': paymentAmount > 0 ? (cashAccount?['id']) : null,
      };

      saleTransactions.add(transaction);
    }

    // Save all transactions to database
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (var transaction in saleTransactions) {
      batch.insert(
        'sales_transactions',
        transaction,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);

    return {
      'success': true,
      'hasPayment': paymentAmount > 0,
      'receiptnumber': receiptnumber,
      'saleId': saleId,
    };
  }

  // Process sale and payment
  Future<Map<String, dynamic>> processSaleAndPayment({
    required List<Map<String, dynamic>> cartItems,
    required double amountTendered,
    required String? customerId,
    required String? reference,
    required String? notes,
    required String? salespersonId,
    String? servicePointId,
    String? cashAccountId,
  }) async {
    if (cartItems.isEmpty) {
      throw Exception('No items in cart');
    }

    isProcessing.value = true;

    try {
      // Get user and company info - the locally logged-in user works offline
      await _ensureDatabaseOpen();
      final userData = await _apiService.getStoredUserData();
      final companyInfo = await _apiService.getCompanyInfo();
      final localUser = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>().currentUser.value
          : null;

      final userContext = _resolveUserContext(
        requestedSalespersonId: salespersonId,
        companyInfo: companyInfo,
        userData: userData,
        localUser: localUser,
      );

      final actualSalespersonId = userContext['salespersonId'];
      final branchId = userContext['branchId'];
      final companyId = userContext['companyId'];
      final actualServicePointId =
          servicePointId ?? companyInfo['servicePointId'] ?? branchId;
      final issuedByName = userContext['issuedByName'];

      // Get customer name
      String customerName = 'Cash Customer';
      if (customerId != null) {
        try {
          final customer = await _dbHelper.getCustomerById(customerId);
          if (customer != null) {
            customerName = customer.fullnames;
          }
        } catch (e) {
      }
      }

      // Generate receipt number and sale ID
      final receiptnumber = await generateReceiptNumber();
      const uuid = Uuid();
      final saleId = uuid.v4();

      // Save sale and payment to local database
      final result = await _saveSaleLocally(
        saleId: saleId,
        receiptnumber: receiptnumber,
        cartItems: cartItems,
        amountTendered: amountTendered,
        customerId: customerId,
        reference: reference,
        notes: notes,
        actualSalespersonId: actualSalespersonId,
        branchId: branchId,
        companyId: companyId,
        actualServicePointId: actualServicePointId,
        issuedByName: issuedByName,
        customerName: customerName,
        cashAccount: cashAccountId != null
            ? await _dbHelper.getCashAccountById(cashAccountId)
            : null,
      );

      await _attemptUploadAfterSave(saleId);

      return result;
    } catch (e) {
      rethrow;
    } finally {
      isProcessing.value = false;
    }
  }

  // Update existing sale
  Future<Map<String, dynamic>> updateSale({
    required String existingSalesId,
    required String existingReceiptNumber,
    required List<Map<String, dynamic>> cartItems,
    required double amountTendered,
    required String? customerId,
    required String? reference,
    required String? notes,
    required String? salespersonId,
    String? servicePointId,
    String? cashAccountId,
  }) async {
    if (cartItems.isEmpty) {
      throw Exception('No items in cart');
    }

    isProcessing.value = true;

    try {
      // Get user and company info - the locally logged-in user works offline
      await _ensureDatabaseOpen();
      final userData = await _apiService.getStoredUserData();
      final companyInfo = await _apiService.getCompanyInfo();
      final localUser = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>().currentUser.value
          : null;

      final userContext = _resolveUserContext(
        requestedSalespersonId: salespersonId,
        companyInfo: companyInfo,
        userData: userData,
        localUser: localUser,
      );

      final actualSalespersonId = userContext['salespersonId'];
      final branchId = userContext['branchId'];
      final companyId = userContext['companyId'];

      // Get original service point ID from existing sale to preserve it
      String actualServicePointId = servicePointId ?? '';
      if (actualServicePointId.isEmpty) {
        try {
          final existingTransactions = await _dbHelper
              .getSaleTransactionsBySalesId(existingSalesId);
          if (existingTransactions.isNotEmpty) {
            actualServicePointId =
                existingTransactions.first.servicepointid ?? '';
          }
        } catch (e) {
          // If can't get existing, fall back to current
          actualServicePointId = companyInfo['servicePointId'] ?? branchId;
        }
      }

      final issuedByName = userContext['issuedByName'];

      // Get customer name
      String customerName = 'Cash Customer';
      if (customerId != null) {
        try {
          final customer = await _dbHelper.getCustomerById(customerId);
          if (customer != null) {
            customerName = customer.fullnames;
          }
        } catch (e) {}
      }

      // Delete existing transactions for this sale
      final db = await _dbHelper.database;
      await db.delete(
        'sales_transactions',
        where: 'salesId = ?',
        whereArgs: [existingSalesId],
      );

      // Save updated sale with same salesId and receipt number
      final result = await _saveSaleLocally(
        saleId: existingSalesId,
        receiptnumber: existingReceiptNumber,
        cartItems: cartItems,
        amountTendered: amountTendered,
        customerId: customerId,
        reference: reference,
        notes: notes,
        actualSalespersonId: actualSalespersonId,
        branchId: branchId,
        companyId: companyId,
        actualServicePointId: actualServicePointId,
        issuedByName: issuedByName,
        customerName: customerName,
        cashAccount: cashAccountId != null
            ? await _dbHelper.getCashAccountById(cashAccountId)
            : null,
      );

      // Attempt to upload updated sale to server automatically
      await _attemptUploadAfterSave(existingSalesId);

      return result;
    } catch (e) {
      rethrow;
    } finally {
      isProcessing.value = false;
    }
  }

  // Calculate total amount from cart items
  double calculateTotalAmount(List<Map<String, dynamic>> cartItems) {
    return cartItems.fold(0, (sum, item) => sum + (item['amount'] as num));
  }

  // Calculate balance/change
  double calculateBalance(double amountTendered, double totalAmount) {
    return amountTendered - totalAmount;
  }

  // Validate payment
  bool validatePayment(double amountTendered, double totalAmount) {
    return amountTendered >= totalAmount;
  }

  // Settle an uploaded sale by posting payment directly
  Future<void> settleUploadedSale(
    String salesId,
    double amountTendered, {
    String? cashAccountId,
  }) async {
    debugPrint('=== DEBUG: settleUploadedSale START ===');
    debugPrint('salesId: $salesId');
    debugPrint('amountTendered: $amountTendered');
    
    try {
      isProcessing.value = true;

      debugPrint('Fetching transaction details from server...');
      // Fetch transaction details from server to get proper data
      final transactionData = await _apiService.fetchSingleTransaction(salesId);
      debugPrint('Transaction data fetched: $transactionData');

      // Calculate outstanding balance from server data
      final lineItemsList =
          transactionData['lineItems'] as List<dynamic>? ?? [];
      debugPrint('Line items count: ${lineItemsList.length}');
      
      final totalAmount = lineItemsList.fold<double>(
        0.0,
        (sum, item) =>
            sum + ((item['sellingprice'] ?? 0.0) * (item['quantity'] ?? 0.0)),
      );
      debugPrint('Total amount: $totalAmount');
      
      final currentPaid =
          double.tryParse(
            transactionData['amountpaid']?.toString() ??
                transactionData['amountPaid']?.toString() ??
                '0',
          ) ??
          0.0;
      debugPrint('Current paid: $currentPaid');
      
      final outstandingBalance = totalAmount - currentPaid;
      debugPrint('Outstanding balance: $outstandingBalance');

      // Only pay up to the outstanding balance
      final paymentAmount = amountTendered < outstandingBalance
          ? amountTendered
          : outstandingBalance;
      debugPrint('Payment amount to process: $paymentAmount');

      if (paymentAmount <= 0) {
        throw Exception('No payment amount to process');
      }

      // Get service point ID from transaction data
      final servicePointId = transactionData['servicepointid'] ?? '';
      final customerId = transactionData['clientid'];
      debugPrint('servicePointId: $servicePointId, customerId: $customerId');

      // Get current timestamp for payment
      final paymentTimestamp = DateTime.now().millisecondsSinceEpoch;
      debugPrint('paymentTimestamp: $paymentTimestamp');

      // Create payment payload
      debugPrint('Creating payment payload...');
      final paymentPayload = await createPaymentPayload(
        saleId: salesId,
        paymentAmount: paymentAmount,
        paymentTimestamp: paymentTimestamp,
        servicePointId: servicePointId,
        customerId: customerId,
        companyId: transactionData['companyId'],
        currencyid : transactionData['currencyid'],
        categoryid: "44444444-1111-1111-1111-111111111111",
        cashAccountId: cashAccountId,
      );
      final paymentModeName = paymentPayload['method'] ?? 'Cash';
      debugPrint('Payment payload created: $paymentPayload');

      // Log the payment payload being sent to server
      print('=== SETTLE BILL PAYMENT PAYLOAD BEING SENT TO SERVER ===');
      print('Sale ID: $salesId');
      print('Payment Amount: $paymentAmount');
      print('Payment Payload JSON:');
      print(paymentPayload);
      print('=== END SETTLE BILL PAYMENT PAYLOAD ===');

      // Post payment to server
      debugPrint('=== DEBUG: Posting payment to server ===');
      try {
        final response = await _apiService.postSale(paymentPayload);
        debugPrint('Server response: $response');
        debugPrint('=== DEBUG: Payment posted successfully ===');
      } catch (e) {
        debugPrint('=== DEBUG: ERROR posting payment: $e ===');
        rethrow;
      }

      // Update local database with new payment amount
      final saleTransactions = await _dbHelper.getSaleTransactionsBySalesId(
        salesId,
      );
      if (saleTransactions.isNotEmpty) {
        final db = await _dbHelper.database;
        final batch = db.batch();

        for (var transaction in saleTransactions) {
          // Calculate the share of this payment for this item
          final itemAmount = transaction.amount;
          final totalAmountLocal = saleTransactions.fold<double>(
            0,
            (sum, t) => sum + t.amount,
          );
          final currentPaidLocal = saleTransactions.fold<double>(
            0,
            (sum, t) => sum + t.amountpaid,
          );
          final itemShare = totalAmountLocal > 0
              ? (itemAmount / totalAmountLocal) * paymentAmount
              : 0.0;

          final newAmountPaid = transaction.amountpaid + itemShare;
          final newBalance = transaction.amount - newAmountPaid;

          batch.update(
            'sales_transactions',
            {
              'amountpaid': newAmountPaid,
              'balance': newBalance,
              'paymentmode': paymentModeName,
              'paymenttype': paymentModeName,
            },
            where: 'id = ?',
            whereArgs: [transaction.id],
          );
        }

        await batch.commit(noResult: true);
      }

      print('Payment posted successfully for sale $salesId');
    } catch (e) {
      print('Failed to settle bill for sale $salesId: $e');
      rethrow;
    } finally {
      isProcessing.value = false;
    }
  }

  // Attempt to upload sale to server after saving locally
  Future<void> _attemptUploadAfterSave(String saleId) async {
    try {
      if (!_settingsService.getAutoUploadEnabled()) {
        print('Auto upload is disabled - sale will be uploaded manually');
        return;
      }

      final hasConnection = await NetworkHelper.hasConnection();

      if (!hasConnection) {
        print(
          'No network connection - sale will be uploaded later when connection is available',
        );
        return;
      }

      print('Attempting to upload sale $saleId to server...');
      // Get the SalesController and upload the sale
      final salesController = Get.find<SalesController>();
      await salesController.uploadSaleToServer(saleId);

      print('Sale $saleId uploaded successfully');
    } catch (e) {
      // Upload failed - sale remains with 'pending' status for later retry
      print('Failed to upload sale $saleId: $e');
      print('Sale will be uploaded later when retrying from sales listing');
    }
  }

  // Public method to fetch transaction data
  Future<Map<String, dynamic>> fetchTransactionData(String salesId) async {
    return await _apiService.fetchSingleTransaction(salesId);
  }

  // Public method to get customer by ID
  Future<Customer?> getCustomerById(String clientId) async {
    return await _dbHelper.getCustomerById(clientId);
  }
}
