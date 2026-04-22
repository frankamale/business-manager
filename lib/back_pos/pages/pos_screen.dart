import 'dart:async';
import 'package:bac_pos/bac_monitor/lib/additions/colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../widgets/barcode_scanner.dart';
import 'payment_screen.dart';
import '../models/inventory_item.dart';
import '../models/service_point.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/customer_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/payment_controller.dart';
import '../controllers/settings_controller.dart';
import '../services/print_service.dart';
import '../../shared/database/unified_db_helper.dart';
import '../models/sale_transaction.dart';
import '../../flavors/flavor_colors.dart';

class PosScreen extends StatefulWidget {
  final String? existingSalesId;
  final String? existingReceiptNumber;
  final List<Map<String, dynamic>>? existingItems;
  final String? existingCustomerId;
  final String? existingReference;
  final String? existingNotes;
  final String? existingSalespersonId;
  final ServicePoint? servicePoint;
  final bool isViewOnly;

  const PosScreen({
    super.key,
    this.existingSalesId,
    this.existingReceiptNumber,
    this.existingItems,
    this.existingCustomerId,
    this.existingReference,
    this.existingNotes,
    this.existingSalespersonId,
    this.servicePoint,
    this.isViewOnly = false,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final NumberFormat _numberFormat = NumberFormat('#,###', 'en_US');
  final InventoryController inventoryController = Get.find();
  final CustomerController customerController = Get.find();
  final AuthController authController = Get.find();
  final SettingsController settingsController = Get.find();
  String selectedCategory = 'All';
  final TextEditingController searchController = TextEditingController();
  String? selectedSalespersonId;

  String formatMoney(double amount) {
    return _numberFormat.format(amount.toInt());
  }

  String? selectedCustomerId;
  final TextEditingController refController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  final List<Map<String, dynamic>> selectedItems = [];

  final Map<String, TextEditingController> _priceControllers = {};

  bool _isPriceEditingEnabled = false;

  double get totalAmount {
    return selectedItems.fold(0, (sum, item) => sum + (item['amount'] as num));
  }

  bool _isCashierRole() {
    final currentUser = authController.currentUser.value;
    if (currentUser == null) return false;

    final role = currentUser.role.toLowerCase();
    final allowAllUsersPayment =
        settingsController.paymentAccessForAllUsers.value;

    // Allow cashiers or if setting is enabled, also allow waiters
    return role == 'cashier' ||
        role.contains('cashier') ||
        (allowAllUsersPayment && role == 'waiter');
  }

  void _addItemToCart(InventoryItem item) {
    setState(() {
      final existingItemIndex = selectedItems.indexWhere(
        (cartItem) => cartItem['id'] == item.id,
      );

      if (existingItemIndex != -1) {
        selectedItems[existingItemIndex]['quantity'] += 1;
        selectedItems[existingItemIndex]['amount'] =
            selectedItems[existingItemIndex]['quantity'] * item.price;
      } else {
        // New item, add to cart
        selectedItems.add({
          'id': item.id,
          'name': item.name,
          'quantity': 1,
          'price': item.price,
          'amount': item.price,
          'item': item,
          'complimentary': false,
        });

        // Create a controller for this item's price
        _priceControllers[item.id] = TextEditingController(
          text: item.price.toStringAsFixed(0),
        );
      }
    });
  }

  void _removeItemFromCart(int index) {
    setState(() {
      final item = selectedItems[index];
      // Dispose the price controller for this item
      _priceControllers[item['id']]?.dispose();
      _priceControllers.remove(item['id']);
      selectedItems.removeAt(index);
    });
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItemFromCart(index);
      return;
    }

    setState(() {
      selectedItems[index]['quantity'] = newQuantity;
      selectedItems[index]['amount'] =
          newQuantity * selectedItems[index]['price'];
    });
  }

  void _updatePrice(int index, double newPrice) {
    setState(() {
      selectedItems[index]['price'] = newPrice;
      selectedItems[index]['amount'] =
          selectedItems[index]['quantity'] * newPrice;
    });
  }

  void _showItemDetailsDialog(int index) {
    final item = selectedItems[index];
    final inventoryItem = item['item'] as InventoryItem;
    bool isComplimentary = item['complimentary'] == true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                item['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category: ${inventoryItem.category}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Price per unit: UGX ${formatMoney(inventoryItem.price)}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                  if (inventoryItem.packaging.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Packaging: ${inventoryItem.packaging}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                  ],
                  const Divider(height: 24),
                  CheckboxListTile(
                    title: const Text('Complimentary'),
                    subtitle: const Text('Set price to 0 for this item'),
                    value: isComplimentary,
                    activeColor: FlavorColors.current.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setDialogState(() {
                        isComplimentary = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedItems[index]['complimentary'] = isComplimentary;
                      if (isComplimentary) {
                        selectedItems[index]['price'] = 0.0;
                        selectedItems[index]['amount'] = 0.0;
                        _priceControllers[item['id']]?.text = '0';
                      } else {
                        selectedItems[index]['price'] = inventoryItem.price;
                        selectedItems[index]['amount'] =
                            selectedItems[index]['quantity'] *
                            inventoryItem.price;
                        _priceControllers[item['id']]?.text = inventoryItem
                            .price
                            .toStringAsFixed(0);
                      }
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onSearchChanged() {
    inventoryController.searchInventory(searchController.text);
  }

  @override
  void initState() {
    super.initState();

    if (widget.existingItems != null && widget.existingItems!.isNotEmpty) {
      _loadExistingSale();
    } else {
      final cashCustomer = customerController.getCustomerByFullnames(
        "Cash Customer ",
      );
      if (cashCustomer != null) {
        selectedCustomerId = cashCustomer.id;
      }
      final currentUser = authController.currentUser.value;
      if (currentUser != null && currentUser.salespersonid.isNotEmpty) {
        selectedSalespersonId = currentUser.salespersonid;
      }
    }

    searchController.addListener(_onSearchChanged);

    if (widget.servicePoint != null) {
      inventoryController.filterByServicePointType(
        widget.servicePoint!.servicepointtype,
      );
    }
  }

  void _loadExistingSale() {
    setState(() {
      // Load existing items into cart
      if (widget.existingItems != null) {
        selectedItems.addAll(widget.existingItems!);
        // Create price controllers for existing items
        for (var item in widget.existingItems!) {
          _priceControllers[item['id']] = TextEditingController(
            text: (item['price'] as num).toStringAsFixed(0),
          );
        }
      }

      // Load existing customer
      if (widget.existingCustomerId != null) {
        selectedCustomerId = widget.existingCustomerId;
      }

      // Load existing reference
      if (widget.existingReference != null) {
        refController.text = widget.existingReference!;
      }

      // Load existing notes
      if (widget.existingNotes != null) {
        notesController.text = widget.existingNotes!;
      }

      // Load existing salesperson
      if (widget.existingSalespersonId != null) {
        selectedSalespersonId = widget.existingSalespersonId;
      }
    });

    // Show mode indicator after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {}
    });
  }

  @override
  void dispose() {
    refController.dispose();
    notesController.dispose();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    // Dispose all price controllers
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
    _priceControllers.clear();
    super.dispose();
  }

  Future<void> _navigateToPayment() async {
    if (selectedItems.isEmpty) {
      Get.snackbar(
        'Error',
        'No items in cart',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
      duration:
      const Duration(seconds: 1);
      return;
    }

    final result = await Get.to(
      () => PaymentScreen(
        cartItems: selectedItems,
        customer: selectedCustomerId,
        reference: refController.text,
        notes: notesController.text,
        salespersonId: selectedSalespersonId,
        servicePointId: widget.servicePoint?.id,
        isUpdateMode: widget.existingSalesId != null,
        existingSalesId: widget.existingSalesId,
        existingReceiptNumber: widget.existingReceiptNumber,
      ),
    );

    if (result == true) {
      setState(() {
        // Dispose all price controllers
        for (var controller in _priceControllers.values) {
          controller.dispose();
        }
        _priceControllers.clear();
        selectedItems.clear();
        refController.clear();
        notesController.clear();
        final cashCustomer = customerController.getCustomerByFullnames(
          "Cash Customer ",
        );
        selectedCustomerId = cashCustomer?.id;
        final currentUser = authController.currentUser.value;
        if (currentUser != null && currentUser.salespersonid.isNotEmpty) {
          selectedSalespersonId = currentUser.salespersonid;
        }
      });
    }
  }

  Future<void> _saveBill() async {
    if (selectedItems.isEmpty) {
      Get.snackbar(
        'Error',
        'No items in cart',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
      duration:
      const Duration(seconds: 1);
      return;
    }
    try {
      final paymentController = Get.find<PaymentController>();
      final result = await paymentController.processSaleAndPayment(
        cartItems: selectedItems,
        customerId: selectedCustomerId,
        reference: refController.text,
        notes: notesController.text,
        salespersonId: selectedSalespersonId,
        servicePointId: widget.servicePoint?.id,
        amountTendered: 0,
      );
      if (result['success'] == true) {
        final db = await UnifiedDatabaseHelper.instance.database;
        final maps = await db!.query(
          'sales_transactions',
          where: 'receiptnumber = ?',
          whereArgs: [result['receiptnumber']],
        );
        final items = maps.map((m) => SaleTransaction.fromMap(m)).toList();

        // Get customer name
        String customerName = 'Cash Customer';
        if (selectedCustomerId != null) {
          final customer = customerController.getCustomerById(
            selectedCustomerId!,
          );
          if (customer != null) {
            customerName = customer.fullnames;
          }
        }

        // Get salesperson name
        String issuedBy = '';
        final currentUser = authController.currentUser.value;
        if (currentUser != null) {
          issuedBy = currentUser.staff;
        }

        // Print the bill
        await PrintService.printBill(
          receiptNumber: result['receiptnumber'],
          customerName: customerName,
          date: DateTime.now(),
          items: items,
          totalAmount: totalAmount,
          issuedBy: issuedBy,
          notes: notesController.text,
        );

        setState(() {
          // Dispose all price controllers
          for (var controller in _priceControllers.values) {
            controller.dispose();
          }
          _priceControllers.clear();
          selectedItems.clear();
          refController.clear();
          notesController.clear();
          final cashCustomer = customerController.getCustomerByFullnames(
            "Cash Customer ",
          );
          selectedCustomerId = cashCustomer?.id;
          // Reset salesperson to logged-in user
          final currentUser = authController.currentUser.value;
          if (currentUser != null && currentUser.salespersonid.isNotEmpty) {
            selectedSalespersonId = currentUser.salespersonid;
          }
        });

        Get.snackbar(
          'Success',
          'Bill saved successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
        );
      } else {
        Get.snackbar(
          'Error',
          'Failed to save bill',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'An error occurred',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    }
  }

  Future<void> _updateSale() async {
    if (selectedItems.isEmpty) {
      Get.snackbar(
        'Error',
        'No items in cart',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
      return;
    }

    if (widget.existingSalesId == null ||
        widget.existingReceiptNumber == null) {
      Get.snackbar(
        'Error',
        'Invalid sale data',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
      return;
    }

    final bool isWaiter = (authController.currentUser.value?.role ?? '')
        .toLowerCase()
        .contains('waiter');
    final bool allowAllUsersPayment =
        settingsController.paymentAccessForAllUsers.value;

    // For waiters, update bill without payment if setting doesn't allow all users payment
    if (isWaiter && !allowAllUsersPayment) {
      await _updateBillWithoutPayment();
      return;
    }

    final result = await Get.to(
      () => PaymentScreen(
        cartItems: selectedItems,
        customer: selectedCustomerId,
        reference: refController.text,
        notes: notesController.text,
        salespersonId: selectedSalespersonId,
        servicePointId: widget.servicePoint?.id,
        isUpdateMode: true,
        existingSalesId: widget.existingSalesId,
        existingReceiptNumber: widget.existingReceiptNumber,
      ),
    );

    // If update was successful, go back to sales listing
    if (result == true) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _updateBillWithoutPayment() async {
    try {
      final paymentController = Get.find<PaymentController>();
      final result = await paymentController.updateSale(
        existingSalesId: widget.existingSalesId!,
        existingReceiptNumber: widget.existingReceiptNumber!,
        cartItems: selectedItems,
        amountTendered: 0,
        // No payment for waiters
        customerId: selectedCustomerId,
        reference: refController.text,
        notes: notesController.text,
        salespersonId: selectedSalespersonId,
        servicePointId: widget.servicePoint?.id,
      );

      if (result['success'] == true) {
        // Get the sale transactions for printing
        final db = await UnifiedDatabaseHelper.instance.database;
        final maps = await db!.query(
          'sales_transactions',
          where: 'receiptnumber = ?',
          whereArgs: [result['receiptnumber']],
        );
        final items = maps.map((m) => SaleTransaction.fromMap(m)).toList();

        // Get customer name
        String customerName = 'Cash Customer';
        if (selectedCustomerId != null) {
          final customer = customerController.getCustomerById(
            selectedCustomerId!,
          );
          if (customer != null) {
            customerName = customer.fullnames;
          }
        }

        // Get salesperson name
        String issuedBy = '';
        final currentUser = authController.currentUser.value;
        if (currentUser != null) {
          issuedBy = currentUser.staff;
        }

        // Print the updated bill
        await PrintService.printBill(
          receiptNumber: result['receiptnumber'],
          customerName: customerName,
          date: DateTime.now(),
          items: items,
          totalAmount: totalAmount,
          issuedBy: issuedBy,
          notes: notesController.text,
        );

        Get.snackbar(
          'Success',
          'Bill updated successfully!\nReceipt: ${result['receiptnumber']}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
          duration: const Duration(seconds: 3),
        );

        // Go back to sales listing
        Navigator.of(context).pop(true);
      } else {
        Get.snackbar(
          'Error',
          'Failed to update bill',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update bill: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    }
  }

  Widget _buildItemCard(InventoryItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          _addItemToCart(item);
          inventoryController.clearSearch();
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: FlavorColors.current.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: FlavorColors.current.icon,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),

              // Item Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.code.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: FlavorColors.current.surface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.code,
                              style: TextStyle(
                                fontSize: 11,
                                color: FlavorColors.current.tertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: FlavorColors.current.tertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'UGX ${item.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  if (item.costprice != null && item.costprice! > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Cost: ${item.costprice!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: FlavorColors.current.tertiary,
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),
                  Text(
                    '${item.packaging} • ${item.measurmentunit}',
                    style: TextStyle(
                      fontSize: 11,
                      color: FlavorColors.current.tertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        foregroundColor: Colors.white,

        title: const Text(
          "POS Sale",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: FlavorColors.current.primary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Get.to(() => const BarcodeScannerPage());

          if (result is InventoryItem) {
            _addItemToCart(result);
            inventoryController.clearSearch();
          }
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Total Display (not scrollable)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                width: double.infinity,
                height: isKeyboardVisible ? 50 : 65,
                decoration: BoxDecoration(
                  color: FlavorColors.current.primaryDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "UGX ${formatMoney(totalAmount)}",
                  style: TextStyle(
                    color: FlavorColors.current.onPrimary,
                    fontSize: isKeyboardVisible ? 24 : 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: isKeyboardVisible ? 4 : 8),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 80,
                          child: Text(
                            "Client:",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: PrimaryColors.lightBlue,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Obx(() {
                            if (customerController.isLoadingCustomers.value) {
                              return const SizedBox(
                                height: 36,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            if (widget.isViewOnly) {
                              final customer = customerController.customers
                                  .firstWhereOrNull(
                                    (c) => c.id == selectedCustomerId,
                                  );
                              final customerName = customer?.fullnames ?? '';
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              );
                            } else {
                              return DropdownButtonFormField<String>(
                                value: selectedCustomerId,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  isDense: true,
                                ),
                                items: customerController.customers.map((
                                  customer,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: customer.id,
                                    child: Text(
                                      customer.fullnames,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    selectedCustomerId = newValue;
                                  });
                                },
                              );
                            }
                          }),
                        ),
                      ],
                    ),
                    SizedBox(height: isKeyboardVisible ? 4 : 8),

                    // Salesperson Display
                    if (!isKeyboardVisible) ...[
                      Row(
                        children: [
                          const SizedBox(
                            width: 85,
                            child: Text(
                              "Salesperson:",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: PrimaryColors.lightBlue,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Obx(() {
                              final currentUser =
                                  authController.currentUser.value;
                              final salespersonName =
                                  currentUser?.staff ?? 'Unknown User';
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey.shade50,
                                ),
                                child: Text(
                                  salespersonName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Reference Field
                    Row(
                      children: [
                        const SizedBox(
                          width: 80,
                          child: Text(
                            "Ref:",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: PrimaryColors.lightBlue,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: refController,
                            readOnly: widget.isViewOnly,
                            decoration: InputDecoration(
                              hintText: "Reference number",
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isKeyboardVisible ? 4 : 8),

                    // Notes Field
                    Row(
                      children: [
                        const SizedBox(
                          width: 80,
                          child: Text(
                            "Notes:",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: PrimaryColors.lightBlue,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: notesController,
                            readOnly: widget.isViewOnly,
                            decoration: InputDecoration(
                              hintText: "Add notes",
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isKeyboardVisible ? 4 : 8),

                    // Selected Items Container
                    Container(
                      height: 500,
                      decoration: BoxDecoration(
                        border: Border.all(color: FlavorColors.current.light),
                        borderRadius: BorderRadius.circular(8),
                        color: FlavorColors.current.surface,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    "Item",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 50,
                                  child: Text(
                                    "Qty",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    "Amount",
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Items List
                          Expanded(
                            child: selectedItems.isEmpty
                                ? const Center(
                                    child: Text(
                                      "No items selected",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: selectedItems.length,
                                    itemBuilder: (context, index) {
                                      final item = selectedItems[index];
                                      final isComp =
                                          item['complimentary'] == true;
                                      return GestureDetector(
                                        onTap: widget.isViewOnly
                                            ? null
                                            : () =>
                                                  _showItemDetailsDialog(index),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isComp
                                                ? FlavorColors.current.light
                                                      .withValues(alpha: 0.3)
                                                : null,
                                            border: Border(
                                              bottom: BorderSide(
                                                color:
                                                    FlavorColors.current.light,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            item['name'],
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color:
                                                                  PrimaryColors
                                                                      .lightBlue,
                                                            ),
                                                          ),
                                                        ),
                                                        if (isComp) ...[
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 4,
                                                                  vertical: 1,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  FlavorColors
                                                                      .current
                                                                      .primary,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    3,
                                                                  ),
                                                            ),
                                                            child: const Text(
                                                              'COMP',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 9,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        const Text(
                                                          'UGX ',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: 80,
                                                          child: TextField(
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            readOnly:
                                                                widget
                                                                    .isViewOnly ||
                                                                !settingsController
                                                                    .priceEditingEnabled
                                                                    .value,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                            decoration: InputDecoration(
                                                              isDense: true,
                                                              contentPadding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        4,
                                                                    vertical: 2,
                                                                  ),
                                                              border: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                                borderSide: BorderSide(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade300,
                                                                ),
                                                              ),
                                                              enabledBorder: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                                borderSide: BorderSide(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade300,
                                                                ),
                                                              ),
                                                              disabledBorder: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                                borderSide: BorderSide(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade200,
                                                                ),
                                                              ),
                                                              fillColor:
                                                                  (widget.isViewOnly ||
                                                                      !_isPriceEditingEnabled)
                                                                  ? Colors
                                                                        .grey
                                                                        .shade50
                                                                  : Colors
                                                                        .white,
                                                              filled: true,
                                                            ),
                                                            controller:
                                                                _priceControllers[item['id']],
                                                            onChanged:
                                                                (widget.isViewOnly ||
                                                                    !settingsController
                                                                        .priceEditingEnabled
                                                                        .value)
                                                                ? null
                                                                : (value) {
                                                                    if (value
                                                                        .isEmpty) {
                                                                      _updatePrice(
                                                                        index,
                                                                        0,
                                                                      );
                                                                    } else {
                                                                      final newPrice =
                                                                          double.tryParse(
                                                                            value,
                                                                          );
                                                                      if (newPrice !=
                                                                          null) {
                                                                        _updatePrice(
                                                                          index,
                                                                          newPrice,
                                                                        );
                                                                      }
                                                                    }
                                                                  },
                                                          ),
                                                        ),
                                                        const Text(
                                                          ' each',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  InkWell(
                                                    onTap: widget.isViewOnly
                                                        ? null
                                                        : () => _updateQuantity(
                                                            index,
                                                            item['quantity'] -
                                                                1,
                                                          ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: FlavorColors
                                                            .current
                                                            .surface,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors
                                                              .red
                                                              .shade900,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        Icons.remove,
                                                        size: 16,
                                                        color:
                                                            Colors.red.shade900,
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                        ),
                                                    child: Text(
                                                      "${item['quantity']}",
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: widget.isViewOnly
                                                        ? null
                                                        : () => _updateQuantity(
                                                            index,
                                                            item['quantity'] +
                                                                1,
                                                          ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: FlavorColors
                                                            .current
                                                            .surface,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors
                                                              .green
                                                              .shade900,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        Icons.add,
                                                        size: 16,
                                                        color: Colors
                                                            .green
                                                            .shade900,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              SizedBox(
                                                width: 80,
                                                child: Text(
                                                  formatMoney(item['amount']),
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
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
            // Action Buttons (outside scrollview)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 12,
              ),
              child: widget.existingSalesId != null && widget.isViewOnly
                  ? // View-only mode - show only Close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              inventoryController.clearSearch();
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: FlavorColors.current.primaryDark,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Close"),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final bool isWaiter =
                                  (authController.currentUser.value?.role ?? '')
                                      .toLowerCase()
                                      .contains('waiter');
                              final bool isNewSale =
                                  widget.existingSalesId == null;
                              final bool allowAllUsersPayment =
                                  settingsController
                                      .paymentAccessForAllUsers
                                      .value;

                              if (isNewSale &&
                                  isWaiter &&
                                  !allowAllUsersPayment) {
                                _saveBill();
                              } else if (isNewSale) {
                                _navigateToPayment();
                              } else {
                                _updateSale();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: PrimaryColors.lightBlue,
                              foregroundColor: FlavorColors.current.onPrimary,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(() {
                              final bool isCashier = _isCashierRole();
                              final bool isNewSale =
                                  widget.existingSalesId == null;
                              final bool allowAllUsersPayment =
                                  settingsController
                                      .paymentAccessForAllUsers
                                      .value;
                              return (isNewSale &&
                                      !isCashier &&
                                      !allowAllUsersPayment)
                                  ? "SAVE"
                                  : "SAVE";
                            }()),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (widget.existingSalesId != null) {
                                Navigator.of(context).pop();
                              } else {
                                setState(() {
                                  for (var controller
                                      in _priceControllers.values) {
                                    controller.dispose();
                                  }
                                  _priceControllers.clear();
                                  selectedItems.clear();
                                  refController.clear();
                                  notesController.clear();
                                  final cashCustomer = customerController
                                      .getCustomerByFullnames("Cash Customer ");
                                  selectedCustomerId = cashCustomer?.id;
                                  // Reset salesperson to logged-in user
                                  final currentUser =
                                      authController.currentUser.value;
                                  if (currentUser != null &&
                                      currentUser.salespersonid.isNotEmpty) {
                                    selectedSalespersonId =
                                        currentUser.salespersonid;
                                  }
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: widget.existingSalesId != null
                                  ? FlavorColors.current.tertiary
                                  : Colors.green.shade800,
                              foregroundColor: FlavorColors.current.onPrimary,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              widget.existingSalesId != null ? "Cancel" : "New",
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: widget.isViewOnly
                                ? null
                                : () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor:
                                          FlavorColors.current.surface,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(20),
                                        ),
                                      ),
                                      builder: (BuildContext context) {
                                        // Calculate height to leave space for the price display section
                                        final screenHeight = MediaQuery.of(
                                          context,
                                        ).size.height;
                                        final appBarHeight =
                                            kToolbarHeight +
                                            MediaQuery.of(context).padding.top;

                                        final modalHeight =
                                            screenHeight - appBarHeight;

                                        return Container(
                                          height: modalHeight,
                                          child: Column(
                                            children: [
                                              // Search Bar
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                color: FlavorColors
                                                    .current
                                                    .background,
                                                child: TextField(
                                                  controller: searchController,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Search by name, code, or category...',
                                                    prefixIcon: const Icon(
                                                      Icons.search,
                                                      color: Colors.grey,
                                                    ),
                                                    suffixIcon:
                                                        searchController
                                                            .text
                                                            .isNotEmpty
                                                        ? IconButton(
                                                            icon: const Icon(
                                                              Icons.clear,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                            onPressed: () {
                                                              searchController
                                                                  .clear();
                                                              inventoryController
                                                                  .searchInventory(
                                                                    '',
                                                                  );
                                                            },
                                                          )
                                                        : null,
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: FlavorColors
                                                            .current
                                                            .light,
                                                      ),
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              BorderSide(
                                                                color:
                                                                    FlavorColors
                                                                        .current
                                                                        .light,
                                                              ),
                                                        ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide: BorderSide(
                                                            color: FlavorColors
                                                                .current
                                                                .primaryDark,
                                                            width: 2,
                                                          ),
                                                        ),
                                                    filled: true,
                                                    fillColor: FlavorColors
                                                        .current
                                                        .surface,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 12,
                                                        ),
                                                  ),
                                                ),
                                              ),

                                              const Divider(height: 1),

                                              // Items List
                                              Expanded(
                                                child: Obx(() {
                                                  if (inventoryController
                                                      .isLoadingInventory
                                                      .value) {
                                                    return const Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    );
                                                  }

                                                  if (inventoryController
                                                      .filteredItems
                                                      .isEmpty) {
                                                    return Center(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .inventory_2_outlined,
                                                            size: 80,
                                                            color: Colors
                                                                .grey[400],
                                                          ),
                                                          const SizedBox(
                                                            height: 16,
                                                          ),
                                                          Text(
                                                            searchController
                                                                    .text
                                                                    .isNotEmpty
                                                                ? 'No items found for "${searchController.text}"'
                                                                : 'No items available',
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }

                                                  return NotificationListener<
                                                    ScrollNotification
                                                  >(
                                                    onNotification:
                                                        (
                                                          ScrollNotification
                                                          scrollInfo,
                                                        ) {
                                                          if (scrollInfo
                                                                  .metrics
                                                                  .pixels >=
                                                              scrollInfo
                                                                      .metrics
                                                                      .maxScrollExtent *
                                                                  0.8) {
                                                            if (inventoryController
                                                                    .hasMoreItems
                                                                    .value &&
                                                                !inventoryController
                                                                    .isLoadingInventory
                                                                    .value) {
                                                              inventoryController
                                                                  .loadMoreInventory();
                                                            }
                                                          }
                                                          return false;
                                                        },
                                                    child: ListView.builder(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      itemCount:
                                                          inventoryController
                                                              .filteredItems
                                                              .length +
                                                          (inventoryController
                                                                  .isLoadingInventory
                                                                  .value
                                                              ? 1
                                                              : 0),
                                                      itemBuilder: (context, index) {
                                                        if (index >=
                                                            inventoryController
                                                                .filteredItems
                                                                .length) {
                                                          return const Center(
                                                            child: Padding(
                                                              padding:
                                                                  EdgeInsets.all(
                                                                    8.0,
                                                                  ),
                                                              child:
                                                                  CircularProgressIndicator(),
                                                            ),
                                                          );
                                                        }
                                                        final item =
                                                            inventoryController
                                                                .filteredItems[index];
                                                        return _buildItemCard(
                                                          item,
                                                        );
                                                      },
                                                    ),
                                                  );
                                                }),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: FlavorColors.current.onPrimary,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Items"),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: FlavorColors.current.onPrimary,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Close"),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
