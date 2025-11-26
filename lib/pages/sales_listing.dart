import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../controllers/sales_controller.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/customer_controller.dart';
import '../controllers/auth_controller.dart';
import 'pos_screen.dart';

class SalesListing extends StatefulWidget {
  const SalesListing({super.key});

  @override
  State<SalesListing> createState() => _SalesListingState();
}

class _SalesListingState extends State<SalesListing> {
  final SalesController salesController = Get.find<SalesController>();
  final TextEditingController searchController = TextEditingController();
  final RxList<Map<String, dynamic>> filteredSales = <Map<String, dynamic>>[].obs;
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    filteredSales.assignAll(salesController.groupedSales);
    searchController.addListener(_filterSales);

    // Update filtered sales when grouped sales change
    ever(salesController.groupedSales, (_) => _filterSales());
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterSales() {
    final query = searchController.text.toLowerCase();
    if (query.isEmpty) {
      filteredSales.assignAll(salesController.groupedSales);
    } else {
      filteredSales.assignAll(
        salesController.groupedSales.where((sale) {
          final receipt = (sale['receiptnumber'] as String? ?? '').toLowerCase();
          final reference = (sale['reference'] as String? ?? '').toLowerCase();
          final paymentType = (sale['paymenttype'] as String? ?? '').toLowerCase();
          final notes = (sale['notes'] as String? ?? '').toLowerCase();
          return receipt.contains(query) ||
                 reference.contains(query) ||
                 paymentType.contains(query) ||
                 notes.contains(query);
        }).toList(),
      );
    }
  }

  void _startSearch() {
    setState(() {
      isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      isSearching = false;
      searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: isSearching
            ? TextField(
                controller: searchController,
                autofocus: true,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by receipt, reference, payment...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              )
            : Text("Sales Orders / Bills"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!isSearching) ...[
            Obx(() => IconButton(
              icon: salesController.isSyncingSales.value
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.sync),
              onPressed: salesController.isSyncingSales.value
                  ? null
                  : () => salesController.refreshSales(),
              tooltip: 'Refresh Sales',
            )),
            IconButton(
              icon: Icon(Icons.search),
              onPressed: _startSearch,
              tooltip: 'Search',
            ),
          ] else ...[
            IconButton(
              icon: Icon(Icons.close),
              onPressed: _stopSearch,
              tooltip: 'Close Search',
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (salesController.isLoadingSales.value) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          if (filteredSales.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSearching && searchController.text.isNotEmpty
                        ? Icons.search_off
                        : Icons.receipt_long,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    isSearching && searchController.text.isNotEmpty
                        ? "No sales match your search"
                        : "No sales found",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    isSearching && searchController.text.isNotEmpty
                        ? "Try a different search term"
                        : "Sales data synced on startup",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => salesController.refreshSales(),
            child: ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: filteredSales.length,
              itemBuilder: (context, index) {
                return _buildSaleCard(filteredSales[index]);
              },
            ),
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

  Future<void> _handleEdit(Map<String, dynamic> sale) async {
    final salesController = Get.find<SalesController>();
    final inventoryController = Get.find<InventoryController>();
    final customerController = Get.find<CustomerController>();

    final receiptNumber = sale['receiptnumber'] as String? ?? '';
    final salesId = sale['salesId'] as String?;

    if (salesId == null) {
      Get.snackbar(
        'Error',
        'Cannot edit sale: Invalid sale ID',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    try {
      // Show loading indicator
      Get.dialog(
        Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading sale details...'),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Fetch all items for this sale from database
      final saleTransactions = await salesController.getSaleTransactionsBySalesId(salesId);

      // Close loading dialog
      Get.back();

      if (saleTransactions.isEmpty) {
        Get.snackbar(
          'Error',
          'No items found for this sale',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }

      // Get customer from first transaction (all have same customer)
      final firstTransaction = saleTransactions.first;
      final customerName = firstTransaction.destinationbp;
      print('🔍 Looking up customer: $customerName');

      // Try exact match first, then try with/without trailing space
      var customer = customerController.getCustomerByFullnames(customerName);
      if (customer == null) {
        customer = customerController.getCustomerByFullnames(customerName.trim());
      }
      if (customer == null && !customerName.endsWith(' ')) {
        customer = customerController.getCustomerByFullnames('$customerName ');
      }

      final customerId = customer?.id;
      print('✅ Customer ID found: $customerId');

      // Get salesperson from first transaction
      final salespersonName = firstTransaction.issuedby.trim();
      print('🔍 Looking for salesperson: "$salespersonName"');

      // Try to find salesperson by username or name
      final authController = Get.find<AuthController>();
      final salespeople = await authController.getSalespeople();

      String? salespersonId;
      if (salespersonName.isNotEmpty && salespersonName != '  ') {
        final salesperson = salespeople.firstWhereOrNull(
          (user) => user.username.toLowerCase() == salespersonName.toLowerCase() ||
                    user.name.toLowerCase() == salespersonName.toLowerCase(),
        );
        salespersonId = salesperson?.salespersonid;
        print('✅ Salesperson ID found: $salespersonId');
      }

      // Transform sale transactions to cart items format
      final cartItems = <Map<String, dynamic>>[];
      for (var transaction in saleTransactions) {
        // Try to find the inventory item by name (search inventory)
        final inventoryItems = inventoryController.inventoryItems;
        final inventoryItem = inventoryItems.firstWhereOrNull(
          (item) => item.name.toLowerCase() == transaction.inventoryname.toLowerCase(),
        );

        // Use inventory item ID if found, otherwise use transaction ID
        final itemId = inventoryItem?.id ?? transaction.id;

        cartItems.add({
          'id': itemId,
          'name': transaction.inventoryname,
          'quantity': transaction.quantity.toInt(),
          'price': transaction.sellingprice,
          'amount': transaction.amount,
          'item': inventoryItem, // Include full inventory item if found
        });
      }

      // Extract other sale details
      final reference = sale['reference'] as String? ?? '';
      final notes = firstTransaction.remarks;

      // Navigate to POS screen with existing sale data
      await Get.to(
        () => PosScreen(
          existingSalesId: salesId,
          existingItems: cartItems,
          existingCustomerId: customerId,
          existingReference: reference,
          existingNotes: notes,
          existingSalespersonId: salespersonId,
        ),
        transition: Transition.rightToLeft,
      );

      // Refresh sales list after returning from POS screen
      await salesController.loadSalesFromCache();
    } catch (e) {
      // Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      print('Error loading sale for edit: $e');
      Get.snackbar(
        'Error',
        'Failed to load sale details: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    }
  }
}
