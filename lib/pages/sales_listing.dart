import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../controllers/sales_controller.dart';

class SalesListing extends StatelessWidget {
  const SalesListing({super.key});

  @override
  Widget build(BuildContext context) {
    final SalesController salesController = Get.find<SalesController>();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text("Sales Orders / Bills"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => salesController.loadSalesTransactions(),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {
              // Add filter functionality
            },
            tooltip: 'Filter',
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              // Add search functionality
            },
            tooltip: 'Search',
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (salesController.isLoadingSales.value) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          if (salesController.groupedSales.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No sales found",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Sales data synced on startup",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: salesController.groupedSales.length,
            itemBuilder: (context, index) {
              return _buildSaleCard(salesController.groupedSales[index]);
            },
          );
        }),
      ),
    );
  }

  Widget _buildSaleCard(Map<String, dynamic> sale) {
    final dateTimeFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final currencyFormat = NumberFormat('#,###', 'en_US');

    final receiptNumber = sale['receiptnumber'] as String? ?? '';
    final numberOfItems = sale['numberOfItems'] as int? ?? 0;
    final totalAmount = sale['totalAmount'] as double? ?? 0.0;
    final totalPaid = sale['totalPaid'] as double? ?? 0.0;
    final totalBalance = sale['totalBalance'] as double? ?? 0.0;
    final transactionDate = sale['transactiondate'] as int? ?? 0;
    final reference = sale['reference'] as String? ?? '';
    final notes = sale['notes'] as String? ?? '';
    final paymentType = sale['paymenttype'] as String? ?? 'Unknown';
    final cancelled = sale['cancelled'] as int? ?? 0;

    final date = DateTime.fromMillisecondsSinceEpoch(transactionDate);

    return Card(
      margin: EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row - Receipt Number and Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  receiptNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cancelled > 0 ? Colors.red.shade700 : Colors.blue.shade700,
                  ),
                ),
                Text(
                  '($numberOfItems items)',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => _handlePrint(sale),
                      icon: Icon(Icons.print),
                      color: Colors.blue.shade600,
                      tooltip: 'Print',
                    ),
                    IconButton(
                      onPressed: () => _handleEdit(sale),
                      icon: Icon(Icons.edit_note_outlined),
                      color: Colors.green.shade600,
                      tooltip: 'Edit',
                      padding: EdgeInsets.all(8),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        _handleAction(value, sale);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'upload',
                          child: Row(
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Upload',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'fiscalise',
                          child: Row(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Fiscalise',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'synchronise',
                          child: Row(
                            children: [
                              Icon(Icons.sync, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Synchronise',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                      icon: Icon(Icons.more_vert),
                      color: Colors.blue.shade600,
                      tooltip: 'Actions',
                      padding: EdgeInsets.all(8),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),

            // Date and Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total: UGX ${currencyFormat.format(totalAmount)}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (totalBalance > 0) ...[
                      SizedBox(height: 2),
                      Text(
                        "Balance: UGX ${currencyFormat.format(totalBalance)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  dateTimeFormat.format(date),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            SizedBox(height: 6),

            // Payment Type
            Row(
              children: [
                Icon(
                  Icons.payment,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                SizedBox(width: 4),
                Text(
                  "Payment: $paymentType",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
            SizedBox(height: 4),

            // Reference
            Row(
              children: [
                Icon(
                  Icons.tag,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                SizedBox(width: 4),
                Text(
                  "Reference: ",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                Text(
                  reference,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),

            // Status indicators
            if (cancelled > 0) ...[
              SizedBox(height: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "CANCELLED",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],

            // Notes if present
            if (notes.isNotEmpty) ...[
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.note,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      notes,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handlePrint(Map<String, dynamic> sale) {
    final receiptNumber = sale['receiptnumber'] as String? ?? '';
    Get.snackbar(
      'Print',
      'Printing receipt $receiptNumber...',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blue.shade700,
      colorText: Colors.white,
    );
  }

  void _handleAction(String action, Map<String, dynamic> sale) {
    final receiptNumber = sale['receiptnumber'] as String? ?? '';
    String message = '';
    switch (action) {
      case 'upload':
        message = 'Uploading $receiptNumber to server...';
        break;
      case 'fiscalise':
        message = 'Fiscalising $receiptNumber...';
        break;
      case 'synchronise':
        message = 'Synchronising $receiptNumber...';
        break;
    }

    Get.snackbar(
      action.toUpperCase(),
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange.shade700,
      colorText: Colors.white,
    );
  }

  void _handleEdit(Map<String, dynamic> sale) {
    final receiptNumber = sale['receiptnumber'] as String? ?? '';
    Get.snackbar(
      'Edit',
      'Editing $receiptNumber...',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade700,
      colorText: Colors.white,
    );
  }
}
