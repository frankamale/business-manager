import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../services/api_services.dart';
import '../models/inventory_item.dart';
import '../database/db_helper.dart';

class PaymentController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();
  final DatabaseHelper _dbHelper = DatabaseHelper();

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
        final numericPart = latestReceiptNumber.replaceAll(RegExp(r'[^0-9]'), '');
        if (numericPart.isNotEmpty) {
          final latestNumber = int.tryParse(numericPart) ?? 0;
          receiptCounter.value = latestNumber + 1;
          print('📊 Receipt counter initialized to: ${receiptCounter.value}');
        }
      } else {
        print('📊 No existing receipts found, starting from 1');
      }
    } catch (e) {
      print('⚠️ Error initializing receipt counter: $e');
      // Default to 1 if there's an error
      receiptCounter.value = 1;
    }
  }

  // Get the latest receipt number from database
  Future<String?> _getLatestReceiptNumber() async {
    try {
      final db = await _dbHelper.database;
      if (db == null) {
        print('⚠️ Database is null, cannot fetch latest receipt number');
        return null;
      }

      final result = await db.rawQuery(
        'SELECT receiptnumber FROM sales_transactions ORDER BY transactiondate DESC LIMIT 1'
      );

      if (result.isNotEmpty) {
        return result.first['receiptnumber'] as String?;
      }
      return null;
    } catch (e) {
      print('⚠️ Error fetching latest receipt number: $e');
      return null;
    }
  }

  // Generate unique receipt number
  Future<String> generateReceiptNumber() async {
    String number = 'REC-${receiptCounter.value.toString().padLeft(4, '0')}';

    // Safety check: ensure this number doesn't exist in database
    bool exists = await _receiptNumberExists(number);

    // If it exists, keep incrementing until we find a unique one
    while (exists) {
      print('⚠️ Receipt number $number already exists, incrementing...');
      receiptCounter.value++;
      number = 'REC-${receiptCounter.value.toString().padLeft(4, '0')}';
      exists = await _receiptNumberExists(number);
    }

    // Increment counter for next receipt
    receiptCounter.value++;

    print('✅ Generated unique receipt number: $number');
    return number;
  }

  // Check if receipt number already exists in database
  Future<bool> _receiptNumberExists(String receiptNumber) async {
    try {
      final db = await _dbHelper.database;
      if (db == null) {
        print('⚠️ Database is null, cannot check receipt number existence');
        return false;
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales_transactions WHERE receiptnumber = ?',
        [receiptNumber]
      );

      final count = result.first['count'] as int;
      return count > 0;
    } catch (e) {
      print('⚠️ Error checking receipt number existence: $e');
      return false; // Assume doesn't exist on error
    }
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
      final sellingPrice = (item['price'] as num?)?.toDouble() ?? inventoryItem.price;

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
        "sellingprice_original": (inventoryItem.price ?? 0.0).toInt(),
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
      "glproxySubCategoryId": "44444444-4444-4444-4444-444444444444",
      "lineItems": lineItems,
      "saleActionId": 1,
    };
  }

  // Create payment payload
  Map<String, dynamic> createPaymentPayload({
    required String saleId,
    required double paymentAmount,
    required int paymentTimestamp,
    required String servicePointId,
    required String? customerId,
    required String? companyId,
  }) {
    const uuid = Uuid();

    return {
      "id": uuid.v4(),
      "currencyid": companyId,
      "referenceid": saleId,
      "servicepointid": servicePointId,
      "transactiontypeid": 1,
      "amount": paymentAmount,
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
  }

  // Process sale and payment
  Future<Map<String, dynamic>> processSaleAndPayment({
    required List<Map<String, dynamic>> cartItems,
    required double amountTendered,
    required String? customerId,
    required String? reference,
    required String? notes,
    required String? salespersonId,
  }) async {
    if (cartItems.isEmpty) {
      throw Exception('No items in cart');
    }

    isProcessing.value = true;

    try {
      // Get user and company info
      final userData = await _apiService.getStoredUserData();
      final companyInfo = await _apiService.getCompanyInfo();

      if (userData == null) {
        throw Exception('User information not available. Please refresh and try again.');
      }

      final userId = userData['userId'] ?? "00000000-0000-0000-0000-000000000000";
      final actualSalespersonId = salespersonId ??
        userData['salespersonid'] ??
        userData['staffid'] ??
        userId;
      final branchId = companyInfo['branchId'] ?? '';
      final companyId = companyInfo['companyId'] ?? '';
      final servicePointId = companyInfo['servicePointId'] ?? branchId;

      // Generate receipt number and sale ID
      final receiptnumber = await generateReceiptNumber();
      const uuid = Uuid();
      final saleId = uuid.v4();

      // Create sale payload
      final salePayload = createSalePayload(
        saleId: saleId,
        cartItems: cartItems,
        receiptnumber: receiptnumber,
        customerId: customerId,
        salespersonId: actualSalespersonId,
        remarks: notes ?? "",
        branchId: branchId,
        companyId: companyId,
        servicePointId: servicePointId,
      );

      // Create sale
      print('📤 Creating sale...');
      final saleResult = await _apiService.createSale(salePayload);
      print('✅ Sale created successfully');

      // Process payment if amount tendered > 0
      if (amountTendered > 0) {
        print('💵 Processing payment of $amountTendered...');

        // Fetch transaction details
        final transactionData = await _apiService.fetchSingleTransaction(saleId);

        // Calculate payment amount
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

        // Use minimum of amountTendered or outstanding balance
        final paymentAmount = amountTendered < outstandingBalance
          ? amountTendered
          : outstandingBalance;

        // Get transaction date
        int invoiceTimestamp = DateTime.now().millisecondsSinceEpoch;
        if (transactionData['transactiondate'] != null) {
          invoiceTimestamp = transactionData['transactiondate'];
        }

        // Add 2 seconds buffer to ensure payment is after invoice
        final paymentTimestamp = invoiceTimestamp + 2000;

        print('📅 Invoice timestamp: $invoiceTimestamp');
        print('📅 Payment timestamp: $paymentTimestamp');

        // Create payment payload
        final paymentPayload = createPaymentPayload(
          saleId: saleId,
          paymentAmount: paymentAmount,
          paymentTimestamp: paymentTimestamp,
          servicePointId: servicePointId,
          customerId: customerId,
          companyId: companyId,
        );

        // Post payment
        print('📤 Posting payment...');
        final paymentResult = await _apiService.postSale(paymentPayload);
        print('✅ Payment posted successfully');

        return {
          'success': true,
          'hasPayment': true,
          'receiptnumber': receiptnumber,
          'saleId': saleId,
          'saleResult': saleResult,
          'paymentResult': paymentResult,
        };
      } else {
        // No payment, just sale
        print('ℹ️ No payment processed (amount tendered = 0)');

        return {
          'success': true,
          'hasPayment': false,
          'receiptnumber': receiptnumber,
          'saleId': saleId,
          'saleResult': saleResult,
        };
      }
    } catch (e) {
      print('❌ Error processing sale and payment: $e');

      // Check for authentication errors
      if (e.toString().contains("Full authentication is required")) {
        await _apiService.clearAuthData();
        throw Exception('SESSION_EXPIRED');
      }

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
}

