import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import '../../additions/colors.dart';
import '../../models/inventory_data.dart';
import 'item_details_dialog.dart';

class InventoryDataTable extends StatelessWidget {
  final List<MonitorInventoryItem> items;
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
        AppColors.getSurfaceColor(context),
      ),
      headingTextStyle: TextStyle(
        color: AppColors.getTextPrimaryColor(context),
        fontWeight: FontWeight.bold,
      ),
      dataRowColor: MaterialStateProperty.all(
        AppColors.getCardColor(context),
      ),
      dataTextStyle: TextStyle(
        color: AppColors.getTextSecondaryColor(context),
      ),
      columnSpacing: 24,
      horizontalMargin: 12,
      dividerThickness: 0,
      showCheckboxColumn: false,
      columns: isServicesView
          ? [
              DataColumn(label: Text('SERVICE DETAILS', style: TextStyle(color: AppColors.getTextPrimaryColor(context)))),
              DataColumn(label: Text('PRICE', style: TextStyle(color: AppColors.getTextPrimaryColor(context)))),
            ]
          : [
              DataColumn(label: Text('PRODUCT DETAILS', style: TextStyle(color: AppColors.getTextPrimaryColor(context)))),
              DataColumn(label: Text('PRICE/QTY', style: TextStyle(color: AppColors.getTextPrimaryColor(context)))),
            ],
      rows: items.map((item) => _createDataRow(context, item)).toList(),
    );
  }

  DataRow _createDataRow(BuildContext context, MonitorInventoryItem item) {
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

  Widget _buildProductCell(MonitorInventoryItem item) {
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
        style: TextStyle(color: AppColors.getTextSecondaryColor(context as BuildContext), fontSize: 10),
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
            style: TextStyle(color: AppColors.getTextHintColor(context as BuildContext), fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "cost: ${currencyFormatter.format(item.costPrice)}",
            style: TextStyle(color: AppColors.getTextHintColor(context as BuildContext), fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "supplier: ${item.servicePoint}",
            style: TextStyle(color: AppColors.getTextHintColor(context as BuildContext), fontSize: 10),
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
            style: TextStyle(color: AppColors.getTextHintColor(context as BuildContext), fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "Supplier: ${item.servicePoint}",
            style: TextStyle(color: AppColors.getTextHintColor(context as BuildContext), fontSize: 10),
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
                  style: TextStyle(
                    color: AppColors.getTextPrimaryColor(context as BuildContext),
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

  Widget _buildQuantityCell(MonitorInventoryItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'SP: ${currencyFormatter.format(item.sellingPrice)}',
          maxLines: 1,
          style: TextStyle(
            color: AppColors.getTextPrimaryColor(context as BuildContext),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 1),
        item.expiryDate != null && item.expiryDate!.isNotEmpty
            ? Text(
                'exp: ${item.expiryDate}',
                style: TextStyle(color: AppColors.getTextSecondaryColor(context as BuildContext), fontSize: 10),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QTY: ${item.quantityOnHand}',
                    style: TextStyle(color: AppColors.getTextSecondaryColor(context as BuildContext), fontSize: 10),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'sup. on : ${DateFormat('dd/MM/yyyy').format(item.lastUpdated)}',
                    style: TextStyle(color: AppColors.getTextSecondaryColor(context as BuildContext), fontSize: 10),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildServiceCell(MonitorInventoryItem item) {
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
                  style: TextStyle(
                    color: AppColors.getTextPrimaryColor(context as BuildContext),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  'Category: ${item.category}',
                  style: TextStyle(color: AppColors.getTextHintColor(context as BuildContext), fontSize: 10),
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

  Widget _buildPriceCell(MonitorInventoryItem item) {
    return Text(
      currencyFormatter.format(item.sellingPrice),
      style: TextStyle(
        color: AppColors.getTextPrimaryColor(context as BuildContext),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStockStatusIndicator(MonitorInventoryItem item) {
    final bool isLowStock = item.quantityOnHand < 40;
    final bool isOverstocked = item.quantityOnHand > 100;

    Color color;

    if (isLowStock) {
      color = LightColors.error;
    } else if (isOverstocked) {
      color = LightColors.success;
    } else {
      color = LightColors.warning;
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
      color: AppColors.getSurfaceColor(context as BuildContext),
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 16,
        color: AppColors.getTextSecondaryColor(context as BuildContext),
      ),
    );
  }

  void _showItemDetailsDialog(BuildContext context, MonitorInventoryItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) => ItemDetailsDialog(item: item),
    );
  }
}
