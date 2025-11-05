import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalesListing extends StatefulWidget {
  const SalesListing({super.key});

  @override
  State<SalesListing> createState() => _SalesListingState();
}

class _SalesListingState extends State<SalesListing> {
  // Sample data - replace with actual data from database/API
  final List<Sale> sales = [
    Sale(
      receiptNumber: 'RCP-001',
      numberOfItems: 5,
      totalAmount: 450000,
      date: DateTime.now(),
      reference: 'REF-2024-001',
      notes: 'Customer paid by card',
    ),
    Sale(
      receiptNumber: 'RCP-002',
      numberOfItems: 3,
      totalAmount: 275000,
      date: DateTime.now().subtract(Duration(hours: 2)),
      reference: 'REF-2024-002',
      notes: 'Cash payment',
    ),
    Sale(
      receiptNumber: 'RCP-003',
      numberOfItems: 8,
      totalAmount: 780000,
      date: DateTime.now().subtract(Duration(hours: 5)),
      reference: 'REF-2024-003',
      notes: 'Corporate order',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text("Sales Orders / Bills"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
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
        child: sales.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "No sales found",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: sales.length,
                itemBuilder: (context, index) {
                  return _buildSaleCard(sales[index]);
                },
              ),
      ),
    );
  }

  Widget _buildSaleCard(Sale sale) {
    final dateTimeFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final currencyFormat = NumberFormat('#,###', 'en_US');

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
                  sale.receiptNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                // Icon(
                //   Icons.shopping_cart,
                //   size: 14,
                //   color: Colors.grey.shade600,
                // ),
                Text(
                  '(${sale.numberOfItems} items)',
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
                Text("Total: " + sale.totalAmount.toString()),

                Text(
                  dateTimeFormat.format(sale.date),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            SizedBox(height: 6),

            // Items and Reference
            Row(
              children: [
                SizedBox(width: 4),
                Text(
                  "Upload Status:  Pending",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                Text(
                  "Efris Status:  Pending",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(width: 4),
                Text(
                  "Reference: ",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                Text(
                  sale.reference,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),

            // Notes if present
            if (sale.notes.isNotEmpty) ...[
              SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    "Notes: ",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sale.notes,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handlePrint(Sale sale) {
    // Implement print functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Printing receipt ${sale.receiptNumber}...'),
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }

  void _handleAction(String action, Sale sale) {
    String message = '';
    switch (action) {
      case 'upload':
        message = 'Uploading ${sale.receiptNumber} to server...';
        break;
      case 'fiscalise':
        message = 'Fiscalising ${sale.receiptNumber}...';
        break;
      case 'synchronise':
        message = 'Synchronising ${sale.receiptNumber}...';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange.shade700),
    );
  }

  void _handleEdit(Sale sale) {
    // Implement edit functionality - navigate to edit screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing ${sale.receiptNumber}...'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }
}

// Sale Model
class Sale {
  final String receiptNumber;
  final int numberOfItems;
  final double totalAmount;
  final DateTime date;
  final String reference;
  final String notes;

  Sale({
    required this.receiptNumber,
    required this.numberOfItems,
    required this.totalAmount,
    required this.date,
    required this.reference,
    this.notes = '',
  });
}
