import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/sale_transaction.dart';
import '../../shared/utils/business_day.dart';
import '../config.dart';

class PrintService {
  static final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  // Thermal receipts/reports print on 58mm roll paper. Full page width is
  // 58mm; a 5mm side margin keeps content inside the usual printable area.
  static const PdfPageFormat _roll58 =
      PdfPageFormat(58 * PdfPageFormat.mm, double.infinity);
  static const pw.EdgeInsets _roll58Margin =
      pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6);

  // Must match the options/key used by PosApiService.saveCompanyInfo so the
  // stored business name is readable here.
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const String _companyNameKey = 'company_name';
  static const String _companyLocationKey = 'company_location';
  static const String _companyPhoneKey = 'company_phone';
  static const String _fallbackCompanyName = 'Komusoft Solutions LTD';

  /// Resolves the business name printed on receipts.
  /// Prefers the real company name fetched from the API
  /// (activeBranch.company.name, persisted on login), then the flavor's
  /// configured company name, then a hard-coded fallback.
  static Future<String> resolveCompanyName() async {
    try {
      final stored = await _secureStorage.read(key: _companyNameKey);
      if (stored != null && stored.trim().isNotEmpty) {
        return stored.trim();
      }
    } catch (e) {
      // ignore secure-storage read failures and fall back below
    }
    if (AppConfig.companyName.trim().isNotEmpty) {
      return AppConfig.companyName.trim();
    }
    return _fallbackCompanyName;
  }

  /// Resolves the full receipt header: business name plus optional
  /// location (address) and phone, all persisted on login. Empty/missing
  /// values are returned as null so the receipt can omit them.
  static Future<({String name, String? location, String? phone})>
      resolveCompanyHeader() async {
    final name = await resolveCompanyName();
    String? location;
    String? phone;
    try {
      final loc = await _secureStorage.read(key: _companyLocationKey);
      if (loc != null && loc.trim().isNotEmpty) location = loc.trim();
      final ph = await _secureStorage.read(key: _companyPhoneKey);
      if (ph != null && ph.trim().isNotEmpty) phone = ph.trim();
    } catch (e) {
      // ignore secure-storage read failures; header still shows the name
    }
    return (name: name, location: location, phone: phone);
  }

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
    String? reference,
    String? notes,
    // EFRIS fiscal fields. When any are provided, a fiscal block (QR code,
    // fiscal document number, verification code) is appended below the
    // receipt. All null (the default) = a plain, non-fiscal receipt.
    String? efrisCode,
    String? verificationCode,
    String? efrisInvoiceId,
    String? qrCode,
    String? taxAmount,
    String? taxRate,
  }) async {
    final bool hasFiscal = (efrisCode != null && efrisCode.isNotEmpty) ||
        (qrCode != null && qrCode.isNotEmpty) ||
        (verificationCode != null && verificationCode.isNotEmpty);
    final pdf = pw.Document();
    final header = await resolveCompanyHeader();

    // Derive change/owing from amountPaid vs totalAmount rather than the passed
    // `balance` value, whose sign differs between callers (settle-bill vs
    // payment screen). Tolerance covers floating-point rounding.
    final bool isFullyPaid = amountPaid + 0.005 >= totalAmount;
    final double changeDue = amountPaid - totalAmount; // >= 0 when fully paid
    final double amountOwing = totalAmount - amountPaid; // > 0 when not fully paid

    pdf.addPage(
      pw.Page(
        pageFormat: _roll58,
        margin: _roll58Margin,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Company Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      header.name,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (header.location != null) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        header.location!,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 11),
                      ),
                    ],
                    if (header.phone != null) ...[
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Tel: ${header.phone!}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 11),
                      ),
                    ],
                    pw.SizedBox(height: 6),
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
              if (hasFiscal) ...[
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
              ] else ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Reference:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(reference ?? '-', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
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
                pw.SizedBox(height: 2),
                // Show Change when fully paid (any overpayment), otherwise the
                // outstanding Balance still owed.
                if (isFullyPaid)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Change:',
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text('UGX ${_currencyFormat.format(changeDue)}',
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  )
                else
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Balance:', style: pw.TextStyle(fontSize: 12)),
                      pw.Text('UGX ${_currencyFormat.format(amountOwing)}',
                          style: pw.TextStyle(fontSize: 12)),
                    ],
                  ),

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

              // EFRIS fiscal block - appears below the receipt body: the QR
              // code, fiscal document number and verification code.
              if (hasFiscal) ...[
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1),
                pw.Center(
                  child: pw.Text(
                    'FISCAL DOCUMENT',
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 4),
                if (taxRate != null && taxRate.isNotEmpty ||
                    taxAmount != null && taxAmount.isNotEmpty)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Tax${_formatTaxRate(taxRate)}:',
                        style: pw.TextStyle(fontSize: 11),
                      ),
                      pw.Text(
                        'UGX ${_currencyFormat.format(double.tryParse(taxAmount ?? '') ?? 0)}',
                        style: pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                if (efrisCode != null && efrisCode.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Fiscal Doc No:',
                          style: pw.TextStyle(fontSize: 11)),
                      pw.Text(efrisCode,
                          style: pw.TextStyle(
                              fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
                if (verificationCode != null &&
                    verificationCode.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Verification No:',
                          style: pw.TextStyle(fontSize: 11)),
                      pw.Text(verificationCode,
                          style: pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
                if (efrisInvoiceId != null && efrisInvoiceId.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Invoice ID:', style: pw.TextStyle(fontSize: 11)),
                      pw.Text(efrisInvoiceId,
                          style: pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
                if (qrCode != null && qrCode.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrCode,
                      width: 90,
                      height: 90,
                      drawText: false,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Text(
                      'Scan to verify on URA EFRIS',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ),
                ],
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

  /// Formats an EFRIS tax rate (e.g. "0.18") as a "(18%)" suffix, or "" when
  /// absent/unparseable.
  static String _formatTaxRate(String? taxRate) {
    final rate = double.tryParse(taxRate ?? '');
    if (rate == null || rate == 0) return '';
    final pct = rate <= 1 ? rate * 100 : rate;
    return ' (${pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1)}%)';
  }

  // Generate bill PDF
  static Future<Uint8List> generateBillPdf({
    required String receiptNumber,
    required DateTime date,
    required List<SaleTransaction> items,
    required double totalAmount,
    String? reference,
    String? notes,
  }) async {
    final pdf = pw.Document();
    final companyName = await resolveCompanyName();

    pdf.addPage(
      pw.Page(
        pageFormat: _roll58,
        margin: _roll58Margin,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Company Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      companyName,
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
                  pw.Text('Reference:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(reference ?? '-', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
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
    required DateTime date,
    required List<SaleTransaction> items,
    required double totalAmount,
    String? reference,
    String? notes,
  }) async {
    final pdfBytes = await generateBillPdf(
      receiptNumber: receiptNumber,
      date: date,
      items: items,
      totalAmount: totalAmount,
      reference: reference,
      notes: notes,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  // Generate KOT (Kitchen Order Ticket) PDF
  static Future<Uint8List> generateKotPdf({
    required String receiptNumber,
    required DateTime date,
    required List<SaleTransaction> items,
    String? issuedBy,
    String? notes,
    String? tableNumber,
  }) async {
    final pdf = pw.Document();
    final companyName = await resolveCompanyName();

    pdf.addPage(
      pw.Page(
        pageFormat: _roll58,
        margin: _roll58Margin,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      companyName,
                      style: pw.TextStyle(

                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '*** KITCHEN ORDER ***',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),

              // Order Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Order No:', style: pw.TextStyle(fontSize: 12)),
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
              if (tableNumber != null && tableNumber.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Table:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(tableNumber, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Waiter:', style: pw.TextStyle(fontSize: 12)),
                  pw.Text(issuedBy ?? 'Staff', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1),

              // Items Header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text('Qty',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text('Item',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items List - Kitchen items only (filter by category if needed)
              ...items.map((item) => pw.Column(
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text(
                              item.quantity.toStringAsFixed(0),
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Expanded(
                            flex: 4,
                            child: pw.Text(
                              item.inventoryname,
                              style: pw.TextStyle(fontSize: 12),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                    ],
                  )),

              pw.Divider(thickness: 1),

              if (notes != null && notes.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text('Notes:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text(notes, style: pw.TextStyle(fontSize: 10)),
                pw.Divider(thickness: 0.5),
              ],

              // Footer
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Printed: ${_dateFormat.format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 9),
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

  // Print KOT
  static Future<void> printKot({
    required String receiptNumber,
    required DateTime date,
    required List<SaleTransaction> items,
    String? issuedBy,
    String? notes,
    String? tableNumber,
  }) async {
    final pdfBytes = await generateKotPdf(
      receiptNumber: receiptNumber,
      date: date,
      items: items,
      issuedBy: issuedBy,
      notes: notes,
      tableNumber: tableNumber,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  // Generate BOT (Bar Order Ticket) PDF
  static Future<Uint8List> generateBotPdf({
    required String receiptNumber,
    required DateTime date,
    required List<SaleTransaction> items,
    String? issuedBy,
    String? notes,
    String? tableNumber,
  }) async {
    final pdf = pw.Document();
    final companyName = await resolveCompanyName();

    pdf.addPage(
      pw.Page(
        pageFormat: _roll58,
        margin: _roll58Margin,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      companyName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '*** BAR ORDER ***',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),

              // Order Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Order No:', style: pw.TextStyle(fontSize: 12)),
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
              if (tableNumber != null && tableNumber.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Table:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(tableNumber, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Waiter:', style: pw.TextStyle(fontSize: 12)),
                  pw.Text(issuedBy ?? 'Staff', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1),

              // Items Header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text('Qty',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text('Item',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items List - Bar items only (filter by category if needed)
              ...items.map((item) => pw.Column(
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text(
                              item.quantity.toStringAsFixed(0),
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Expanded(
                            flex: 4,
                            child: pw.Text(
                              item.inventoryname,
                              style: pw.TextStyle(fontSize: 12),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                    ],
                  )),

              pw.Divider(thickness: 1),

              if (notes != null && notes.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text('Notes:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text(notes, style: pw.TextStyle(fontSize: 10)),
                pw.Divider(thickness: 0.5),
              ],

              // Footer
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Printed: ${_dateFormat.format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 9),
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

  // Print BOT
  static Future<void> printBot({
    required String receiptNumber,
    required DateTime date,
    required List<SaleTransaction> items,
    String? issuedBy,
    String? notes,
    String? tableNumber,
  }) async {
    final pdfBytes = await generateBotPdf(
      receiptNumber: receiptNumber,
      date: date,
      items: items,
      issuedBy: issuedBy,
      notes: notes,
      tableNumber: tableNumber,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  // Share bill as PDF
  static Future<void> shareBill({
    required String receiptNumber,
    required DateTime date,
    required List<SaleTransaction> items,
    required double totalAmount,
    String? reference,
    String? notes,
  }) async {
    final pdfBytes = await generateBillPdf(
      receiptNumber: receiptNumber,
      date: date,
      items: items,
      totalAmount: totalAmount,
      reference: reference,
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
    String? reference,
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
      reference: reference,
      notes: notes,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  /// Print an EFRIS fiscal receipt: the normal receipt plus a fiscal block
  /// (QR code, fiscal document number, verification code) below it. The
  /// fiscal fields come from the cached fiscal_documents snapshot taken at
  /// fiscalise time, so this works offline.
  static Future<void> printFiscalReceipt({
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
    String? efrisCode,
    String? verificationCode,
    String? efrisInvoiceId,
    String? qrCode,
    String? taxAmount,
    String? taxRate,
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
      efrisCode: efrisCode,
      verificationCode: verificationCode,
      efrisInvoiceId: efrisInvoiceId,
      qrCode: qrCode,
      taxAmount: taxAmount,
      taxRate: taxRate,
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
    String? reference,
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
      reference: reference,
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
    List<Map<String, dynamic>> itemsSummary = const [],
    List<Map<String, dynamic>> settledItems = const [],
    List<Map<String, dynamic>> complementaryItems = const [],
    List<Map<String, dynamic>> nonSettledItems = const [],
    double? complementaryTotal,
    num complementaryQuantity = 0,
    String? printedBy,
  }) async {
    final pdf = pw.Document();
    final companyHeader = await resolveCompanyHeader();
    final phone = companyHeader.phone ?? AppConfig.phone;
    final reportDate = BusinessDay.shortRangeLabel(date);
    final printedByName = (printedBy ?? '').trim().isEmpty
        ? 'Account'
        : printedBy!.trim();
    final paymentTotals = _aggregatePaymentSummary(paymentSummary);
    final categoryTotals = _aggregateCategorySummary(categorySummary);
    final settledGroups = _groupSettledItems(settledItems);
    final complementaryGroups = _groupComplementaryItems(complementaryItems);
    final nonSettledTotals = _aggregateNonSettledItems(nonSettledItems);

    pdf.addPage(
      pw.Page(
        pageFormat: _roll58,
        margin: _roll58Margin,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  companyHeader.name,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'Phone: $phone',
                  style: pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'DAILY SUMMARY',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              _buildTextRow('Date', reportDate, fontSize: 12),
              _buildTextRow('Printed by', printedByName, fontSize: 12),
              pw.SizedBox(height: 6),
              _buildDottedLine(),
              _buildSectionHeading('SUMMARY'),
              _buildReceiptRow('Total Sales', totalSales, isBold: true, fontSize: 13),
              _buildReceiptRow('Total Cash', paymentTotals['Cash'] ?? 0.0),
              _buildReceiptRow('Total Card', paymentTotals['Card'] ?? 0.0),
              _buildReceiptRow('Total M/Money', paymentTotals['M/Money'] ?? 0.0),
              _buildReceiptRow('Total Credit', paymentTotals['Credit'] ?? 0.0),
              _buildReceiptRow(
                'Total Pending',
                pendingAmount < 0 ? 0.0 : pendingAmount,
                isBold: true,
              ),
              ..._orderedExtraPaymentRows(paymentTotals),
              ..._orderedCategoryRows(categoryTotals),
              _buildTextRow(
                'Complementary Item Quantity',
                _formatQuantity(complementaryQuantity),
                fontSize: 12,
              ),
              if (complementaryTotal != null && complementaryTotal > 0)
                _buildReceiptRow('Complementary Total', complementaryTotal),
              pw.SizedBox(height: 6),
              _buildDottedLine(),
              _buildSectionHeading('Items Summary'),
              if (itemsSummary.isEmpty)
                _buildEmptyText('No items')
              else
                ...itemsSummary.map(
                  (item) => _buildReceiptRow(
                    '${_mapText(item, const ['item', 'inventoryname'], 'Unknown')} '
                    '(${_formatQuantity(_mapValue(item, const ['quantity', 'qty']))})',
                    _toDouble(_mapValue(item, const ['amount', 'totalAmount'])),
                  ),
                ),
              _buildReceiptRow('Total', totalSales, isBold: true),
              pw.SizedBox(height: 6),
              _buildDottedLine(),
              _buildSectionHeading('Complementary Items'),
              if (complementaryGroups.isEmpty)
                _buildEmptyText('No complementary items')
              else
                ...complementaryGroups.entries.map(
                  (entry) => _buildTextRow(
                    entry.key,
                    _formatQuantity(entry.value),
                    fontSize: 12,
                  ),
                ),
              pw.SizedBox(height: 6),
              _buildDottedLine(),
              _buildSectionHeading('Settled Items'),
              if (settledGroups.isEmpty)
                _buildEmptyText('No settled items')
              else
                ..._buildSettledRows(settledGroups),
              pw.SizedBox(height: 6),
              _buildDottedLine(),
              _buildSectionHeading('Non-Settled Items'),
              if (nonSettledTotals.isEmpty)
                _buildEmptyText('No non-settled items')
              else
                ..._orderedNonSettledRows(nonSettledTotals),
              pw.SizedBox(height: 8),
              _buildDottedLine(),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'Printed: ${DateFormat('dd/MM/yy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 7),
                ),
              ),
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

  static pw.Widget _buildSectionHeading(String title) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(top: 3, bottom: 3),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildSubheading(String title) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(top: 3, bottom: 1),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildTextRow(
    String label,
    String value, {
    double fontSize = 12,
    bool isBold = false,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(child: pw.Text(label, style: style)),
        pw.SizedBox(width: 4),
        pw.Text(value, style: style, textAlign: pw.TextAlign.right),
      ],
    );
  }

  static pw.Widget _buildEmptyText(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  static pw.Widget _buildReceiptRow(
    String label,
    double amount, {
    bool isBold = false,
    double fontSize = 12,
  }) {
    return _buildTextRow(
      label,
      _currencyFormat.format(amount),
      fontSize: fontSize,
      isBold: isBold,
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0.0;
    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0.0;
  }

  static int _toInt(Object? value) => _toDouble(value).round();

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  static List<Map<String, dynamic>> _asMapList(Object? value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map(_asMap).toList();
  }

  static String _formatQuantity(Object? value) {
    final quantity = _toDouble(value);
    if (quantity == quantity.roundToDouble()) return quantity.toInt().toString();
    return quantity.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static Object? _mapValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) return value;
    }
    return null;
  }

  static String _mapText(
    Map<String, dynamic> map,
    List<String> keys, [
    String fallback = 'Unknown',
  ]) {
    final value = _mapValue(map, keys)?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  static String _canonicalPaymentType(Object? value) {
    final text = value?.toString().trim() ?? '';
    final normalized = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normalized == 'pending') return 'Pending';
    if (normalized.contains('cash')) return 'Cash';
    if (normalized.contains('card')) return 'Card';
    if (normalized.contains('mobilemoney') ||
        normalized.contains('mmoney') ||
        normalized.contains('momo') ||
        normalized.contains('mpesa') ||
        normalized == 'mm') {
      return 'M/Money';
    }
    if (normalized.contains('credit')) return 'Credit';
    if (text.isEmpty) return 'Other';
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  static Map<String, double> _aggregatePaymentSummary(
    List<Map<String, dynamic>> paymentSummary,
  ) {
    final totals = <String, double>{};
    for (final payment in paymentSummary) {
      final type = _canonicalPaymentType(
        _mapValue(payment, const ['paymenttype', 'paymentType']),
      );
      if (type == 'Pending') continue;
      final amount = _toDouble(
        _mapValue(payment, const ['totalPaid', 'amountPaid', 'amount']),
      );
      totals.update(type, (value) => value + amount, ifAbsent: () => amount);
    }
    return totals;
  }

  static Map<String, double> _aggregateCategorySummary(
    List<Map<String, dynamic>> categorySummary,
  ) {
    final totals = <String, double>{};
    for (final category in categorySummary) {
      final name = _mapText(category, const ['category'], 'Unknown');
      final amount = _toDouble(
        _mapValue(category, const ['totalAmount', 'amount']),
      );
      totals.update(name, (value) => value + amount, ifAbsent: () => amount);
    }
    return totals;
  }

  static Map<String, Map<String, Map<String, double>>>
      _groupSettledItems(List<Map<String, dynamic>> settledItems) {
    final groups = <String, Map<String, Map<String, double>>>{};
    for (final item in settledItems) {
      final payment = _canonicalPaymentType(
        _mapValue(item, const ['paymenttype', 'paymentType']),
      );
      if (payment == 'Pending') continue;
      final itemName = _mapText(item, const ['item', 'inventoryname']);
      final paymentItems = groups.putIfAbsent(payment, () => {});
      final values = paymentItems.putIfAbsent(
        itemName,
        () => {'quantity': 0.0, 'amount': 0.0},
      );
      values['quantity'] = values['quantity']! + _toDouble(
            _mapValue(item, const ['quantity', 'qty']),
          );
      values['amount'] = values['amount']! + _toDouble(
            _mapValue(item, const ['amount', 'totalAmount']),
          );
    }
    return groups;
  }

  static Map<String, double> _groupComplementaryItems(
    List<Map<String, dynamic>> complementaryItems,
  ) {
    final groups = <String, double>{};
    for (final item in complementaryItems) {
      final name = _mapText(item, const ['item', 'inventoryname'], 'Unknown');
      final quantity = _toDouble(
        _mapValue(item, const ['quantity', 'qty']),
      );
      groups.update(
        name,
        (value) => value + quantity,
        ifAbsent: () => quantity,
      );
    }
    return groups;
  }

  static Map<String, Map<String, double>> _aggregateNonSettledItems(
    List<Map<String, dynamic>> nonSettledItems,
  ) {
    final totals = <String, Map<String, double>>{};
    for (final item in nonSettledItems) {
      final itemName = _mapText(item, const ['item', 'inventoryname']);
      final values = totals.putIfAbsent(
        itemName,
        () => {'quantity': 0.0, 'balance': 0.0},
      );
      values['quantity'] = values['quantity']! + _toDouble(
            _mapValue(item, const ['quantity', 'qty']),
          );
      values['balance'] = values['balance']! + _toDouble(
            _mapValue(item, const ['balance', 'totalBalance', 'amount']),
          );
    }
    return totals;
  }

  static List<pw.Widget> _orderedExtraPaymentRows(
    Map<String, double> paymentTotals,
  ) {
    const fixed = {'Cash', 'Card', 'M/Money', 'Credit'};
    final labels = paymentTotals.keys
        .where((label) => !fixed.contains(label))
        .toList()
      ..sort();
    return labels
        .map((label) => _buildReceiptRow('Total $label', paymentTotals[label]!))
        .toList();
  }

  static List<pw.Widget> _orderedCategoryRows(
    Map<String, double> categoryTotals,
  ) {
    return categoryTotals.entries
        .map((entry) => _buildReceiptRow('Total ${entry.key}', entry.value))
        .toList();
  }

  static List<pw.Widget> _buildSettledRows(
    Map<String, Map<String, Map<String, double>>> settledGroups,
  ) {
    const fixedOrder = ['Cash', 'Card', 'M/Money', 'Credit'];
    final payments = settledGroups.keys.toList()
      ..sort((left, right) {
        final leftIndex = fixedOrder.indexOf(left);
        final rightIndex = fixedOrder.indexOf(right);
        if (leftIndex == -1 && rightIndex == -1) return left.compareTo(right);
        if (leftIndex == -1) return 1;
        if (rightIndex == -1) return -1;
        return leftIndex.compareTo(rightIndex);
      });
    final rows = <pw.Widget>[];
    for (final payment in payments) {
      rows.add(_buildSubheading('BY ${payment.toUpperCase()}'));
      final items = settledGroups[payment]!.keys.toList()..sort();
      for (final item in items) {
        final values = settledGroups[payment]![item]!;
        rows.add(
          _buildReceiptRow(
            '$item (${_formatQuantity(values['quantity'])})',
            values['amount']!,
          ),
        );
      }
    }
    return rows;
  }

  static List<pw.Widget> _orderedNonSettledRows(
    Map<String, Map<String, double>> nonSettledTotals,
  ) {
    final items = nonSettledTotals.keys.toList()..sort();
    return items
        .map(
          (item) => _buildReceiptRow(
            '$item (${_formatQuantity(nonSettledTotals[item]!['quantity'])})',
            nonSettledTotals[item]!['balance']!,
          ),
        )
        .toList();
  }

  // Print daily summary
  static Future<void> printDailySummary({
    required DateTime date,
    required Map<String, dynamic> summaryData,
    String? printedBy,
  }) async {
    final overallTotal = _asMap(summaryData['overallTotal']);
    final totalSales = _toDouble(overallTotal['totalSales']);
    final fullyPaidAmount = _toDouble(overallTotal['fullyPaidAmount']);
    final partialPaymentAmount = _toDouble(overallTotal['partialPaymentAmount']);
    final pendingAmount = _toDouble(overallTotal['totalBalance']);
    final totalTransactions = _toInt(overallTotal['totalTransactions']);
    final fullyPaidTransactions = _toInt(overallTotal['fullyPaidTransactions']);
    final partialPaymentTransactions =
        _toInt(overallTotal['partialPaymentTransactions']);
    final unpaidTransactions = _toInt(overallTotal['unpaidTransactions']);

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
      paymentSummary: _asMapList(summaryData['paymentSummary']),
      categorySummary: _asMapList(summaryData['categorySummary']),
      itemsSummary: _asMapList(summaryData['itemsSummary']),
      settledItems: _asMapList(summaryData['settledItems']),
      complementaryItems: _asMapList(summaryData['complementaryItems']),
      nonSettledItems: _asMapList(summaryData['nonSettledItems']),
      complementaryTotal: _toDouble(summaryData['complementaryTotal']),
      complementaryQuantity: _toDouble(summaryData['complementaryQuantity']),
      printedBy: printedBy,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  // Share daily summary as PDF
  static Future<void> shareDailySummary({
    required DateTime date,
    required Map<String, dynamic> summaryData,
    String? printedBy,
  }) async {
    final overallTotal = _asMap(summaryData['overallTotal']);
    final totalSales = _toDouble(overallTotal['totalSales']);
    final fullyPaidAmount = _toDouble(overallTotal['fullyPaidAmount']);
    final partialPaymentAmount = _toDouble(overallTotal['partialPaymentAmount']);
    final pendingAmount = _toDouble(overallTotal['totalBalance']);
    final totalTransactions = _toInt(overallTotal['totalTransactions']);
    final fullyPaidTransactions = _toInt(overallTotal['fullyPaidTransactions']);
    final partialPaymentTransactions =
        _toInt(overallTotal['partialPaymentTransactions']);
    final unpaidTransactions = _toInt(overallTotal['unpaidTransactions']);

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
      paymentSummary: _asMapList(summaryData['paymentSummary']),
      categorySummary: _asMapList(summaryData['categorySummary']),
      itemsSummary: _asMapList(summaryData['itemsSummary']),
      settledItems: _asMapList(summaryData['settledItems']),
      complementaryItems: _asMapList(summaryData['complementaryItems']),
      nonSettledItems: _asMapList(summaryData['nonSettledItems']),
      complementaryTotal: _toDouble(summaryData['complementaryTotal']),
      complementaryQuantity: _toDouble(summaryData['complementaryQuantity']),
      printedBy: printedBy,
    );

    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'daily_summary_$dateStr.pdf',
    );
  }
}