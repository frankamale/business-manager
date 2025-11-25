import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'inventory_items_screen.dart';
import 'payment_screen.dart';
import '../models/inventory_item.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/customer_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/users.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
   final NumberFormat _numberFormat = NumberFormat('#,###', 'en_US');
   final InventoryController inventoryController = Get.find();
   final CustomerController customerController = Get.find();
   final AuthController authController = Get.find();
   String selectedCategory = 'All';
   final TextEditingController searchController = TextEditingController();
   List<User> salespeople = [];
   String? selectedSalespersonId;

   String formatMoney(double amount) {
     return _numberFormat.format(amount.toInt());
   }

   String? selectedCustomerId;
   final TextEditingController refController = TextEditingController();
   final TextEditingController notesController = TextEditingController();

   // Selected items
   final List<Map<String, dynamic>> selectedItems = [];

  double get totalAmount {
    return selectedItems.fold(0, (sum, item) => sum + (item['amount'] as num));
  }

  void _addItemToCart(InventoryItem item) {
    setState(() {
      // Check if item already exists in cart
      final existingItemIndex = selectedItems.indexWhere(
        (cartItem) => cartItem['id'] == item.id,
      );

      if (existingItemIndex != -1) {
        // Item exists, increase quantity
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
        });
      }
    });

    // Show success message
    Get.snackbar(
      'Item Added',
      '${item.name} added to cart',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      backgroundColor: Colors.green[100],
      colorText: Colors.green[900],
      margin: const EdgeInsets.all(8),
    );
  }

  void _removeItemFromCart(int index) {
    setState(() {
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

  void _onSearchChanged() {
    inventoryController.searchInventory(searchController.text);
  }

  Future<void> _loadSalespeople() async {
    salespeople = await authController.getSalespeople();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // Set default customer to "Cash Customer"
    final cashCustomer = customerController.getCustomerByFullnames("Cash Customer ");
    if (cashCustomer != null) {
      selectedCustomerId = cashCustomer.id;
    }
    // Set default salesperson to logged-in user
    final currentUser = authController.currentUser.value;
    if (currentUser != null && currentUser.salespersonid.isNotEmpty) {
      selectedSalespersonId = currentUser.salespersonid;
    }
    _loadSalespeople();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    refController.dispose();
    notesController.dispose();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  Future<void> _navigateToPayment() async {
    if (selectedItems.isEmpty) {
      Get.snackbar('Error', 'No items in cart',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900]);
      return;
    }

    final result = await Get.to(
      () => PaymentScreen(
        cartItems: selectedItems,
        customer: selectedCustomerId,
        reference: refController.text,
        notes: notesController.text,
        salespersonId: selectedSalespersonId,
      ),
    );

    // If payment was successful, clear the cart
    if (result == true) {
      setState(() {
        selectedItems.clear();
        refController.clear();
        notesController.clear();
        final cashCustomer = customerController.getCustomerByFullnames("Cash Customer ");
        selectedCustomerId = cashCustomer?.id;
        // Reset salesperson to logged-in user
        final currentUser = authController.currentUser.value;
        if (currentUser != null && currentUser.salespersonid.isNotEmpty) {
          selectedSalespersonId = currentUser.salespersonid;
        }
      });
    }
  }

  Widget _buildItemCard(InventoryItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {
          _addItemToCart(item);
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
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: Colors.blue[700],
                  size: 28,
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
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.code,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
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
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.packaging} • ${item.measurmentunit}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
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
                      color: Colors.green[700],
                    ),
                  ),
                  if (item.costprice != null && item.costprice! > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Cost: ${item.costprice!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "POS Sale",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
          child: Column(
            children: [
              // Total Display
              Container(
                width: double.infinity,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "UGX ${formatMoney(totalAmount)}",
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Customer Dropdown
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text(
                      "Client:",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Obx(() {
                      if (customerController.isLoadingCustomers.value) {
                        return const SizedBox(
                          height: 36,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
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
                        items: customerController.customers.map((customer) {
                          return DropdownMenuItem<String>(
                            value: customer.id,
                            child: Text(customer.fullnames),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedCustomerId = newValue;
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Salesperson Dropdown
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text(
                      "Salesperson:",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedSalespersonId,
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
                      items: salespeople.map((user) {
                        return DropdownMenuItem<String>(
                          value: user.salespersonid,
                          child: Text(user.staff),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedSalespersonId = newValue;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Reference Field
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text(
                      "Ref:",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: refController,
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
              const SizedBox(height: 8),

              // Notes Field
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text(
                      "Notes:",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: notesController,
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
              const SizedBox(height: 8),

              // Selected Items Container
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
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
                          color: Colors.blue.shade50,
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
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              child: Text(
                                "Qty",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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
                                  fontSize: 13,
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
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
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
                                                      keyboardType: TextInputType.number,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      decoration: InputDecoration(
                                                        isDense: true,
                                                        contentPadding: const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                          vertical: 2,
                                                        ),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(4),
                                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                                        ),
                                                        enabledBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(4),
                                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                                        ),
                                                      ),
                                                      controller: TextEditingController(
                                                        text: item['price'].toStringAsFixed(0),
                                                      ),
                                                      onChanged: (value) {
                                                        final newPrice = double.tryParse(value) ?? item['price'];
                                                        _updatePrice(index, newPrice);
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
                                              onTap: () => _updateQuantity(
                                                index,
                                                item['quantity'] - 1,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red[50],
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Icon(
                                                  Icons.remove,
                                                  size: 16,
                                                  color: Colors.red[700],
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              child: Text(
                                                "${item['quantity']}",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => _updateQuantity(
                                                index,
                                                item['quantity'] + 1,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.green[50],
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Icon(
                                                  Icons.add,
                                                  size: 16,
                                                  color: Colors.green[700],
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
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _navigateToPayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("PAY"),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedItems.clear();
                          refController.clear();
                          notesController.clear();
                          final cashCustomer = customerController.getCustomerByFullnames("Cash Customer ");
                          selectedCustomerId = cashCustomer?.id;
                          // Reset salesperson to logged-in user
                          final currentUser = authController.currentUser.value;
                          if (currentUser != null && currentUser.salespersonid.isNotEmpty) {
                            selectedSalespersonId = currentUser.salespersonid;
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("New"),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.grey[100],
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (BuildContext context) {
                            // Calculate height to leave space for the price display section
                            final screenHeight = MediaQuery.of(context).size.height;
                            final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
                            final priceDisplayHeight = 100.0; // Height of price display container
                            final spacing = 16.0; // Additional spacing
                            final modalHeight = screenHeight - appBarHeight - priceDisplayHeight - spacing;

                            return Container(
                              height: modalHeight,
                              child: Column(
                                children: [
                                  // Search Bar
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    color: Colors.white,
                                    child: TextField(
                                      controller: searchController,
                                      decoration: InputDecoration(
                                        hintText: 'Search by name, code, or category...',
                                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                        suffixIcon: searchController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, color: Colors.grey),
                                                onPressed: () {
                                                  searchController.clear();
                                                  inventoryController.searchInventory('');
                                                },
                                              )
                                            : null,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Category Filter
                                  Obx(() {
                                    if (inventoryController.categories.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    return Container(
                                      height: 50,
                                      color: Colors.white,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        itemCount: inventoryController.categories.length + 1,
                                        itemBuilder: (context, index) {
                                          final category = index == 0 ? 'All' : inventoryController.categories[index - 1];
                                          final isSelected = selectedCategory == category;

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                            child: ChoiceChip(
                                              label: Text(category),
                                              selected: isSelected,
                                              onSelected: (selected) {
                                                setState(() {
                                                  selectedCategory = category;
                                                });
                                                inventoryController.filterByCategory(category);
                                                searchController.clear();
                                              },
                                              selectedColor: Colors.blue[700],
                                              labelStyle: TextStyle(
                                                color: isSelected ? Colors.white : Colors.black87,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              ),
                                              backgroundColor: Colors.grey[200],
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }),

                                  const Divider(height: 1),

                                  // Items List
                                  Expanded(
                                    child: Obx(() {
                                      if (inventoryController.isLoadingInventory.value) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }

                                      if (inventoryController.filteredItems.isEmpty) {
                                        return Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.inventory_2_outlined,
                                                size: 80,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                searchController.text.isNotEmpty
                                                    ? 'No items found for "${searchController.text}"'
                                                    : 'No items available',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      return ListView.builder(
                                        padding: const EdgeInsets.all(8),
                                        itemCount: inventoryController.filteredItems.length,
                                        itemBuilder: (context, index) {
                                          final item = inventoryController.filteredItems[index];
                                          return _buildItemCard(item);
                                        },
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
                        backgroundColor: Colors.yellow[700],
                        foregroundColor: Colors.white,
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
                        backgroundColor: Colors.red[700],
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
