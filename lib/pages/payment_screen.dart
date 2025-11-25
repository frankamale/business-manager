import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/inventory_item.dart';
import '../services/api_services.dart';

class PaymentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final String? customer;
  final String? reference;
  final String? notes;

  const PaymentScreen({
    super.key,
    required this.cartItems,
    this.customer,
    this.reference,
    this.notes,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiService _apiService = Get.find<ApiService>();
  final NumberFormat _numberFormat = NumberFormat('#,###', 'en_US');
  final TextEditingController amountTenderedController = TextEditingController();
  bool _isProcessing = false;
  int receiptCounter = 1;

  String formatMoney(double amount) {
    return _numberFormat.format(amount.toInt());
  }

  double get totalAmount {
    return widget.cartItems.fold(0, (sum, item) => sum + (item['amount'] as num));
  }

  double get amountTendered {
    final text = amountTenderedController.text.trim();
    return text.isNotEmpty ? double.tryParse(text) ?? 0.0 : 0.0;
  }

  double get balance {
    return amountTendered - totalAmount;
  }

  @override
  void dispose() {
    amountTenderedController.dispose();
    super.dispose();
  }

  Future<void> _saveBillAndPayment() async {
    print("saveBill called");

    // Validation
    if (widget.cartItems.isEmpty) {
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
      final dateReadyValue = widget.notes ?? "";
      print("saveBill: dateReadyValue: $dateReadyValue");

      // Create line items matching DtoSaleDetail interface
      final lineItems = widget.cartItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final inventoryItem = item['item'] as InventoryItem;

        return {
          "id": uuid.v4(),
          "salesid": saleId,
          "inventoryid": inventoryItem.id,
          "ipdid": inventoryItem.ipdid,
          "quantity": (item['quantity'] as num).toInt(),
          "packsize": (inventoryItem.packsize ?? 1.0).toInt(),
          "sellingprice": inventoryItem.price.toInt(),
          "ordernumber": index,
          "remarks": item['notes'] ?? "",
          "transactionstatusid": 1,
          "sellingprice_original": (inventoryItem.price ?? 0.0).toInt(),
          "itemName": inventoryItem.name,
          "category": inventoryItem.category ?? "",
          "notes": item['notes'] ?? "",
          "costprice": 0,
          "packagingid": servicePointId,
          "servicepointid": null,
          "complimentaryid": 0,
        };
      }).toList();

      // Create sale payload matching SaleEntry interface
      final salePayload = {
        "id": saleId,
        "transactionDate": transactionTimestamp,
        "transactionstatusid": 1,
        "receiptnumber": receiptnumber,
        "clientid": "00000000-0000-0000-0000-000000000000",
        "remarks": dateReadyValue.isNotEmpty ? dateReadyValue : "New sale added",
        "otherRemarks": "",
        "companyId": companyId,
        "branchId": branchId,
        "servicepointid": servicePointId,
        "salespersonid": "da040b68-b5f9-4022-907d-13110d022e9c",
        "modeid": 2,
        "glproxySubCategoryId": "44444444-4444-4444-4444-444444444444",
        "lineItems": lineItems,
        "saleActionId": 1,
      };

      print("═══════════════════════════════════════════════════");
      print("saveBill: VALIDATION CHECKS");
      print("═══════════════════════════════════════════════════");
      print("✓ userId (salespersonid): $userId");
      print("✓ branchId: $branchId");
      print("✓ companyId: $companyId");
      print("✓ servicePointId: $servicePointId");
      print("✓ Line items count: ${lineItems.length}");
      print("✓ Transaction timestamp: $transactionTimestamp (${DateTime.fromMillisecondsSinceEpoch(transactionTimestamp)})");
      print("✓ Receipt number: $receiptnumber");
      print("═══════════════════════════════════════════════════");

      // STEP 1: Save the bill first (like React app)
      print("saveBill: about to post sale, saleData:");
      final result = await _apiService.createSale(salePayload);
      print("saveBill: postSale result: $result");

      // STEP 2: Handle payment if amount is provided (after sale is successfully saved)
      final amountPaid = amountTendered;
      print("saveBill: Amount paid from form: $amountPaid");

      if (amountPaid > 0) {
        print("saveBill: amountPaid > 0, proceeding to create payment");

        // Fetch the transaction to get its actual date (same approach as React bill listing)
        final transactionData = await _apiService.fetchSingleTransaction(saleId);
        print('POS: Fetched transaction data: $transactionData');

        // Calculate the outstanding balance
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

        print('POS: Total amount: $totalAmount');
        print('POS: Current paid: $currentPaid');
        print('POS: Outstanding balance: $outstandingBalance');
        print('POS: Amount from form: $amountPaid');

        // Use the minimum of amountPaid or outstanding balance
        final paymentAmount = amountPaid < outstandingBalance ? amountPaid : outstandingBalance;
        print('POS: Final payment amount to send: $paymentAmount');

        // Get the transaction date - keep it in the same format as backend stored it
        int invoiceTimestamp = DateTime.now().millisecondsSinceEpoch; // Default to now in milliseconds
        if (transactionData['transactiondate'] != null) {
          print('POS: Raw transactiondate from backend: ${transactionData['transactiondate']}');
          // Backend stores in milliseconds, so use it directly
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
          "bp": widget.customer ?? "",
          "direction": 1,
          "glproxySubCategoryId": "44444444-4444-4444-4444-444444444444",
        };

        print("saveBill: paymentPayload created: $paymentPayload");
        print("saveBill: about to post payment");

        try {
          final paymentResult = await _apiService.createPayment(paymentPayload);
          print("saveBill: postPayment result: $paymentResult");

          Get.back(result: true); // Return to POS screen
          Get.snackbar(
            'Success',
            'Bill saved, posted, and payment processed successfully!\nReceipt: $receiptnumber',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green[100],
            colorText: Colors.green[900],
            duration: const Duration(seconds: 3),
          );
        } catch (paymentError) {
          print("saveBill: payment error: $paymentError");
          Get.back(result: true); // Return to POS screen
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
        // No payment, just bill saved
        Get.back(result: true); // Return to POS screen
        Get.snackbar(
          'Success',
          'Bill saved and posted successfully!\nReceipt: $receiptnumber',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
          duration: const Duration(seconds: 3),
        );
      }
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
          "Payment",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Receipt Number
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Receipt Number",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'REC-${receiptCounter.toString().padLeft(4, '0')}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Amount Due
              _buildAmountRow(
                "Amount Due",
                totalAmount,
                Colors.red[700]!,
                fontSize: 28,
              ),
              const SizedBox(height: 16),

              // Amount Tendered Input
              TextField(
                controller: amountTenderedController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: "Amount Tendered",
                  labelStyle: const TextStyle(fontSize: 16),
                  prefixText: "UGX ",
                  prefixStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue[300]!, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue[200]!, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) {
                  setState(() {}); // Rebuild to update balance
                },
              ),
              const SizedBox(height: 16),

              // Balance/Change
              _buildAmountRow(
                "Balance",
                balance,
                balance >= 0 ? Colors.green[700]! : Colors.red[700]!,
                fontSize: 28,
              ),
              const SizedBox(height: 8),

              if (balance < 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "Insufficient payment",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const Spacer(),

              // Items Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Items:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...widget.cartItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${item['name']} x${item['quantity']}",
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            "UGX ${formatMoney(item['amount'])}",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Get.back(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _saveBillAndPayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green[700],
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
                          : const Text(
                              "Save Bill",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
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

  Widget _buildAmountRow(String label, double amount, Color color, {double fontSize = 20}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha((255 * 0.3).round())),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize * 0.6,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            "UGX ${formatMoney(amount.abs())}",
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
