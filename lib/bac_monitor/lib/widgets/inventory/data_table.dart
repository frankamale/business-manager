import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../additions/colors.dart';
import '../../models/inventory_data.dart';
import 'item_details_dialog.dart';

class InventoryDataTable extends StatelessWidget {
  final List<InventoryItem> items;
  final bool isServicesView;

  const InventoryDataTable({super.key, required this.items, required this.isServicesView});

  NumberFormat get currencyFormatter =>
      NumberFormat.currency(locale: 'en_UG', symbol: 'UGX ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return DataTable(
      headingRowHeight: 48,
      dataRowHeight: 80,
      headingRowColor: MaterialStateProperty.all(
        PrimaryColors.lightBlue.withOpacity(0.5),
      ),
      headingTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      dataRowColor: MaterialStateProperty.all(PrimaryColors.lightBlue),
      dataTextStyle: const TextStyle(color: Colors.white70),
      columnSpacing: 24,
      horizontalMargin: 12,
      dividerThickness: 0,
      showCheckboxColumn: false,
      columns: isServicesView
          ? const [
              DataColumn(label: Text('SERVICE DETAILS')),
              DataColumn(label: Text('PRICE')),
            ]
          : const [
              DataColumn(label: Text('PRODUCT DETAILS')),
              DataColumn(label: Text('PRICE/QTY')),
            ],
      rows: items.map((item) => _createDataRow(context, item)).toList(),
    );
  }

  DataRow _createDataRow(BuildContext context, InventoryItem item) {
    return DataRow(
      onSelectChanged: (_) => _showItemDetailsDialog(context, item),
      cells: isServicesView
          ? [
              DataCell(_buildServiceCell(item)),
              DataCell(_buildPriceCell(item)),
            ]
          : [
              DataCell(_buildProductCell(item)),
              DataCell(_buildQuantityCell(item)),
            ],
    );
  }

  Widget _buildProductCell(InventoryItem item) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_UG',
      symbol: 'UGX ',
      decimalDigits: 0,
    );

    final bool isService =
        item.category.toLowerCase() == 'service' ||
        item.servicePoint.toLowerCase().contains('service');
    final bool isPharmacy = item.servicePoint.toLowerCase().contains(
      'pharmacy',
    );

    Widget conditionalWidget;
    if (isPharmacy && item.expiryDate != null && item.expiryDate!.isNotEmpty) {
      conditionalWidget = Text(
        'exp: ${item.expiryDate}',
        style: const TextStyle(color: Colors.white70, fontSize: 10),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    } else if (isService) {
      conditionalWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.category,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "cost: ${currencyFormatter.format(item.costPrice)}",
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "supplier: ${item.servicePoint}",
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else {
      conditionalWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "cost price: ${currencyFormatter.format(item.costPrice)}",
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "Supplier: ${item.servicePoint}",
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Row(
      children: [
        CircleAvatar(child: _buildStockStatusIndicator(item), radius: 3),
        const SizedBox(width: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.0),
          child: item.imageUrl != null && item.imageUrl!.isNotEmpty
              ? Image.network(
                  item.imageUrl!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _fallbackImage(),
                )
              : _fallbackImage(),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: ClipRect(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                conditionalWidget,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityCell(InventoryItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'SP: ${currencyFormatter.format(item.sellingPrice)}',
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 1),
        item.expiryDate != null && item.expiryDate!.isNotEmpty
            ? Text(
                'exp: ${item.expiryDate}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QTY: ${item.quantityOnHand}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'sup. on : ${DateFormat('dd/MM/yyyy').format(item.lastUpdated)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildServiceCell(InventoryItem item) {
    return Row(
      children: [
        const SizedBox(width: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.0),
          child: item.imageUrl != null && item.imageUrl!.isNotEmpty
              ? Image.network(
                  item.imageUrl!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _fallbackImage(),
                )
              : _fallbackImage(),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: ClipRect(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  'Category: ${item.category}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCell(InventoryItem item) {
    return Text(
      currencyFormatter.format(item.sellingPrice),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStockStatusIndicator(InventoryItem item) {
    final bool isLowStock = item.quantityOnHand < 40;
    final bool isOverstocked = item.quantityOnHand > 100;

    Color color;

    if (isLowStock) {
      color = Colors.red;
    } else if (isOverstocked) {
      color = Colors.greenAccent;
    } else {
      color = Colors.yellowAccent;
    }

    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: 32,
      height: 32,
      color: Colors.grey.shade700,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 16,
        color: Colors.grey,
      ),
    );
  }

  void _showItemDetailsDialog(BuildContext context, InventoryItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) => ItemDetailsDialog(item: item),
    );
  }
}
