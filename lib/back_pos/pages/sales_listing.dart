import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../controllers/sales_controller.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/service_point_controller.dart';
import '../controllers/settings_controller.dart';
import '../models/inventory_item.dart';
import '../models/service_point.dart';
import '../services/print_service.dart';
import '../services/sales_sync_service.dart';
import 'pos_screen.dart';
import 'payment_screen.dart';
import 'settle_bill_screen.dart';

class SalesListing extends StatefulWidget {
  const SalesListing({super.key});

  @override
  State<SalesListing> createState() => _SalesListingState();
}

class _SalesListingState extends State<SalesListing> {
  final SalesController salesController = Get.find<SalesController>();
  final AuthController authController = Get.find<AuthController>();
  final InventoryController inventoryController = Get.find<InventoryController>();
  final TextEditingController searchController = TextEditingController();
  final RxList<Map<String, dynamic>> filteredSales = <Map<String, dynamic>>[].obs;
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    // Load sales from cache when screen opens
    salesController.loadSalesFromCache();
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
  bool _isCashierRole() {
    final currentUser = authController.currentUser.value;
    if (currentUser == null) return false;

    final role = currentUser.role.toLowerCase();
    final settingsController = Get.find<SettingsController>();
    final allowAllUsersPayment = settingsController.paymentAccessForAllUsers.value;

    // Allow cashiers or if setting is enabled, also allow waiters
    return role == 'cashier' || role.contains('cashier') ||
           (allowAllUsersPayment && role == 'waiter');
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
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () async {
                final salesSyncService = Get.find<SalesSyncService>();
                await salesSyncService.manualSync();
                await salesController.refreshSales();
              },
              tooltip: 'Sync with Server & Reload',
            ),
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
                        : "Create sales using the POS screen",
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
    final paymentType = sale['paymenttype'] as String? ?? 'Pending';
    final cancelled = sale['cancelled'] as int? ?? 0;
    final uploadStatus = sale['upload_status'] as String? ?? 'pending';
    final uploadError = sale['upload_error'] as String?;

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
                    color: cancelled > 0 
                        ? Colors.red.shade700 
                        : uploadStatus == 'uploaded' 
                            ? Colors.green.shade700
                            : uploadStatus == 'failed'
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
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
                      tooltip: uploadStatus == 'uploaded'
                          ? 'View'
                          : 'Edit',
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
                        // Only show settle bill option for cashier roles
                        if (_isCashierRole()) ...[
                          PopupMenuItem(
                            value: 'settleBill',
                            child: Row(
                              children: [
                                Icon(Icons.sync, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Settle bill',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
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
            SizedBox(height: 6),
            if (cancelled > 0) ...[
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

            // Show upload error if present
            if (uploadError != null && uploadError.isNotEmpty) ...[
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 14, color: Colors.red.shade700),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        uploadError,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            ],
        ),
      ),
    );
  }

  Future<void> _handlePrint(Map<String, dynamic> sale) async {
    final salesController = Get.find<SalesController>();

    final receiptNumber = sale['receiptnumber'] as String? ?? '';
    final salesId = sale['salesId'] as String?;

    if (salesId == null) {
      Get.snackbar(
        'Error',
        'Cannot print: Invalid sale ID',
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
                  Text('Preparing receipt...'),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Fetch sale transactions
      final saleTransactions = await salesController.getSaleTransactionsBySalesId(salesId);

      // Close loading dialog
      Get.back();

      if (saleTransactions.isEmpty) {
        Get.snackbar(
          'Error',
          'No items found for this receipt',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }

      // Get sale details
      final firstTransaction = saleTransactions.first;
      final customerName = firstTransaction.destinationbp;
      final date = DateTime.fromMillisecondsSinceEpoch(firstTransaction.transactiondate);
      final notes = firstTransaction.remarks;
      final paymentMode = firstTransaction.paymentmode;

      String cashierName = 'Cashier';
      final currentUser = authController.currentUser.value;
      if (currentUser != null) {
        cashierName = currentUser.staff ?? currentUser.name ?? 'Cashier';
      }

      // Calculate totals
      double totalAmount = 0;
      double amountPaid = 0;
      for (var transaction in saleTransactions) {
        totalAmount += transaction.amount;
        amountPaid += transaction.amountpaid;
      }
      final balance = totalAmount - amountPaid;

      // Check if amount paid is 0 or null to determine print type
      final bool isUnpaid = amountPaid == 0 || amountPaid.isNaN;
      
      // Show print options dialog
      await Get.dialog(
        AlertDialog(
          title: Text('Print Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.print, color: Colors.blue),
                title: Text(isUnpaid ? 'Print Bill' : 'Print Receipt'),
                subtitle: Text('Print to connected printer'),
                onTap: () async {
                  Get.back();
                  try {
                    if (isUnpaid) {
                      await PrintService.printBill(
                        receiptNumber: receiptNumber,
                        customerName: customerName,
                        date: date,
                        items: saleTransactions,
                        totalAmount: totalAmount,
                        issuedBy: cashierName,
                        notes: notes.isNotEmpty ? notes : null,
                      );
                    } else {
                      await PrintService.printReceipt(
                        receiptNumber: receiptNumber,
                        customerName: customerName,
                        date: date,
                        items: saleTransactions,
                        totalAmount: totalAmount,
                        amountPaid: amountPaid,
                        balance: balance,
                        paymentMode: paymentMode,
                        issuedBy: cashierName,
                        notes: notes.isNotEmpty ? notes : null,
                      );
                    }
                  } catch (e) {
                    Get.snackbar(
                      'Print Error',
                      'Failed to print',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red.shade700,
                      colorText: Colors.white,
                    );
                  }
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.share, color: Colors.green),
                title: Text(isUnpaid ? 'Share Bill PDF' : 'Share Receipt PDF'),
                subtitle: Text('Share as PDF file'),
                onTap: () async {
                  Get.back();
                  try {
                    if (isUnpaid) {
                      await PrintService.shareBill(
                        receiptNumber: receiptNumber,
                        customerName: customerName,
                        date: date,
                        items: saleTransactions,
                        totalAmount: totalAmount,
                        issuedBy: cashierName,
                        notes: notes.isNotEmpty ? notes : null,
                      );
                    } else {
                      await PrintService.shareReceipt(
                        receiptNumber: receiptNumber,
                        customerName: customerName,
                        date: date,
                        items: saleTransactions,
                        totalAmount: totalAmount,
                        amountPaid: amountPaid,
                        balance: balance,
                        paymentMode: paymentMode,
                        issuedBy: cashierName,
                        notes: notes.isNotEmpty ? notes : null,
                      );
                    }
                  } catch (e) {
                    Get.snackbar(
                      'Share Error',
                      'Failed to share',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red.shade700,
                      colorText: Colors.white,
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        'Error',
        'Failed to prepare receipt: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _handleAction(String action, Map<String, dynamic> sale) async {
    final receiptNumber = sale['receiptnumber'] as String? ?? '';
    final salesId = sale['salesId'] as String?;

    switch (action) {
      case 'upload':
        if (salesId == null) {
          Get.snackbar(
            'Error',
            'Cannot upload sale: Invalid sale ID',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
          );
          return;
        }

        // Check if already uploaded
        final uploadStatus = sale['upload_status'] as String? ?? 'pending';
        if (uploadStatus == 'uploaded') {
          Get.snackbar(
            'Already Uploaded',
            'Sale $receiptNumber has already been uploaded to the server',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.blue.shade700,
            colorText: Colors.white,
            duration: Duration(seconds: 2),
          );
          return;
        }

        // Show loading dialog
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
                    Text('Uploading sale to server...'),
                  ],
                ),
              ),
            ),
          ),
          barrierDismissible: false,
        );

        try {
          // Upload sale to server
          await salesController.uploadSaleToServer(salesId);

          // Close loading dialog
          Get.back();

          // Show success message
          Get.snackbar(
            'Success', "Payment successful",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade700,
            colorText: Colors.white,
            duration: Duration(seconds: 3),
          );
        } catch (e) {
          // Close loading dialog
          if (Get.isDialogOpen ?? false) {
            Get.back();
          }

          // Show error message
          Get.snackbar(
            'Upload Failed',
            'Failed to upload sale $receiptNumber: ${e.toString()}',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
            duration: Duration(seconds: 5),
          );
        }
        break;

      case 'fiscalise':
        Get.snackbar(
          'Not available for the moment ...', "Coming soon ",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade700,
          colorText: Colors.white,
        );
        break;

      case 'settleBill':
        if (salesId == null) {
          Get.snackbar(
            'Error',
            'Cannot settle bill: Invalid sale ID',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
          );
          return;
        }

        // Check if sale has balance > 0
        final totalBalance = sale['totalBalance'] as double? ?? 0.0;
        if (totalBalance <= 0) {
          Get.snackbar(
            'No Balance',
            'This sale has no outstanding balance to settle',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.blue.shade700,
            colorText: Colors.white,
          );
          return;
        }

        final uploadStatus = sale['upload_status'] as String? ?? 'pending';

         if (uploadStatus == 'uploaded') {
           await Get.to(
             () => SettleBillScreen(
               salesId: salesId,
               receiptNumber: receiptNumber,
             ),
             transition: Transition.rightToLeft,
           );

           await salesController.loadSalesFromCache();
         } else {
           // For non-uploaded sales, use the old flow
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

             final firstTransaction = saleTransactions.first;
             final customerId = firstTransaction.clientid;

             final salespersonId = firstTransaction.salespersonid;

             // Transform sale transactions to cart items format
             final cartItems = <Map<String, dynamic>>[];
             for (var transaction in saleTransactions) {
               // Try to find the inventory item by name or ID
               final inventoryItems = inventoryController.inventoryItems;

               // First try to find by inventoryid
               var inventoryItem = inventoryItems.firstWhereOrNull(
                 (item) => item.id == transaction.inventoryid,
               );

               // If not found, try by name
               if (inventoryItem == null) {
                 inventoryItem = inventoryItems.firstWhereOrNull(
                   (item) => item.name.toLowerCase() == transaction.inventoryname.toLowerCase(),
                 );
               }

               // If still not found, create a minimal inventory item object with all required fields
               if (inventoryItem == null) {
                 inventoryItem = InventoryItem(
                   id: transaction.inventoryid ?? transaction.id,
                   ipdid: transaction.ipdid ?? '',
                   name: transaction.inventoryname,
                   code: '',
                   externalserial: '',
                   category: transaction.category,
                   price: transaction.sellingprice.toDouble(),
                   costprice: transaction.costprice,
                   packsize: transaction.packsize.toDouble(),
                   packaging: transaction.packaging,
                   packagingid: '',
                   soldfrom: '',
                   shortform: '',
                   packagingcode: '',
                   efris: false,
                   efrisid: '',
                   measurmentunitidefris: '',
                   measurmentunit: '',
                   measurmentunitid: '',
                   vatcategoryid: '',
                   branchid: transaction.branchid ?? '',
                   companyid: transaction.companyid ?? '',
                 );
               }

               cartItems.add({
                 'id': inventoryItem.id,
                 'name': transaction.inventoryname,
                 'quantity': transaction.quantity.toInt(),
                 'price': transaction.sellingprice,
                 'amount': transaction.amount,
                 'item': inventoryItem,
               });
             }

             final reference = firstTransaction.purchaseordernumber ?? '';
             final notes = firstTransaction.remarks ?? '';

             await Get.to(
               () => PaymentScreen(
                 cartItems: cartItems,
                 customer: customerId,
                 reference: reference,
                 notes: notes,
                 salespersonId: salespersonId,
                 isUpdateMode: true,
                 existingSalesId: salesId,
                 existingReceiptNumber: receiptNumber,
               ),
               transition: Transition.rightToLeft,
             );

             await salesController.loadSalesFromCache();
           } catch (e) {
             if (Get.isDialogOpen ?? false) {
               Get.back();
             }

             Get.snackbar(
               'Error',
               'Failed to load sale details for settlement',
               snackPosition: SnackPosition.BOTTOM,
               backgroundColor: Colors.red.shade700,
               colorText: Colors.white,
             );
           }
         }
        break;

      case 'synchronise':
        Get.snackbar(
          'Synchronise',
          'Synchronising $receiptNumber...',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade700,
          colorText: Colors.white,
        );
        break;
    }
  }

  Future<void> _handleEdit(Map<String, dynamic> sale) async {
    final salesController = Get.find<SalesController>();
    final inventoryController = Get.find<InventoryController>();

    final receiptNumber = sale['receiptnumber'] as String? ?? '';
    final salesId = sale['salesId'] as String?;
    final uploadStatus = sale['upload_status'] as String? ?? 'pending';

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

      // Get customer ID directly from first transaction (more reliable than name matching)
      final firstTransaction = saleTransactions.first;
      final customerId = firstTransaction.clientid;

      // Get salesperson ID directly from first transaction
      final salespersonId = firstTransaction.salespersonid;

      final servicePointController = Get.find<ServicePointController>();
      ServicePoint? servicePoint;
      if (firstTransaction.servicepointid != null) {
        servicePoint = servicePointController.getServicePointById(firstTransaction.servicepointid!);
      }

      // Transform sale transactions to cart items format
      final cartItems = <Map<String, dynamic>>[];
      for (var transaction in saleTransactions) {
        // Try to find the inventory item by name or ID
        final inventoryItems = inventoryController.inventoryItems;

        var inventoryItem = inventoryItems.firstWhereOrNull(
          (item) => item.id == transaction.inventoryid,
        );

        // If not found, try by name
        if (inventoryItem == null) {
          inventoryItem = inventoryItems.firstWhereOrNull(
            (item) => item.name.toLowerCase() == transaction.inventoryname.toLowerCase(),
          );
        }

        // If still not found, create a minimal inventory item object with all required fields
        if (inventoryItem == null) {
          inventoryItem = InventoryItem(
            id: transaction.inventoryid ?? transaction.id,
            ipdid: transaction.ipdid ?? '',
            name: transaction.inventoryname,
            code: '',
            externalserial: '',
            category: transaction.category,
            price: transaction.sellingprice.toDouble(),
            costprice: transaction.costprice,
            packsize: transaction.packsize.toDouble(),
            packaging: transaction.packaging,
            packagingid: '',
            soldfrom: '',
            shortform: '',
            packagingcode: '',
            efris: false,
            efrisid: '',
            measurmentunitidefris: '',
            measurmentunit: '',
            measurmentunitid: '',
            vatcategoryid: '',
            branchid: transaction.branchid ?? '',
            companyid: transaction.companyid ?? '',
          );
        }

        cartItems.add({
          'id': inventoryItem.id,
          'name': transaction.inventoryname,
          'quantity': transaction.quantity.toInt(),
          'price': transaction.sellingprice,
          'amount': transaction.amount,
          'item': inventoryItem,
        });
      }

      final reference = firstTransaction.purchaseordernumber ?? '';
      final notes = firstTransaction.remarks ?? '';

      await Get.to(
        () => PosScreen(
          existingSalesId: salesId,
          existingReceiptNumber: receiptNumber,
          existingItems: cartItems,
          existingCustomerId: customerId,
          existingReference: reference,
          existingNotes: notes,
          existingSalespersonId: salespersonId,
          servicePoint: servicePoint,
          isViewOnly: uploadStatus == 'uploaded',
        ),
        transition: Transition.rightToLeft,
      );

      await salesController.loadSalesFromCache();
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        'Error',
        'Failed to load sale details',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    }
  }
}
