import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../controllers/payment_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/sales_controller.dart';
import '../services/print_service.dart';
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
  final FocusNode _amountFocus = FocusNode();

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
    // Load existing sale data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSaleData();
      // ensure keyboard opens on the amount field when screen opens
      _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    amountTenderedController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSaleData() async {
    try {
      setState(() => isLoading = true);

      final transactionData = await _paymentController.fetchTransactionData(widget.salesId);

      final lineItemsList = transactionData['lineItems'] as List<dynamic>? ?? [];
      totalAmount = lineItemsList.fold<double>(
        0.0,
            (sum, item) => sum + ((item['sellingprice'] ?? 0.0) * (item['quantity'] ?? 0.0)),
      );

      currentPaid = double.tryParse(
        transactionData['amountpaid']?.toString() ?? transactionData['amountPaid']?.toString() ?? '0',
      ) ??
          0.0;

      outstandingBalance = totalAmount - currentPaid;

      final clientId = transactionData['clientid'];
      if (clientId != null) {
        try {
          final customer = await _paymentController.getCustomerById(clientId);
          if (customer != null) {
            customerName = customer.fullnames;
          }
        } catch (_) {}
      }

      notes = transactionData['remarks'] ?? '';

      final salesController = Get.find<SalesController>();
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
    // show integers with separators
    return _numberFormat.format(amount.round());
  }

  double get amountTendered {
    final text = amountTenderedController.text.replaceAll(',', '').trim();
    return text.isNotEmpty ? double.tryParse(text) ?? 0.0 : 0.0;
  }

  double get remainingBalanceAfterPayment {
    return (outstandingBalance - amountTendered).clamp(double.negativeInfinity, double.infinity);
  }

  Future<void> _settleBill() async {
    // Basic validations
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
      await _paymentController.settleUploadedSale(widget.salesId, amountTendered);

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
          // Print failures shouldn't block user
          debugPrint('Failed to print receipt: $printError');
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Settle Bill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header card (receipt + customer)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Receipt', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(widget.receiptNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Customer', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(customerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text('Notes: $notes', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Summary amounts
                    _SummaryRow(label: 'Total Amount', amount: totalAmount, color: Colors.black87),
                    const SizedBox(height: 10),
                    _SummaryRow(label: 'Amount Paid', amount: currentPaid, color: Colors.green[700]!),
                    const SizedBox(height: 10),
                    _SummaryRow(label: 'Outstanding Balance', amount: outstandingBalance, color: Colors.red[700]!),

                    const SizedBox(height: 18),

                    // Payment card
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Enter Payment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 10),

                            // Amount input with input formatter and grouped separators
                            TextFormField(
                              controller: amountTenderedController,
                              focusNode: _amountFocus,
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                              textInputAction: TextInputAction.done,
                              autofocus: true,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                ThousandsSeparatorInputFormatter(),
                              ],
                              decoration: InputDecoration(
                                prefixText: 'UGX ',
                                prefixStyle: const TextStyle(fontWeight: FontWeight.w600),
                                hintText: '0',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              onChanged: (_) => setState(() {}),
                              onFieldSubmitted: (_) async {
                                // Try to settle when user presses done
                                await _settleBill();
                              },
                            ),

                            const SizedBox(height: 12),

                            // Change / remaining balance
                            _SummaryRow(
                              label: 'Remaining Balance',
                              amount: remainingBalanceAfterPayment,
                              color: remainingBalanceAfterPayment >= 0 ? Colors.red[700]! : Colors.green[700]!,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Action buttons bottom
                    Padding(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 12, top: 12),
                      child: Obx(() => Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _paymentController.isProcessing.value ? null : () => Get.back(),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.grey[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _paymentController.isProcessing.value ? null : _settleBill,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _paymentController.isProcessing.value
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Settle Bill', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      )),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- Small reusable widgets & helpers ---

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryRow({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    final NumberFormat fmt = NumberFormat('#,###', 'en_US');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14 * 0.85, fontWeight: FontWeight.w600, color: color)),
          Text('UGX ${fmt.format(amount.abs().round())}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _fmt = NumberFormat('#,###');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String onlyDigits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (onlyDigits.isEmpty) return const TextEditingValue(text: '');

    final formatted = _fmt.format(int.parse(onlyDigits));

    // Maintain cursor position
    int selectionIndex = formatted.length - (onlyDigits.length - newValue.selection.end);
    if (selectionIndex < 0) selectionIndex = 0;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex.clamp(0, formatted.length)),
    );
  }
}
