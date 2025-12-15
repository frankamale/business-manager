import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../back_pos/models/sale_transaction.dart';
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

  // Generate daily summary PDF
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
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (context) {
          return [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    AppConfig.companyName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    AppConfig.appName,
                    style: pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'DAILY SALES SUMMARY',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _dateFormat.format(date),
                    style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 16),

            // Key Metrics Section
            pw.Text(
              'SALES OVERVIEW',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Metric',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Transactions',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Amount (UGX)',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('Total Sales'),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        totalTransactions.toString(),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        _currencyFormat.format(totalSales),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.green50),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('Fully Paid'),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        fullyPaidTransactions.toString(),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        _currencyFormat.format(fullyPaidAmount),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.orange50),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('Partial Payments'),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        partialPaymentTransactions.toString(),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        _currencyFormat.format(partialPaymentAmount),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.red50),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('Pending Amount'),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        unpaidTransactions.toString(),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        _currencyFormat.format(pendingAmount),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Payment Methods Breakdown
            pw.Text(
              'PAYMENT METHODS',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Payment Method',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Amount (UGX)',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                ...paymentSummary.map((payment) {
                  final type = payment['paymenttype'] as String? ?? 'Unknown';
                  final amount = (payment['totalPaid'] as num?)?.toDouble() ?? 0.0;
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(type),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          _currencyFormat.format(amount),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 24),

            // Category Breakdown
            pw.Text(
              'CATEGORY BREAKDOWN',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Category',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Amount (UGX)',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                ...categorySummary.map((category) {
                  final catName = category['category'] as String? ?? 'Unknown';
                  final amount = (category['totalAmount'] as num?)?.toDouble() ?? 0.0;
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(catName),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          _currencyFormat.format(amount),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }).toList(),
                if (complementaryTotal != null && complementaryTotal > 0)
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.teal50),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text('Complementary Items'),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          _currencyFormat.format(complementaryTotal),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 32),

            // Footer
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 16, color: PdfColors.grey600),
              ),
            ),
            pw.Center(
              child: pw.Text(
                AppConfig.copyright,
                style: pw.TextStyle(fontSize: 15, color: PdfColors.grey600),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
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