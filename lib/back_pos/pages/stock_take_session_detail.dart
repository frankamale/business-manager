import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/stock_take_controller.dart';
import '../models/inventory_item.dart';
import '../models/service_point.dart';
import '../models/stock_take.dart';
import '../models/stock_take_session.dart';
import 'stock_take_form.dart';
import 'stock_take_item_picker.dart';
import '../../flavors/flavor_colors.dart';

/// Shows a single stock-take session: its header and a table of counted items.
/// Items are added/edited here; upload/fiscalise/delete act on the session.
class StockTakeSessionDetail extends StatefulWidget {
  final ServicePoint? servicePoint;
  final StockTakeSession session;

  const StockTakeSessionDetail({
    super.key,
    required this.session,
    this.servicePoint,
  });

  @override
  State<StockTakeSessionDetail> createState() => _StockTakeSessionDetailState();
}

class _StockTakeSessionDetailState extends State<StockTakeSessionDetail> {
  final StockTakeController _controller = Get.find();
  final NumberFormat _money = NumberFormat('#,##0.##', 'en_US');

  late StockTakeSession _session;

  String? get _spId => widget.servicePoint?.id;
  String get _status => _session.uploadStatus;
  bool get _isLocked =>
      _status == 'uploaded' || _status == 'fiscalised'; // no edits after upload

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _controller.loadSessionItems(_session.id);
  }

  Future<void> _addItemFlow() async {
    bool again = true;
    while (again && mounted) {
      final item = await Get.to<dynamic>(() => const StockTakeItemPicker());
      if (item is! InventoryItem) break;

      final saveAndNew = await Get.to<dynamic>(
        () => StockTakeForm(
          servicePoint: widget.servicePoint,
          item: item,
          stockTakeId: _session.id,
        ),
      );
      again = saveAndNew == true;
    }
    await _controller.loadSessionItems(_session.id);
  }

  Future<void> _editItem(StockTake take) async {
    if (_isLocked) return;
    await Get.to(
      () => StockTakeForm(servicePoint: widget.servicePoint, existing: take),
    );
    await _controller.loadSessionItems(_session.id);
  }

  Future<void> _deleteItem(StockTake take) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove "${take.itemName}" from this stock take?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _controller.deleteItem(take.id, stockTakeId: _session.id);
    }
  }

  Future<void> _runWithLoader(String message, Future<void> Function() task,
      {String? successMessage}) async {
    Get.dialog(
      Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
    try {
      await task();
      if (Get.isDialogOpen ?? false) Get.back();
      if (successMessage != null) {
        Get.snackbar(
          'Success',
          successMessage,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade900,
        );
      }
      if (mounted) Navigator.of(context).pop(); // back to the sessions list
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Error',
        'Operation failed: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    }
  }

  Future<void> _upload() async {
    if (_controller.sessionItems.isEmpty) {
      Get.snackbar('Nothing to upload', 'Add at least one item first',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    await _runWithLoader(
      'Uploading...',
      () => _controller.uploadSession(_session, servicePointId: _spId),
      successMessage: 'Stock take uploaded',
    );
  }

  Future<void> _fiscalise() => _runWithLoader(
        'Fiscalising...',
        () =>
            _controller.fiscaliseSession(_session, servicePointId: _spId),
        successMessage: 'Stock take fiscalised',
      );

  Future<void> _deleteSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete stock take?'),
        content: const Text(
            'This removes the whole session and all its items. This cannot be '
            'undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _controller.deleteSession(_session.id, servicePointId: _spId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: _session.reference);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename stock take'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Reference / name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await _controller.renameSession(
        _session,
        reference: result,
        servicePointId: _spId,
      );
      setState(() {
        _session = _session.copyWith(
          reference: result,
          updatedAt: DateTime.now(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _session.reference.isNotEmpty
        ? _session.reference
        : 'Stock Take';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: FlavorColors.current.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Options',
            onSelected: (value) {
              switch (value) {
                case 'rename':
                  _rename();
                  break;
                case 'upload':
                  _upload();
                  break;
                case 'fiscalise':
                  _fiscalise();
                  break;
                case 'delete':
                  _deleteSession();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(children: [
                  Icon(Icons.drive_file_rename_outline, size: 20),
                  SizedBox(width: 12),
                  Text('Rename'),
                ]),
              ),
              if (!_isLocked)
                PopupMenuItem(
                  value: 'upload',
                  child: Row(children: [
                    Icon(Icons.cloud_upload_outlined,
                        size: 20, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    const Text('Upload'),
                  ]),
                ),
              PopupMenuItem(
                value: 'fiscalise',
                // Only an uploaded (not yet fiscalised) session can be
                // fiscalised; otherwise show it greyed-out.
                enabled: _status == 'uploaded',
                child: Row(children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 20,
                      color: _status == 'uploaded'
                          ? FlavorColors.current.primaryDark
                          : Colors.grey),
                  const SizedBox(width: 12),
                  const Text('Fiscalise'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline,
                      size: 20, color: Colors.red.shade400),
                  const SizedBox(width: 12),
                  const Text('Delete'),
                ]),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _isLocked
          ? null
          : FloatingActionButton.extended(
              onPressed: _addItemFlow,
              backgroundColor: FlavorColors.current.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            const Divider(height: 1),
            Expanded(
              child: Obx(() {
                if (_controller.isLoadingItems.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = _controller.sessionItems;
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list_alt_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('No items counted yet',
                            style: TextStyle(color: Colors.grey.shade600)),
                        if (!_isLocked) ...[
                          const SizedBox(height: 4),
                          Text('Tap "Add Item" to start',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade500)),
                        ],
                      ],
                    ),
                  );
                }
                return _itemsTable(items);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final s = _session;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _fiscalIcon(_status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd MMM yyyy • HH:mm').format(s.createdAt),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _uploadColor(_status),
                  ),
                ),
                const SizedBox(height: 2),
                Obx(() {
                  final count = _controller.sessionItems.length;
                  final total = _controller.sessionItems
                      .fold<double>(0, (sum, t) => sum + t.amount);
                  return Text(
                    '$count item(s)  •  Total ${_money.format(total)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  );
                }),
              ],
            ),
          ),
          _statusChip(_status),
        ],
      ),
    );
  }

  Widget _itemsTable(List<StockTake> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStatePropertyAll(
            FlavorColors.current.primary.withValues(alpha: 0.06),
          ),
          columnSpacing: 22,
          columns: const [
            DataColumn(label: Text('Item')),
            DataColumn(label: Text('Pkg')),
            DataColumn(label: Text('Qty'), numeric: true),
            DataColumn(label: Text('Cost'), numeric: true),
            DataColumn(label: Text('Amount'), numeric: true),
            DataColumn(label: Text('Sell'), numeric: true),
            DataColumn(label: Text('')),
          ],
          rows: items.map((t) {
            return DataRow(
              onSelectChanged: _isLocked ? null : (_) => _editItem(t),
              cells: [
                DataCell(SizedBox(
                  width: 140,
                  child: Text(t.itemName, overflow: TextOverflow.ellipsis),
                )),
                DataCell(Text(t.packaging)),
                DataCell(Text(_money.format(t.quantity))),
                DataCell(Text(_money.format(t.costPrice))),
                DataCell(Text(_money.format(t.amount))),
                DataCell(Text(_money.format(t.sellingPrice))),
                DataCell(
                  _isLocked
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 20, color: Colors.red.shade400),
                          onPressed: () => _deleteItem(t),
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ---- status visuals (shared style with the sessions list) ----

  Color _uploadColor(String status) {
    switch (status) {
      case 'failed':
        return const Color(0xFFD32F2F);
      case 'uploaded':
      case 'fiscalised':
        return const Color(0xFF0D47A1);
      default:
        return const Color(0xFFEF6C00);
    }
  }

  Widget _statusChip(String status) {
    final color = _uploadColor(status);
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _fiscalIcon(String status) {
    late final IconData icon;
    late final MaterialColor color;
    late final String tip;
    switch (status) {
      case 'fiscalised':
        icon = Icons.check_circle_rounded;
        color = Colors.green;
        tip = 'Fiscalised';
        break;
      case 'failed':
        icon = Icons.help_rounded;
        color = Colors.red;
        tip = 'Fiscalisation error';
        break;
      default:
        icon = Icons.hourglass_bottom_rounded;
        color = Colors.blueGrey;
        tip = 'Awaiting fiscalisation';
    }
    return Tooltip(
      message: tip,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color.shade700),
      ),
    );
  }
}
