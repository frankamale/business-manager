import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../services/api_services.dart';
import '../models/inventory_item.dart';

class PaymentController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();

  // Reactive state
  var isProcessing = false.obs;
  var receiptCounter = 1.obs;

  // Generate unique receipt number
  String generateReceiptNumber() {
    final number = 'REC-${receiptCounter.value.toString().padLeft(4, '0')}';
    receiptCounter.value++;
    return number;
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
        "packsize": (inventoryItem.packsize ?? 1.0).toInt(),
        "sellingprice": sellingPrice.toInt(),
        "ordernumber": index,
        "remarks": item['notes'] ?? "",
        "transactionstatusid": 1,
        "sellingprice_original": (inventoryItem.price ?? 0.0).toInt(),
        "itemName": inventoryItem.name,
        "category": inventoryItem.category ?? "",
        "notes": item['notes'] ?? "",
        "costprice": inventoryItem.costprice ?? 0.0,
        "packagingid": servicePointId,
        "servicepointid": null,
        "complimentaryid": 0,
      };
    }).toList();

    // Create sale payload
    return {
      "id": saleId,
      "transactionDate": transactionTimestamp,
      "transactionstatusid": 1,
      "receiptnumber": receiptnumber,
      "clientid": customerId ?? "00000000-0000-0000-0000-000000000000",
      "remarks": remarks.isNotEmpty ? remarks : "New sale added",
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
  }) {
    const uuid = Uuid();

    return {
      "id": uuid.v4(),
      "currencyid": "aa7eed85-3c4e-42df-b0aa-0337009bee85",
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
      final receiptnumber = generateReceiptNumber();
      const uuid = Uuid();
      final saleId = uuid.v4();

      print('💰 Processing sale: $saleId with receipt: $receiptnumber');

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
