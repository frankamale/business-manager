import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'inventory_items_screen.dart';
import '../models/inventory_item.dart';
import '../services/api_services.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final ApiService _apiService = Get.find<ApiService>();
  final NumberFormat _numberFormat = NumberFormat('#,###', 'en_US');
  bool _isProcessing = false;

  String formatMoney(double amount) {
    return _numberFormat.format(amount.toInt());
  }

  final List<String> customers = [
    "Walk-in Customer",
    "Customer 1",
    "Customer 2",
    "Customer 3",
    "Customer 4",
    "Customer 5",
  ];

  String? selectedCustomer;
  final TextEditingController refController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController amountPaidController = TextEditingController();
  int receiptCounter = 1;

  // Selected items
  final List<Map<String, dynamic>> selectedItems = [];

  double get totalAmount {
    return selectedItems.fold(0, (sum, item) => sum + (item['amount'] as num));
  }

  void _addItemToCart(InventoryItem item) {
    setState(() {
      // Check if item already exists in cart
      final existingItemIndex = selectedItems.indexWhere(
        (cartItem) => cartItem['id'] == item.id,
      );

      if (existingItemIndex != -1) {
        // Item exists, increase quantity
        selectedItems[existingItemIndex]['quantity'] += 1;
        selectedItems[existingItemIndex]['amount'] =
            selectedItems[existingItemIndex]['quantity'] * item.price;
      } else {
        // New item, add to cart
        selectedItems.add({
          'id': item.id,
          'name': item.name,
          'quantity': 1,
          'price': item.price,
          'amount': item.price,
          'item': item,
        });
      }
    });

    // Show success message
    Get.snackbar(
      'Item Added',
      '${item.name} added to cart',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      backgroundColor: Colors.green[100],
      colorText: Colors.green[900],
      margin: const EdgeInsets.all(8),
    );
  }

  void _removeItemFromCart(int index) {
    setState(() {
      selectedItems.removeAt(index);
    });
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItemFromCart(index);
      return;
    }

    setState(() {
      selectedItems[index]['quantity'] = newQuantity;
      selectedItems[index]['amount'] =
          newQuantity * selectedItems[index]['price'];
    });
  }

  @override
  void initState() {
    super.initState();
    selectedCustomer = customers[0];
  }

  @override
  void dispose() {
    refController.dispose();
    notesController.dispose();
    amountPaidController.dispose();
    super.dispose();
  }

  Future<void> _processSale() async {
    print("saveBill called");

    // Validation
    if (selectedItems.isEmpty) {
      print("saveBill: validation failed - no items in cart");
      Get.snackbar('Error', 'No items in cart',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900]);
      return;
    }
    print("saveBill: validation passed");

    setState(() => _isProcessing = true);

    try {
      // Get user and company info
      final userData = await _apiService.getStoredUserData();
      final companyInfo = await _apiService.getCompanyInfo();

      if (userData == null) {
        print("saveBill: userInfo not available");
        Get.snackbar('Error', 'User information not available. Please refresh and try again.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red[100],
            colorText: Colors.red[900]);
        return;
      }
      print("saveBill: userInfo available, proceeding");

      final userId = userData['userId'] ?? "00000000-0000-0000-0000-000000000000";
      final branchId = companyInfo['branchId'] ?? '';
      final companyId = companyInfo['companyId'] ?? '';
      final servicePointId = companyInfo['servicePointId'] ?? branchId;

      // Generate receipt number
      final receiptnumber = 'REC-${receiptCounter.toString().padLeft(4, '0')}';
      setState(() {
        receiptCounter++;
      });

      // Generate UUID for sale
      const uuid = Uuid();
      final saleId = uuid.v4();
      print("saveBill: generated saleId: $saleId");

      final transactionTimestamp = DateTime.now().millisecondsSinceEpoch;
      final dateReadyValue = notesController.text;
      print("saveBill: dateReadyValue: $dateReadyValue");

      // Create line items
      final lineItems = selectedItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final inventoryItem = item['item'] as InventoryItem;

        return {
          "itemName": inventoryItem.name,
          "category": inventoryItem.category ?? "",
          "notes": item['notes'] ?? "",
          "id": uuid.v4(),
          "costprice": 0.0,
          "packsize": inventoryItem.packsize ?? 1.0,
          "quantity": item['quantity'].toDouble(),
          "inventoryid": inventoryItem.id.toString(),
          "packagingid": servicePointId,
          "ipdid": "",
          "salesid": saleId,
          "transactionstatusid": 1,
          "servicepointid": null,
          "sellingprice": inventoryItem.price,
          "ordernumber": index,
          "complimentaryid": 0,
          "remarks": item['notes'] ?? "",
          "sellingprice_original": inventoryItem.price ?? 0.0,
        };
      }).toList();

      // Create sale payload
      final salePayload = {
        "id": saleId,
        "transactionDate": transactionTimestamp,
        "clientid": "00000000-0000-0000-0000-000000000000",
        "transactionstatusid": 1,
        "salespersonid": userId,
        "servicepointid": servicePointId,
        "modeid": 2,
        "remarks": dateReadyValue.isNotEmpty ? dateReadyValue : "New sale added",
        "otherRemarks": "",
        "branchId": branchId,
        "companyId": companyId,
        "glproxySubCategoryId": "44444444-4444-4444-4444-444444444444",
        "receiptnumber": receiptnumber,
        "saleActionId": 1,
        "lineItems": lineItems,
      };

      print("saveBill: about to post sale, saleData: $salePayload");
      final result = await _apiService.createSale(salePayload);
      print("saveBill: postSale result: $result");

      // Handle payment if amount is provided
      final amountPaidText = amountPaidController.text.trim();
      final amountPaid = amountPaidText.isNotEmpty ? double.tryParse(amountPaidText) ?? 0.0 : 0.0;
      print("saveBill: Amount paid: $amountPaid");

      if (amountPaid > 0) {
        print("saveBill: amountPaid > 0, proceeding to create payment");

        // Fetch the transaction to get its actual date
        final transactionData = await _apiService.fetchSingleTransaction(saleId);
        print('POS: Fetched transaction data: $transactionData');

        // Calculate the outstanding balance
        final lineItemsList = transactionData['lineItems'] as List<dynamic>? ?? [];
        final totalAmount = lineItemsList.fold<double>(
          0.0,
          (sum, item) => sum + ((item['sellingprice'] ?? 0.0) * (item['quantity'] ?? 0.0)),
        );
        final currentPaid = double.tryParse(transactionData['amountpaid']?.toString() ??
                                           transactionData['amountPaid']?.toString() ?? '0') ?? 0.0;
        final outstandingBalance = totalAmount - currentPaid;

        print('POS: Total amount: $totalAmount');
        print('POS: Current paid: $currentPaid');
        print('POS: Outstanding balance: $outstandingBalance');
        print('POS: Amount from form: $amountPaid');

        // Use the minimum of amountPaid or outstanding balance
        final paymentAmount = amountPaid < outstandingBalance ? amountPaid : outstandingBalance;
        print('POS: Final payment amount to send: $paymentAmount');

        // Get the transaction date
        int invoiceTimestamp = DateTime.now().millisecondsSinceEpoch;
        if (transactionData['transactiondate'] != null) {
          print('POS: Raw transactiondate from backend: ${transactionData['transactiondate']}');
          invoiceTimestamp = transactionData['transactiondate'];
        }
        print('POS: Invoice timestamp as date: ${DateTime.fromMillisecondsSinceEpoch(invoiceTimestamp).toIso8601String()}');

        // Add 2 seconds buffer (2000ms) to ensure payment date is after invoice date
        final paymentTimestamp = invoiceTimestamp + 2000;
        print('POS: Payment date (with 2s buffer, milliseconds): $paymentTimestamp');
        print('POS: Payment date as date: ${DateTime.fromMillisecondsSinceEpoch(paymentTimestamp).toIso8601String()}');

        final paymentPayload = {
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
          "bp": selectedCustomer ?? "",
          "direction": 1,
          "glproxySubCategoryId": "44444444-4444-4444-4444-444444444444",
        };

        print("saveBill: paymentPayload created: $paymentPayload");
        print("saveBill: about to post payment");

        try {
          final paymentResult = await _apiService.createPayment(paymentPayload);
          print("saveBill: postPayment result: $paymentResult");

          Get.snackbar(
            'Success',
            'Bill saved, posted, and payment processed successfully!',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green[100],
            colorText: Colors.green[900],
          );
        } catch (paymentError) {
          print("saveBill: payment error: $paymentError");
          Get.snackbar(
            'Partial Success',
            'Bill saved and posted, but payment failed: $paymentError',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange[100],
            colorText: Colors.orange[900],
            duration: const Duration(seconds: 5),
          );
        }
      } else {
        Get.snackbar(
          'Success',
          'Bill saved and posted successfully!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
        );
      }

      // Clear form
      setState(() {
        selectedItems.clear();
        refController.clear();
        notesController.clear();
        amountPaidController.clear();
        selectedCustomer = customers[0];
      });
    } catch (e) {
      print("saveBill: error: $e");

      // Check for authentication errors
      if (e.toString().contains("Full authentication is required")) {
        Get.snackbar(
          'Session Expired',
          'Your session has expired. Please login again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
        );
        await _apiService.clearAuthData();
        Get.offAllNamed('/login');
      } else {
        Get.snackbar(
          'Error',
          'Bill saved locally but failed to post: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          duration: const Duration(seconds: 5),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "POS Sale",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
          child: Column(
            children: [
              // Total Display
              Container(
                width: double.infinity,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "UGX ${formatMoney(totalAmount)}",
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Customer Dropdown
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text(
                      "Client:",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedCustomer,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      items: customers.map((String customer) {
                        return DropdownMenuItem<String>(
                          value: customer,
                          child: Text(customer),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedCustomer = newValue;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Reference Field
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text(
                      "Ref:",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: refController,
                      decoration: InputDecoration(
                        hintText: "Reference number",
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Notes Field
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text(
                      "Notes:",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        hintText: "Add notes",
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Amount Paid Field
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text(
                      "Paid:",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: amountPaidController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Amount paid (optional)",
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Selected Items Container
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                "Item",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              child: Text(
                                "Qty",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                "Amount",
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Items List
                      Expanded(
                        child: selectedItems.isEmpty
                            ? const Center(
                                child: Text(
                                  "No items selected",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: selectedItems.length,
                                itemBuilder: (context, index) {
                                  final item = selectedItems[index];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                'UGX ${formatMoney(item['price'])} each',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            InkWell(
                                              onTap: () => _updateQuantity(
                                                index,
                                                item['quantity'] - 1,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red[50],
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Icon(
                                                  Icons.remove,
                                                  size: 16,
                                                  color: Colors.red[700],
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              child: Text(
                                                "${item['quantity']}",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => _updateQuantity(
                                                index,
                                                item['quantity'] + 1,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.green[50],
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Icon(
                                                  Icons.add,
                                                  size: 16,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 80,
                                          child: Text(
                                            formatMoney(item['amount']),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processSale,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("PAY"),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedItems.clear();
                          refController.clear();
                          notesController.clear();
                          amountPaidController.clear();
                          selectedCustomer = customers[0];
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("New"),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.to(
                          () => InventoryItemsScreen(
                            onItemSelected: _addItemToCart,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.yellow[700],
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Items"),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Close"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
