import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/stock_take_controller.dart';
import '../models/inventory_item.dart';
import '../models/service_point.dart';
import '../models/stock_take.dart';
import 'stock_take_form.dart';
import 'stock_take_item_picker.dart';
import '../../flavors/flavor_colors.dart';

/// Lists previously recorded stock takes and offers a FAB to add a new one.
class StockTakingList extends StatefulWidget {
  final ServicePoint? servicePoint;

  const StockTakingList({super.key, this.servicePoint});

  @override
  State<StockTakingList> createState() => _StockTakingListState();
}

class _StockTakingListState extends State<StockTakingList> {
  final StockTakeController _controller = Get.put(StockTakeController());
  final NumberFormat _money = NumberFormat('#,##0.##', 'en_US');

  String? get _spId => widget.servicePoint?.id;

  @override
  void initState() {
    super.initState();
    _controller.loadStockTakes(servicePointId: _spId);
  }

  /// Add flow: pick/scan an item first, then fill the form. "Save & New"
  /// loops back to the picker for the next product.
  Future<void> _openForm() async {
    bool again = true;
    while (again && mounted) {
      final item = await Get.to<dynamic>(() => const StockTakeItemPicker());
      if (item is! InventoryItem) break; // cancelled

      final saveAndNew = await Get.to<dynamic>(
        () => StockTakeForm(servicePoint: widget.servicePoint, item: item),
      );
      again = saveAndNew == true;
    }
    await _controller.loadStockTakes(servicePointId: _spId);
  }

  Future<void> _edit(StockTake take) async {
    await Get.to(
      () => StockTakeForm(servicePoint: widget.servicePoint, existing: take),
    );
    await _controller.loadStockTakes(servicePointId: _spId);
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

  Future<void> _upload(StockTake take) => _runWithLoader(
        'Uploading...',
        () => _controller.uploadStockTake(take, servicePointId: _spId),
        successMessage: '${take.itemName} uploaded',
      );

  Future<void> _fiscalise(StockTake take) => _runWithLoader(
        'Fiscalising...',
        () => _controller.fiscaliseStockTake(take, servicePointId: _spId),
        successMessage: '${take.itemName} fiscalised',
      );

  Future<void> _uploadAll() async {
    final pending =
        _controller.stockTakes.where((t) => t.uploadStatus == 'pending').length;
    if (pending == 0) {
      Get.snackbar(
        'Nothing to upload',
        'All stock takes are already uploaded',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: FlavorColors.current.primaryDark,
        colorText: Colors.white,
      );
      return;
    }
    await _runWithLoader(
      'Uploading $pending stock take(s)...',
      () async {
        await _controller.uploadAll(servicePointId: _spId);
      },
      successMessage: '$pending stock take(s) uploaded',
    );
  }

  Future<void> _confirmDelete(StockTake take) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete stock take?'),
        content: Text('Remove the record for "${take.itemName}"?'),
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
      await _controller.deleteStockTake(take.id, servicePointId: _spId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Taking'),
        backgroundColor: FlavorColors.current.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Options',
            onSelected: (value) {
              if (value == 'upload_all') _uploadAll();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'upload_all',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload,
                        size: 20, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    const Text('Upload All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        backgroundColor: FlavorColors.current.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Stock Take'),
      ),
      body: SafeArea(
        child: Obx(() {
          if (_controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          final takes = _controller.stockTakes;
          if (takes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_outlined,
                    size: 72,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No stock takes yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "New Stock Take" to add one',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: takes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _buildTile(takes[index]),
          );
        }),
      ),
    );
  }

  Widget _buildTile(StockTake take) {
    final nameColor = _uploadColor(take.uploadStatus);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Quantity chip (tinted with the upload-status colour)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: nameColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _money.format(take.quantity),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: nameColor,
                    ),
                  ),
                  Text(
                    'QTY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: nameColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Name + code + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    take.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                      color: nameColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Code on its own line so a long code never pushes the
                  // date off-screen.
                  if (take.code.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.qr_code_2,
                            size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            take.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          DateFormat('dd MMM yyyy • HH:mm')
                              .format(take.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Fiscalisation status icon
            _fiscalIcon(take.uploadStatus),
            _buildMenu(take),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(StockTake take) {
    final status = take.uploadStatus;
    final isUploaded = status == 'uploaded' || status == 'fiscalised';
    final isFiscalised = status == 'fiscalised';

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Actions',
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _edit(take);
            break;
          case 'upload':
            _upload(take);
            break;
          case 'fiscalise':
            _fiscalise(take);
            break;
          case 'delete':
            _confirmDelete(take);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20),
              SizedBox(width: 12),
              Text('Edit'),
            ],
          ),
        ),
        if (!isUploaded)
          PopupMenuItem(
            value: 'upload',
            child: Row(
              children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 20, color: Colors.green.shade700),
                const SizedBox(width: 12),
                const Text('Upload'),
              ],
            ),
          ),
        // Fiscalise only appears once a stock take has been uploaded.
        if (isUploaded && !isFiscalised)
          PopupMenuItem(
            value: 'fiscalise',
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 20, color: FlavorColors.current.primaryDark),
                const SizedBox(width: 12),
                const Text('Fiscalise'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
              const SizedBox(width: 12),
              const Text('Delete'),
            ],
          ),
        ),
      ],
    );
  }

  /// Upload status, conveyed through the item-name (and quantity) colour:
  /// orange = pending, red = failed, dark blue = uploaded/fiscalised.
  Color _uploadColor(String status) {
    switch (status) {
      case 'failed':
        return const Color(0xFFD32F2F); // red
      case 'uploaded':
      case 'fiscalised':
        return const Color(0xFF0D47A1); // dark blue
      case 'pending':
      default:
        return const Color(0xFFEF6C00); // orange
    }
  }

  /// Fiscalisation status icon:
  /// check = fiscalised, hourglass = awaiting fiscalisation, "?" = error.
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
        icon = Icons.help_rounded; // question mark
        color = Colors.red;
        tip = 'Fiscalisation error';
        break;
      case 'uploaded':
      case 'pending':
      default:
        icon = Icons.hourglass_bottom_rounded;
        color = Colors.blueGrey;
        tip = 'Awaiting fiscalisation';
    }
    return Tooltip(
      message: tip,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: color.shade700),
      ),
    );
  }
}
