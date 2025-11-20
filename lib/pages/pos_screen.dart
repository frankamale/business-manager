import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'inventory_items_screen.dart';
import '../models/inventory_item.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final List<String> customers = [
    "Walk-in Customer",
    "Customer 1",
    "Customer 2",
    "Customer 3",
    "Customer 4",
    "Customer 5",
  ];

  String? selectedCustomer;
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

  @override
  void initState() {
    super.initState();
    selectedCustomer = customers[0];
  }

  @override
  void dispose() {
    refController.dispose();
    notesController.dispose();
    super.dispose();
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
                  "UGX ${totalAmount.toStringAsFixed(0)}",
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
                    child: DropdownButtonFormField<String>(
                      value: selectedCustomer,
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
                      items: customers.map((String customer) {
                        return DropdownMenuItem<String>(
                          value: customer,
                          child: Text(customer),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedCustomer = newValue;
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
                                              Text(
                                                'UGX ${item['price'].toStringAsFixed(0)} each',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
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
                                            "${item['amount'].toStringAsFixed(0)}",
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
                      onPressed: () {},
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
                          selectedCustomer = customers[0];
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
                      onPressed: () async {
                        final selectedItem = await Get.to(
                          () => InventoryItemsScreen(
                            onItemSelected: _addItemToCart,
                          ),
                        );
                        if (selectedItem != null && selectedItem is InventoryItem) {
                          _addItemToCart(selectedItem);
                        }
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
