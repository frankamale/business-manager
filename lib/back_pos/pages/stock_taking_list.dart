import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/stock_take_controller.dart';
import '../models/service_point.dart';
import '../models/stock_take.dart';
import 'stock_take_form.dart';
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

  @override
  void initState() {
    super.initState();
    _controller.loadStockTakes(servicePointId: widget.servicePoint?.id);
  }

  Future<void> _openForm() async {
    await Get.to(() => StockTakeForm(servicePoint: widget.servicePoint));
    // Refresh in case items were added while the form was open.
    await _controller.loadStockTakes(servicePointId: widget.servicePoint?.id);
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
      await _controller.deleteStockTake(
        take.id,
        servicePointId: widget.servicePoint?.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Taking'),
        backgroundColor: FlavorColors.current.primary,
        foregroundColor: Colors.white,
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
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    take.itemName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  'Qty: ${_money.format(take.quantity)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: FlavorColors.current.primaryDark,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: () => _confirmDelete(take),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                if (take.packaging.isNotEmpty)
                  _meta('Pkg', take.packaging),
                _meta('Cost', _money.format(take.costPrice)),
                _meta('Amount', _money.format(take.amount)),
                _meta('Sell', _money.format(take.sellingPrice)),
                if (take.batchNumber.isNotEmpty)
                  _meta('Batch', take.batchNumber),
                if (take.expiryDate != null)
                  _meta('Exp', DateFormat('dd MMM yyyy').format(take.expiryDate!)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('dd MMM yyyy, HH:mm').format(take.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
