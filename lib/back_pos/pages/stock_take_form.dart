import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/stock_take_controller.dart';
import '../models/inventory_item.dart';
import '../models/service_point.dart';
import '../models/stock_take.dart';
import '../../flavors/flavor_colors.dart';

/// Form to record the stock count for a single product.
///
/// Use [item] when adding a new stock take (item chosen on the previous
/// screen), or [existing] to edit a previously saved record (prefilled).
///
/// Pops with `true` when the user chose "Save & New" (so the caller can
/// re-open the item picker for the next product), otherwise `false`.
class StockTakeForm extends StatefulWidget {
  final ServicePoint? servicePoint;
  final InventoryItem? item;
  final StockTake? existing;

  /// Parent stock take this item belongs to (required when adding a new item).
  final String? stockTakeId;

  const StockTakeForm({
    super.key,
    this.item,
    this.existing,
    this.servicePoint,
    this.stockTakeId,
  }) : assert(item != null || existing != null,
            'Provide either an item (new) or an existing stock take (edit)');

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

  bool get _isEdit => widget.existing != null;
  String get _name => widget.existing?.itemName ?? widget.item!.name;
  String get _code => widget.existing?.code ?? widget.item!.code;
  String get _inventoryId => widget.existing?.inventoryId ?? widget.item!.id;

  @override
  void initState() {
    super.initState();
    _quantityFocus.addListener(() {
      if (!_quantityFocus.hasFocus) _recalculateAmount();
    });
    if (widget.existing != null) {
      _applyExisting(widget.existing!);
    } else {
      _applyItem(widget.item!);
    }
  }

  String _formatNum(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  void _applyExisting(StockTake t) {
    _packagingController.text = t.packaging;
    _quantityController.text = t.quantity != 0 ? _formatNum(t.quantity) : '';
    _costPriceController.text =
        t.costPrice != 0 ? t.costPrice.toStringAsFixed(0) : '';
    _markupController.text = t.markup != 0 ? t.markup.toStringAsFixed(1) : '';
    _sellingPriceController.text =
        t.sellingPrice != 0 ? t.sellingPrice.toStringAsFixed(0) : '';
    _batchController.text = t.batchNumber;
    _expiryDate = t.expiryDate ?? _defaultExpiry;
    _recalculateAmount();
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
      id: widget.existing?.id ?? 'st_${DateTime.now().microsecondsSinceEpoch}',
      stockTakeId: widget.existing?.stockTakeId ?? widget.stockTakeId ?? '',
      inventoryId: _inventoryId,
      itemName: _name,
      code: _code,
      packaging: _packagingController.text.trim(),
      quantity: _quantity,
      costPrice: _costPrice,
      amount: _quantity * _costPrice,
      markup: _markup,
      sellingPrice: _sellingPrice,
      batchNumber: _batchController.text.trim(),
      expiryDate: _expiryDate,
      servicePointId:
          widget.servicePoint?.id ?? widget.existing?.servicePointId,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      uploadStatus: widget.existing?.uploadStatus ?? 'pending',
    );
  }

  bool _isSaving = false;

  Future<void> _save({required bool newAfter}) async {
    // Guard against rapid double taps creating duplicate records.
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    _recalculateAmount();

    setState(() => _isSaving = true);
    try {
      await _stockTakeController.saveItem(_buildStockTake());
      if (!mounted) return;
      // Pop the form route explicitly (Navigator, not Get.back, which can
      // close the snackbar overlay instead of the page). newAfter is returned
      // to the caller so it can re-open the item picker for the next item.
      Navigator.of(context).pop(newAfter);
      Get.snackbar(
        'Saved',
        '$_name recorded',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
        duration: const Duration(seconds: 1),
      );
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
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
          _isEdit ? 'Edit • $_name' : _name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: FlavorColors.current.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
              // Item summary header card
              _itemHeaderCard(),
              const SizedBox(height: 16),

              Column(
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
                        decoration: _cellDecoration(hint: '0'),
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
                        decoration: _cellDecoration(hint: '0'),
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
                        decoration: _cellDecoration(hint: '0.0 '),
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
                        decoration: _cellDecoration(hint: '0'),
                      ),
                    ),
                    // 7. Batch number
                    _row(
                      'Batch Number',
                      TextFormField(
                        controller: _batchController,
                        decoration: _cellDecoration(hint: '#'),
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
                  ],
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlavorColors.current.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FlavorColors.current.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: FlavorColors.current.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: FlavorColors.current.primaryDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_code.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Code: $_code',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : () => Navigator.of(context).pop(false),
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
                onPressed: _isSaving ? null : () => _save(newAfter: false),
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
            if (!_isEdit) ...[
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _save(newAfter: true),
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
          ],
        ),
      ),
    );
  }

  /// One form row: label on the left, input field on the right.
  Widget _row(String label, Widget field, {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: field),
        ],
      ),
    );
  }

  /// Input styling that clearly reads as an editable field.
  InputDecoration _cellDecoration({required String hint}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade400),
    );
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: FlavorColors.current.primary,
          width: 1.6,
        ),
      ),
    );
  }
}
