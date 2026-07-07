import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/inventory_controller.dart';
import '../models/inventory_item.dart';
import '../widgets/barcode_scanner.dart';
import '../../flavors/flavor_colors.dart';

/// First step of adding a stock take: search or scan for the item.
/// Pops with the chosen [InventoryItem], or null if cancelled.
class StockTakeItemPicker extends StatefulWidget {
  const StockTakeItemPicker({super.key});

  @override
  State<StockTakeItemPicker> createState() => _StockTakeItemPickerState();
}

class _StockTakeItemPickerState extends State<StockTakeItemPicker> {
  final InventoryController _inventoryController = Get.find();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inventoryController.clearSearch();
    // Make sure there's something to show before the user starts searching.
    if (_inventoryController.inventoryItems.isEmpty) {
      _inventoryController.loadInventoryFromCache();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final result = await Get.to(() => const BarcodeScannerPage());
    if (result is InventoryItem) {
      Get.back(result: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Item'),
        backgroundColor: FlavorColors.current.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Scan barcode',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scan,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _inventoryController.searchInventory,
                decoration: InputDecoration(
                  hintText: 'Search by name, code, or category...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scan,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Obx(() {
                if (_inventoryController.isLoadingInventory.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = _inventoryController.filteredItems;
                if (items.isEmpty) {
                  return const Center(child: Text('No items found'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.code.isNotEmpty ? "${item.code} • " : ""}'
                        '${item.packaging}',
                      ),
                      trailing: Text('UGX ${item.price.toStringAsFixed(0)}'),
                      onTap: () => Get.back(result: item),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
