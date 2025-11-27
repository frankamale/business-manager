import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
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
      "currencyid": "3a0e97b4-c13a-4a49-9205-182e62039a5a",
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
  }) async {
    const uuid = Uuid();
    final transactionTimestamp = DateTime.now().millisecondsSinceEpoch;

    // Calculate totals
    final totalAmount = calculateTotalAmount(cartItems);
    final paymentAmount = amountTendered;
    final balance = totalAmount - paymentAmount;

    // Create sale transaction for each line item
    final List<Map<String, dynamic>> saleTransactions = [];

    for (int i = 0; i < cartItems.length; i++) {
      final item = cartItems[i];
      final inventoryItem = item['item'] as InventoryItem;
      final sellingPrice = (item['price'] as num?)?.toDouble() ?? inventoryItem.price;
      final quantity = (item['quantity'] as num).toDouble();
      final itemAmount = sellingPrice * quantity;

      // Calculate this item's share of the payment
      final itemPaymentShare = totalAmount > 0 ? (itemAmount / totalAmount) * paymentAmount : 0.0;
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
        'paymentmode': paymentAmount > 0 ? 'Cash' : 'Pending',
        'sourcefacility': branchId,
        'genno': reference ?? '',
        'paymenttype': paymentAmount >= totalAmount ? 'Cash' : (paymentAmount > 0 ? 'Partial' : 'Pending'),
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
        'complimentaryid': 0,
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
      };

      saleTransactions.add(transaction);
    }

    // Save all transactions to database
    final db = await _dbHelper.database;
    final batch = db!.batch();

    for (var transaction in saleTransactions) {
      batch.insert(
        'sales_transactions',
        transaction,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('✅ Saved ${saleTransactions.length} sale transactions to local database');

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
      final actualServicePointId = servicePointId ?? companyInfo['servicePointId'] ?? branchId;
      final issuedByName = userData['staff'] ?? userData['name'] ?? '';

      // Get customer name
      String customerName = 'Cash Customer';
      if (customerId != null) {
        try {
          final customer = await _dbHelper.getCustomerById(customerId);
          if (customer != null) {
            customerName = customer.fullnames;
          }
        } catch (e) {
          print('⚠️ Could not fetch customer name: $e');
        }
      }

      // Generate receipt number and sale ID
      final receiptnumber = await generateReceiptNumber();
      const uuid = Uuid();
      final saleId = uuid.v4();

      // Save sale and payment to local database
      print('💾 Saving sale to local database...');
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
      );
      print('✅ Sale saved locally');

      return result;
    } catch (e) {
      print('❌ Error processing sale and payment: $e');
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

