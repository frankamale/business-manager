import 'package:bac_pos/services/api_services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/payment_controller.dart';
import '../controllers/auth_controller.dart';
import '../services/print_service.dart';
import '../database/db_helper.dart';
import '../models/sale_transaction.dart';

class SettleBillScreen extends StatefulWidget {
  final String salesId;
  final String receiptNumber;

  const SettleBillScreen({
    super.key,
    required this.salesId,
    required this.receiptNumber,
  });

  @override
  State<SettleBillScreen> createState() => _SettleBillScreenState();
}

class _SettleBillScreenState extends State<SettleBillScreen> {
  final PaymentController _paymentController = Get.find<PaymentController>();
  final NumberFormat _numberFormat = NumberFormat('#,###', 'en_US');
  final TextEditingController amountTenderedController = TextEditingController();
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  double totalAmount = 0.0;
  double currentPaid = 0.0;
  double outstandingBalance = 0.0;
  String customerName = 'Cash Customer';
  String notes = '';
  List<SaleTransaction> saleTransactions = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSaleData();
  }

  @override
  void dispose() {
    amountTenderedController.dispose();
    super.dispose();
  }

  Future<void> _loadSaleData() async {
    try {
      setState(() => isLoading = true);

      // Fetch sale data from server
      final transactionData = await _paymentController._apiService.fetchSingleTransaction(widget.salesId);

      // Calculate totals from server data
      final lineItemsList = transactionData['lineItems'] as List<dynamic>? ?? [];
      totalAmount = lineItemsList.fold<double>(
        0.0,
        (sum, item) => sum + ((item['sellingprice'] ?? 0.0) * (item['quantity'] ?? 0.0)),
      );
      currentPaid = double.tryParse(
        transactionData['amountpaid']?.toString() ??
        transactionData['amountPaid']?.toString() ?? '0'
      ) ?? 0.0;
      outstandingBalance = totalAmount - currentPaid;

      // Get customer name from local DB if available
      final clientId = transactionData['clientid'];
      if (clientId != null) {
        try {
          final customer = await _paymentController._dbHelper.getCustomerById(clientId);
          if (customer != null) {
            customerName = customer.fullnames;
          }
        } catch (e) {
          // Use default
        }
      }

      notes = transactionData['remarks'] ?? '';

      // Also fetch local transactions for printing
      final salesController = Get.find();
      saleTransactions = await salesController.getSaleTransactionsBySalesId(widget.salesId);

    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load sale data: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  String formatMoney(double amount) {
    return _numberFormat.format(amount.toInt());
  }

  double get amountTendered {
    final text = amountTenderedController.text.trim();
    return text.isNotEmpty ? double.tryParse(text) ?? 0.0 : 0.0;
  }

  double get balance {
    return amountTendered - outstandingBalance;
  }

  Future<void> _settleBill() async {
    if (amountTendered <= 0) {
      Get.snackbar(
        'Error',
        'Please enter a valid amount',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
      return;
    }

    if (amountTendered > outstandingBalance) {
      Get.snackbar(
        'Error',
        'Amount tendered cannot exceed outstanding balance',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
      return;
    }

    try {
      // Call the settle function
      await _paymentController.settleUploadedSale(widget.salesId, amountTendered);

      // Print receipt
      if (saleTransactions.isNotEmpty) {
        final firstTransaction = saleTransactions.first;
        final date = DateTime.fromMillisecondsSinceEpoch(firstTransaction.transactiondate);

        String cashierName = 'Cashier';
        final currentUser = Get.find<AuthController>().currentUser.value;
        if (currentUser != null) {
          cashierName = currentUser.staff ?? currentUser.name ?? 'Cashier';
        }

        try {
          await PrintService.printReceipt(
            receiptNumber: widget.receiptNumber,
            customerName: customerName,
            date: date,
            items: saleTransactions,
            totalAmount: totalAmount,
            amountPaid: currentPaid + amountTendered,
            balance: outstandingBalance - amountTendered,
            paymentMode: 'Cash',
            issuedBy: cashierName,
            notes: notes.isNotEmpty ? notes : null,
          );
        } catch (printError) {
          print('Failed to print receipt: $printError');
        }
      }

      Get.back(result: true);

      Get.snackbar(
        'Success',
        'Bill settled successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green[100],
        colorText: Colors.green[900],
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to settle bill: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
        duration: const Duration(seconds: 5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Settle Bill", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.blue,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          "Settle Bill",
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
                      Container(
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
                              widget.receiptNumber,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Total Amount
                    _buildAmountRow(
                      "Total Amount",
                      totalAmount,
                      Colors.black87,
                      fontSize: isKeyboardVisible ? 20 : 24,
                    ),
                    const SizedBox(height: 12),

                    // Current Paid
                    _buildAmountRow(
                      "Amount Paid",
                      currentPaid,
                      Colors.green[700]!,
                      fontSize: isKeyboardVisible ? 18 : 20,
                    ),
                    const SizedBox(height: 12),

                    // Outstanding Balance
                    _buildAmountRow(
                      "Outstanding Balance",
                      outstandingBalance,
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
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),

                    // Balance/Change
                    _buildAmountRow(
                      "Change",
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

                    // Customer and Notes
                    if (!isKeyboardVisible) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Customer: $customerName",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Notes: $notes",
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action Buttons
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
                        : _settleBill,
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
                              "Settle Bill",
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