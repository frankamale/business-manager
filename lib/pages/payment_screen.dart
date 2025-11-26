import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/payment_controller.dart';

class PaymentScreen extends StatefulWidget {
   final List<Map<String, dynamic>> cartItems;
   final String? customer;
   final String? reference;
   final String? notes;
   final String? salespersonId;

   const PaymentScreen({
     super.key,
     required this.cartItems,
     this.customer,
     this.reference,
     this.notes,
     this.salespersonId,
   });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentController _paymentController = Get.find<PaymentController>();
  final NumberFormat _numberFormat = NumberFormat('#,###', 'en_US');
  final TextEditingController amountTenderedController = TextEditingController();

  String formatMoney(double amount) {
    return _numberFormat.format(amount.toInt());
  }

  double get totalAmount {
    return _paymentController.calculateTotalAmount(widget.cartItems);
  }

  double get amountTendered {
    final text = amountTenderedController.text.trim();
    return text.isNotEmpty ? double.tryParse(text) ?? 0.0 : 0.0;
  }

  double get balance {
    return _paymentController.calculateBalance(amountTendered, totalAmount);
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
      print(" saveBill: validation failed - no items in cart");
      Get.snackbar(
        'Error',
        'No items in cart',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
      return;
    }

    try {
      // Process sale and payment using controller
      final result = await _paymentController.processSaleAndPayment(
        cartItems: widget.cartItems,
        amountTendered: amountTendered,
        customerId: widget.customer,
        reference: widget.reference,
        notes: widget.notes,
        salespersonId: widget.salespersonId,
      );

      // Handle success
      final hasPayment = result['hasPayment'] as bool;
      final receiptnumber = result['receiptnumber'] as String;

      Get.back(result: true);

      if (hasPayment) {
        Get.snackbar(
          'Success',
          'Bill saved, posted, and payment processed successfully!\nReceipt: $receiptnumber',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
          duration: const Duration(seconds: 3),
        );
      } else {
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

      // Handle session expiry
      if (e.toString().contains("SESSION_EXPIRED")) {
        Get.snackbar(
          'Session Expired',
          'Your session has expired. Please login again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
        );
        Get.offAllNamed('/login');
      } else {
        Get.snackbar(
          'Error',
          'Failed to process payment: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Receipt Number
                    if (!isKeyboardVisible) ...[
                      Obx(() => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Receipt: ",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'REC-${_paymentController.receiptCounter.value.toString().padLeft(4, '0')}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 12),
                    ],

                    // Amount Due
                    _buildAmountRow(
                      "Amount Due",
                      totalAmount,
                      Colors.red[700]!,
                      fontSize: isKeyboardVisible ? 20 : 24,
                    ),
                    const SizedBox(height: 12),

                    // Amount Tendered Input
                    TextField(
                      controller: amountTenderedController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: isKeyboardVisible ? 18 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: "Amount Tendered",
                        labelStyle: const TextStyle(fontSize: 14),
                        prefixText: "UGX ",
                        prefixStyle: TextStyle(
                          fontSize: isKeyboardVisible ? 16 : 18,
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: isKeyboardVisible ? 10 : 12,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {}); // Rebuild to update balance
                      },
                    ),
                    const SizedBox(height: 12),

                    // Balance/Change
                    _buildAmountRow(
                      "Balance",
                      balance,
                      balance >= 0 ? Colors.green[700]! : Colors.red[700]!,
                      fontSize: isKeyboardVisible ? 20 : 24,
                    ),

                    if (balance < 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          "Insufficient payment",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Items Summary
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: isKeyboardVisible ? 100 : 200,
                      ),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Items:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: widget.cartItems.length,
                              itemBuilder: (context, index) {
                                final item = widget.cartItems[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "${item['name']} x${item['quantity']}",
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        "UGX ${formatMoney(item['amount'])}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
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
                  ],
                ),
              ),
            ),

            // Action Buttons (fixed at bottom)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Obx(() => Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _paymentController.isProcessing.value
                        ? null
                        : () => Get.back(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _paymentController.isProcessing.value
                        ? null
                        : _saveBillAndPayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _paymentController.isProcessing.value
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Save Bill",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, Color color, {double fontSize = 20}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
