import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/stock_take_controller.dart';
import '../models/inventory_item.dart';
import '../models/service_point.dart';
import '../models/stock_take.dart';
import '../../flavors/flavor_colors.dart';

/// Form to record the stock count for a single, already-selected product.
/// The item is chosen on the previous screen and shown as the page title.
///
/// Pops with `true` when the user chose "Save & New" (so the caller can
/// re-open the item picker for the next product), otherwise `false`.
class StockTakeForm extends StatefulWidget {
  final ServicePoint? servicePoint;
  final InventoryItem item;

  const StockTakeForm({
    super.key,
    required this.item,
    this.servicePoint,
  });

  @override
  State<StockTakeForm> createState() => _StockTakeFormState();
}

class _StockTakeFormState extends State<StockTakeForm> {
  final _formKey = GlobalKey<FormState>();
  final StockTakeController _stockTakeController = Get.find();

  final _packagingController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _amountController = TextEditingController();
  final _markupController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _batchController = TextEditingController();

  final _quantityFocus = FocusNode();

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
    _applyItem(widget.item);
  }

  @override
  void dispose() {
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

  void _applyItem(InventoryItem item) {
    _packagingController.text = item.packaging;
    _costPriceController.text =
        (item.costprice ?? 0) > 0 ? item.costprice!.toStringAsFixed(0) : '';
    _sellingPriceController.text =
        item.price > 0 ? item.price.toStringAsFixed(0) : '';
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

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 80),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  StockTake _buildStockTake() {
    return StockTake(
      id: 'st_${DateTime.now().microsecondsSinceEpoch}',
      inventoryId: widget.item.id,
      itemName: widget.item.name,
      code: widget.item.code,
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
    if (!_formKey.currentState!.validate()) return;
    _recalculateAmount();
    try {
      await _stockTakeController.addStockTake(
        _buildStockTake(),
        servicePointId: widget.servicePoint?.id,
      );
      Get.snackbar(
        'Saved',
        '${widget.item.name} recorded',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
        duration: const Duration(seconds: 1),
      );
      // newAfter => signal caller to re-open the item picker for the next item.
      Get.back(result: newAfter);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: FlavorColors.current.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Item summary header
              if (widget.item.code.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Code: ${widget.item.code}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),

              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    // 1. Packaging
                    _row(
                      'Packaging',
                      TextFormField(
                        controller: _packagingController,
                        decoration: _cellDecoration(hint: 'Packaging'),
                      ),
                    ),
                    // 2. Quantity (required)
                    _row(
                      'Quantity *',
                      TextFormField(
                        controller: _quantityController,
                        focusNode: _quantityFocus,
                        autofocus: true,
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
                            return 'Required';
                          }
                          return null;
                        },
                        decoration: _cellDecoration(hint: 'Quantity at hand'),
                      ),
                    ),
                    // 3. Cost price
                    _row(
                      'Cost Price',
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
                        decoration: _cellDecoration(hint: 'Cost price'),
                      ),
                    ),
                    // 4. Amount (calculated)
                    _row(
                      'Amount',
                      TextFormField(
                        controller: _amountController,
                        readOnly: true,
                        decoration: _cellDecoration(hint: '0').copyWith(
                          fillColor: Colors.grey.shade100,
                          filled: true,
                        ),
                      ),
                    ),
                    // 5. Markup
                    _row(
                      'Markup (%)',
                      TextFormField(
                        controller: _markupController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: (_) => _recalculateSellingFromMarkup(),
                        decoration: _cellDecoration(hint: 'Markup %'),
                      ),
                    ),
                    // 6. Selling price
                    _row(
                      'Selling Price',
                      TextFormField(
                        controller: _sellingPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: (_) => _recalculateMarkupFromSelling(),
                        decoration: _cellDecoration(hint: 'Selling price'),
                      ),
                    ),
                    // 7. Batch number
                    _row(
                      'Batch Number',
                      TextFormField(
                        controller: _batchController,
                        decoration: _cellDecoration(hint: 'Batch number'),
                      ),
                    ),
                    // 8. Expiry date
                    _row(
                      'Expiry Date',
                      InkWell(
                        onTap: _pickExpiryDate,
                        child: InputDecorator(
                          decoration: _cellDecoration(hint: ''),
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
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Action buttons: Cancel, Save, Save & New
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(result: false),
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

  /// One table row: label on the left, input on the right.
  Widget _row(String label, Widget field, {bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 120,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              width: 1,
              color: Colors.grey.shade300,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: field,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Borderless input used inside the table cells.
  InputDecoration _cellDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    );
  }
}
