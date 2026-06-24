import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/stock_take_controller.dart';
import '../models/inventory_item.dart';
import '../models/service_point.dart';
import '../models/stock_take.dart';
import '../widgets/barcode_scanner.dart';
import '../../flavors/flavor_colors.dart';

/// Form to record the stock count for a single product. Supports
/// "Save" (persist and close) and "Save & New" (persist and reset for the
/// next product).
class StockTakeForm extends StatefulWidget {
  final ServicePoint? servicePoint;

  const StockTakeForm({super.key, this.servicePoint});

  @override
  State<StockTakeForm> createState() => _StockTakeFormState();
}

class _StockTakeFormState extends State<StockTakeForm> {
  final _formKey = GlobalKey<FormState>();
  final InventoryController _inventoryController = Get.find();
  final StockTakeController _stockTakeController = Get.find();

  final _itemController = TextEditingController();
  final _packagingController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _amountController = TextEditingController();
  final _markupController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _batchController = TextEditingController();

  final _quantityFocus = FocusNode();

  InventoryItem? _selectedItem;

  /// Default expiry used when none is provided (effectively "no expiry").
  static final DateTime _defaultExpiry = DateTime(2099, 12, 31);
  DateTime? _expiryDate = _defaultExpiry;

  final NumberFormat _money = NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    _quantityFocus.addListener(() {
      if (!_quantityFocus.hasFocus) _recalculateAmount();
    });
  }

  @override
  void dispose() {
    _itemController.dispose();
    _packagingController.dispose();
    _quantityController.dispose();
    _costPriceController.dispose();
    _amountController.dispose();
    _markupController.dispose();
    _sellingPriceController.dispose();
    _batchController.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }

  double get _quantity => double.tryParse(_quantityController.text.trim()) ?? 0;
  double get _costPrice => double.tryParse(_costPriceController.text.trim()) ?? 0;
  double get _markup => double.tryParse(_markupController.text.trim()) ?? 0;
  double get _sellingPrice =>
      double.tryParse(_sellingPriceController.text.trim()) ?? 0;

  void _applySelectedItem(InventoryItem item) {
    setState(() {
      _selectedItem = item;
      _itemController.text = item.name;
      _packagingController.text = item.packaging;
      _costPriceController.text = (item.costprice ?? 0) > 0
          ? (item.costprice!).toStringAsFixed(0)
          : '';
      _sellingPriceController.text = item.price > 0
          ? item.price.toStringAsFixed(0)
          : '';
    });
    _recalculateMarkupFromSelling();
    _recalculateAmount();
  }

  void _recalculateAmount() {
    final amount = _quantity * _costPrice;
    _amountController.text = amount > 0 ? _money.format(amount) : '';
    setState(() {});
  }

  /// Selling price = cost * (1 + markup%).
  void _recalculateSellingFromMarkup() {
    if (_costPrice <= 0) return;
    final selling = _costPrice * (1 + _markup / 100);
    _sellingPriceController.text = selling.toStringAsFixed(0);
    setState(() {});
  }

  /// Markup% = (selling - cost) / cost * 100.
  void _recalculateMarkupFromSelling() {
    if (_costPrice <= 0) {
      _markupController.text = '';
      return;
    }
    final markup = ((_sellingPrice - _costPrice) / _costPrice) * 100;
    _markupController.text = markup.toStringAsFixed(1);
    setState(() {});
  }

  Future<void> _scanBarcode() async {
    final result = await Get.to(() => const BarcodeScannerPage());
    if (result is InventoryItem) {
      _applySelectedItem(result);
    }
  }

  Future<void> _pickItem() async {
    final searchController = TextEditingController();
    _inventoryController.clearSearch();

    final selected = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlavorColors.current.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.85;
        return SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  onChanged: _inventoryController.searchInventory,
                  decoration: InputDecoration(
                    hintText: 'Search by name, code, or category...',
                    prefixIcon: const Icon(Icons.search),
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
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.code.isNotEmpty ? "${item.code} • " : ""}'
                          '${item.packaging}',
                        ),
                        trailing: Text('UGX ${item.price.toStringAsFixed(0)}'),
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );

    _inventoryController.clearSearch();
    if (selected != null) {
      _applySelectedItem(selected);
    }
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  bool _validateAndPrepare() {
    if (_selectedItem == null && _itemController.text.trim().isEmpty) {
      Get.snackbar(
        'Item required',
        'Please select or scan an item first',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return false;
    }
    if (!_formKey.currentState!.validate()) return false;
    _recalculateAmount();
    return true;
  }

  StockTake _buildStockTake() {
    return StockTake(
      id: 'st_${DateTime.now().microsecondsSinceEpoch}',
      inventoryId: _selectedItem?.id ?? '',
      itemName: _itemController.text.trim(),
      code: _selectedItem?.code ?? '',
      packaging: _packagingController.text.trim(),
      quantity: _quantity,
      costPrice: _costPrice,
      amount: _quantity * _costPrice,
      markup: _markup,
      sellingPrice: _sellingPrice,
      batchNumber: _batchController.text.trim(),
      expiryDate: _expiryDate,
      servicePointId: widget.servicePoint?.id,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _save({required bool newAfter}) async {
    if (!_validateAndPrepare()) return;
    try {
      await _stockTakeController.addStockTake(
        _buildStockTake(),
        servicePointId: widget.servicePoint?.id,
      );
      Get.snackbar(
        'Saved',
        '${_itemController.text.trim()} recorded',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
        duration: const Duration(seconds: 1),
      );
      if (newAfter) {
        _resetForm();
      } else {
        Get.back();
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save stock take',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    }
  }

  void _resetForm() {
    setState(() {
      _selectedItem = null;
      _expiryDate = _defaultExpiry;
      _itemController.clear();
      _packagingController.clear();
      _quantityController.clear();
      _costPriceController.clear();
      _amountController.clear();
      _markupController.clear();
      _sellingPriceController.clear();
      _batchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Stock Take'),
        backgroundColor: FlavorColors.current.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Scan barcode',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanBarcode,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Item name / scan
              _label('Item'),
              TextFormField(
                controller: _itemController,
                readOnly: true,
                onTap: _pickItem,
                decoration: _decoration(
                  hint: 'Tap to search or scan an item',
                  prefixIcon: Icons.inventory_2_outlined,
                  suffix: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Packaging
              _label('Packaging'),
              TextFormField(
                controller: _packagingController,
                decoration: _decoration(
                  hint: 'Packaging',
                  prefixIcon: Icons.category_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // 3. Quantity (required)
              _label('Quantity *'),
              TextFormField(
                controller: _quantityController,
                focusNode: _quantityFocus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) => _recalculateAmount(),
                validator: (value) {
                  final v = double.tryParse((value ?? '').trim());
                  if (v == null || v <= 0) {
                    return 'Enter a valid quantity';
                  }
                  return null;
                },
                decoration: _decoration(
                  hint: 'Quantity at hand',
                  prefixIcon: Icons.numbers_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // 4. Cost price
              _label('Cost Price'),
              TextFormField(
                controller: _costPriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) {
                  _recalculateAmount();
                  _recalculateMarkupFromSelling();
                },
                decoration: _decoration(
                  hint: 'Cost price',
                  prefixIcon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // 5. Amount (calculated)
              _label('Amount'),
              TextFormField(
                controller: _amountController,
                readOnly: true,
                decoration: _decoration(
                  hint: '0',
                  prefixIcon: Icons.calculate_outlined,
                ).copyWith(
                  fillColor: Colors.grey.shade100,
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),

              // 6. Markup
              _label('Markup (%)'),
              TextFormField(
                controller: _markupController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) => _recalculateSellingFromMarkup(),
                decoration: _decoration(
                  hint: 'Markup percentage',
                  prefixIcon: Icons.trending_up_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // 7. Selling price
              _label('Selling Price'),
              TextFormField(
                controller: _sellingPriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) => _recalculateMarkupFromSelling(),
                decoration: _decoration(
                  hint: 'Selling price',
                  prefixIcon: Icons.sell_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // 8. Batch number
              _label('Batch Number'),
              TextFormField(
                controller: _batchController,
                decoration: _decoration(
                  hint: 'Batch number',
                  prefixIcon: Icons.tag_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // 9. Expiry date
              _label('Expiry Date'),
              InkWell(
                onTap: _pickExpiryDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: _decoration(
                    hint: '',
                    prefixIcon: Icons.event_outlined,
                  ),
                  child: Text(
                    _expiryDate != null
                        ? DateFormat('dd MMM yyyy').format(_expiryDate!)
                        : 'Select expiry date',
                    style: TextStyle(
                      color: _expiryDate != null
                          ? Colors.black87
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Action buttons: Cancel, Save, Save & New
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _save(newAfter: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlavorColors.current.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _save(newAfter: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save & New',
                        textAlign: TextAlign.center,
                      ),
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      );

  InputDecoration _decoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, size: 20),
      suffixIcon: suffix,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
