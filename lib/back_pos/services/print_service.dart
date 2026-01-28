import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/sale_transaction.dart';
import '../config.dart';

class PrintService {
  static final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  // Generate receipt PDF
  static Future<Uint8List> generateReceiptPdf({
    required String receiptNumber,
    required String customerName,
    required DateTime date,
    required List<SaleTransaction> items,
    required double totalAmount,
    required double amountPaid,
    required double balance,
    required String paymentMode,
    String? issuedBy,
    String? notes,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: pw.EdgeInsets.all(8),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Company Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      AppConfig.companyName,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      AppConfig.description,
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'SALES RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),

              // Receipt Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Receipt No:', style: pw.TextStyle(fontSize: 12)),
                  pw.Text(receiptNumber,
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date:', style: pw.TextStyle(fontSize: 12)),
                  pw.Text(_dateFormat.format(date),
                      style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Issued By:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(issuedBy ?? 'Cashier', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer:', style: pw.TextStyle(fontSize: 12)),
                  pw.Text(customerName, style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1),

              // Items Header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('Item',
                        style: pw.TextStyle(
                            fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text('Qty',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('Price',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('Amount',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items List
              ...items.map((item) => pw.Column(
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              item.inventoryname,
                              style: pw.TextStyle(fontSize: 10),
                              maxLines: 2,
                            ),
                          ),
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text(
                              item.quantity.toStringAsFixed(0),
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              _currencyFormat.format(item.sellingprice),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              _currencyFormat.format(item.amount),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                    ],
                  )),

              pw.Divider(thickness: 1),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:',
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text('UGX ${_currencyFormat.format(totalAmount)}',
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Paid:', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('UGX ${_currencyFormat.format(amountPaid)}',
                      style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              if (balance > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Balance:', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('UGX ${_currencyFormat.format(balance)}',
                        style: pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment Mode:', style: pw.TextStyle(fontSize: 12)),
                  pw.Text(paymentMode, style: pw.TextStyle(fontSize: 12)),
                ],
              ),

              if (notes != null && notes.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5),
                pw.Text('Notes:', style: pw.TextStyle(fontSize: 11)),
                pw.Text(notes, style: pw.TextStyle(fontSize: 10)),
              ],

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Thank you for your business!',
                        style: pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 2),
                    pw.Text('Goods sold are not returnable',
                        style: pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      AppConfig.copyright,
                      style: pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Generate bill PDF
  static Future<Uint8List> generateBillPdf({
    required String receiptNumber,
    required String customerName,
    required DateTime date,
    required List<SaleTransaction> items,
    required double totalAmount,
    String? issuedBy,
    String? notes,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: pw.EdgeInsets.all(8),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Company Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      AppConfig.companyName,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      AppConfig.description,
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'BILL',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),

              // Bill Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill No:', style: pw.TextStyle(fontSize: 12)),
                  pw.Text(receiptNumber,
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date:', style: pw.TextStyle(fontSize: 12)),
                  pw.Text(_dateFormat.format(date),
                      style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Issued By:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(issuedBy ?? 'Cashier', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer:', style: pw.TextStyle(fontSize: 12)),
                  pw.Text(customerName, style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1),

              // Items Header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('Item',
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text('Qty',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('Price',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('Amount',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items List
              ...items.map((item) => pw.Column(
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              item.inventoryname,
                              style: pw.TextStyle(fontSize: 10),
                              maxLines: 2,
                            ),
                          ),
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text(
                              item.quantity.toStringAsFixed(0),
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              _currencyFormat.format(item.sellingprice),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              _currencyFormat.format(item.amount),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                    ],
                  )),

              pw.Divider(thickness: 1),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL DUE:',
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text('UGX ${_currencyFormat.format(totalAmount)}',
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 8),

              if (notes != null && notes.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5),
                pw.Text('Notes:', style: pw.TextStyle(fontSize: 11)),
                pw.Text(notes, style: pw.TextStyle(fontSize: 10)),
              ],

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Thank you for your business!',
                        style: pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 2),
                    pw.Text('Goods sold are not returnable',
                        style: pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      AppConfig.copyright,
                      style: pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printBill({
    required String receiptNumber,
    required String customerName,
    required DateTime date,
    required List<SaleTransaction> items,
    required double totalAmount,
    String? issuedBy,
    String? notes,
  }) async {
    final pdfBytes = await generateBillPdf(
      receiptNumber: receiptNumber,
      customerName: customerName,
      date: date,
      items: items,
      totalAmount: totalAmount,
      issuedBy: issuedBy,
      notes: notes,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  // Share bill as PDF
  static Future<void> shareBill({
    required String receiptNumber,
    required String customerName,
    required DateTime date,
    required List<SaleTransaction> items,
    required double totalAmount,
    String? issuedBy,
    String? notes,
  }) async {
    final pdfBytes = await generateBillPdf(
      receiptNumber: receiptNumber,
      customerName: customerName,
      date: date,
      items: items,
      totalAmount: totalAmount,
      issuedBy: issuedBy,
      notes: notes,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'bill_$receiptNumber.pdf',
    );
  }

  // Print receipt (works on smartphones and tablets)
  static Future<void> printReceipt({
    required String receiptNumber,
    required String customerName,
    required DateTime date,
    required List<SaleTransaction> items,
    required double totalAmount,
    required double amountPaid,
    required double balance,
    required String paymentMode,
    String? issuedBy,
    String? notes,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      receiptNumber: receiptNumber,
      customerName: customerName,
      date: date,
      items: items,
      totalAmount: totalAmount,
      amountPaid: amountPaid,
      balance: balance,
      paymentMode: paymentMode,
      issuedBy: issuedBy,
      notes: notes,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  // Share receipt as PDF
  static Future<void> shareReceipt({
    required String receiptNumber,
    required String customerName,
    required DateTime date,
    required List<SaleTransaction> items,
    required double totalAmount,
    required double amountPaid,
    required double balance,
    required String paymentMode,
    String? issuedBy,
    String? notes,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      receiptNumber: receiptNumber,
      customerName: customerName,
      date: date,
      items: items,
      totalAmount: totalAmount,
      amountPaid: amountPaid,
      balance: balance,
      paymentMode: paymentMode,
      issuedBy: issuedBy,
      notes: notes,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'receipt_$receiptNumber.pdf',
    );
  }

  // Generate daily summary PDF for thermal receipt printer (80mm roll)
  static Future<Uint8List> generateDailySummaryPdf({
    required DateTime date,
    required double totalSales,
    required double fullyPaidAmount,
    required double partialPaymentAmount,
    required double pendingAmount,
    required int totalTransactions,
    required int fullyPaidTransactions,
    required int partialPaymentTransactions,
    required int unpaidTransactions,
    required List<Map<String, dynamic>> paymentSummary,
    required List<Map<String, dynamic>> categorySummary,
    double? complementaryTotal,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: pw.EdgeInsets.all(8),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      AppConfig.companyName,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'DAILY SUMMARY',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      DateFormat('dd MMM yyyy').format(date),
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Transactions: $totalTransactions',
                  style: pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 6),
              _buildDottedLine(),
              pw.SizedBox(height: 6),

              // Payment Methods Section - amounts received
              pw.Center(
                child: pw.Text(
                  'PAYMENTS RECEIVED',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 6),

              // List each payment method
              ...paymentSummary.where((payment) {
                final type = (payment['paymenttype'] as String? ?? '').toLowerCase();
                return type != 'pending' && type.isNotEmpty;
              }).map((payment) {
                final type = payment['paymenttype'] as String? ?? 'Unknown';
                final amount = (payment['totalPaid'] as num?)?.toDouble() ?? 0.0;
                return pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: 3),
                  child: _buildReceiptRow(type, amount),
                );
              }),

              pw.SizedBox(height: 4),
              _buildDottedLine(),
              pw.SizedBox(height: 6),

              // Pending - amount yet to be paid
              _buildReceiptRow('PENDING', pendingAmount, isBold: true),
              pw.SizedBox(height: 2),
              pw.Text(
                '  (Not yet paid)',
                style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
              ),

              pw.SizedBox(height: 6),
              _buildDottedLine(),
              pw.SizedBox(height: 6),

              // Total - all sales
              _buildReceiptRow('TOTAL SALES', totalSales, isBold: true, fontSize: 12),

              pw.SizedBox(height: 8),
              _buildDottedLine(),
              pw.SizedBox(height: 6),

              // Category Breakdown Section
              pw.Center(
                child: pw.Text(
                  'BY CATEGORY',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 6),

              ...categorySummary.map((category) {
                final catName = category['category'] as String? ?? 'Unknown';
                final amount = (category['totalAmount'] as num?)?.toDouble() ?? 0.0;
                return pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: 3),
                  child: _buildReceiptRow(catName, amount),
                );
              }),

              if (complementaryTotal != null && complementaryTotal > 0) ...[
                pw.SizedBox(height: 3),
                _buildReceiptRow('Complementary', complementaryTotal),
              ],

              pw.SizedBox(height: 8),
              _buildDottedLine(),
              pw.SizedBox(height: 6),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Printed: ${DateFormat('dd/MM/yy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  AppConfig.copyright,
                  style: pw.TextStyle(fontSize: 7),
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Helper for dotted line separator
  static pw.Widget _buildDottedLine() {
    return pw.Row(
      children: List.generate(
        35,
        (index) => pw.Expanded(
          child: pw.Container(
            height: 1,
            margin: pw.EdgeInsets.symmetric(horizontal: 1),
            color: PdfColors.black,
          ),
        ),
      ),
    );
  }

  // Helper for receipt row with label and amount
  static pw.Widget _buildReceiptRow(String label, double amount, {bool isBold = false, double fontSize = 10}) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(label, style: style),
        ),
        pw.Text(
          _currencyFormat.format(amount),
          style: style,
        ),
      ],
    );
  }

  // Print daily summary
  static Future<void> printDailySummary({
    required DateTime date,
    required Map<String, dynamic> summaryData,
  }) async {
    final overallTotal = summaryData['overallTotal'] as Map<String, dynamic>? ?? {};
    final totalSales = (overallTotal['totalSales'] as num?)?.toDouble() ?? 0.0;
    final fullyPaidAmount = (overallTotal['fullyPaidAmount'] as num?)?.toDouble() ?? 0.0;
    final partialPaymentAmount = (overallTotal['partialPaymentAmount'] as num?)?.toDouble() ?? 0.0;
    final pendingAmount = (overallTotal['totalBalance'] as num?)?.toDouble() ?? 0.0;
    final totalTransactions = overallTotal['totalTransactions'] as int? ?? 0;
    final fullyPaidTransactions = overallTotal['fullyPaidTransactions'] as int? ?? 0;
    final partialPaymentTransactions = overallTotal['partialPaymentTransactions'] as int? ?? 0;
    final unpaidTransactions = overallTotal['unpaidTransactions'] as int? ?? 0;

    final paymentSummary = summaryData['paymentSummary'] as List<Map<String, dynamic>>? ?? [];
    final categorySummary = summaryData['categorySummary'] as List<Map<String, dynamic>>? ?? [];
    final complementaryTotal = (summaryData['complementaryTotal'] as num?)?.toDouble();

    final pdfBytes = await generateDailySummaryPdf(
      date: date,
      totalSales: totalSales,
      fullyPaidAmount: fullyPaidAmount,
      partialPaymentAmount: partialPaymentAmount,
      pendingAmount: pendingAmount,
      totalTransactions: totalTransactions,
      fullyPaidTransactions: fullyPaidTransactions,
      partialPaymentTransactions: partialPaymentTransactions,
      unpaidTransactions: unpaidTransactions,
      paymentSummary: paymentSummary,
      categorySummary: categorySummary,
      complementaryTotal: complementaryTotal,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  // Share daily summary as PDF
  static Future<void> shareDailySummary({
    required DateTime date,
    required Map<String, dynamic> summaryData,
  }) async {
    final overallTotal = summaryData['overallTotal'] as Map<String, dynamic>? ?? {};
    final totalSales = (overallTotal['totalSales'] as num?)?.toDouble() ?? 0.0;
    final fullyPaidAmount = (overallTotal['fullyPaidAmount'] as num?)?.toDouble() ?? 0.0;
    final partialPaymentAmount = (overallTotal['partialPaymentAmount'] as num?)?.toDouble() ?? 0.0;
    final pendingAmount = (overallTotal['totalBalance'] as num?)?.toDouble() ?? 0.0;
    final totalTransactions = overallTotal['totalTransactions'] as int? ?? 0;
    final fullyPaidTransactions = overallTotal['fullyPaidTransactions'] as int? ?? 0;
    final partialPaymentTransactions = overallTotal['partialPaymentTransactions'] as int? ?? 0;
    final unpaidTransactions = overallTotal['unpaidTransactions'] as int? ?? 0;

    final paymentSummary = summaryData['paymentSummary'] as List<Map<String, dynamic>>? ?? [];
    final categorySummary = summaryData['categorySummary'] as List<Map<String, dynamic>>? ?? [];
    final complementaryTotal = (summaryData['complementaryTotal'] as num?)?.toDouble();

    final pdfBytes = await generateDailySummaryPdf(
      date: date,
      totalSales: totalSales,
      fullyPaidAmount: fullyPaidAmount,
      partialPaymentAmount: partialPaymentAmount,
      pendingAmount: pendingAmount,
      totalTransactions: totalTransactions,
      fullyPaidTransactions: fullyPaidTransactions,
      partialPaymentTransactions: partialPaymentTransactions,
      unpaidTransactions: unpaidTransactions,
      paymentSummary: paymentSummary,
      categorySummary: categorySummary,
      complementaryTotal: complementaryTotal,
    );

    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'daily_summary_$dateStr.pdf',
    );
  }
}