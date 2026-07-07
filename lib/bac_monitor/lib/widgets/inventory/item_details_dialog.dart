import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../additions/colors.dart';
import '../../models/inventory_data.dart';

class ItemDetailsDialog extends StatelessWidget {
  final MonitorInventoryItem item;

  const ItemDetailsDialog({super.key, required this.item});

  NumberFormat get currencyFormatter =>
      NumberFormat.currency(locale: 'en_UG', symbol: 'UGX ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'ItemDetailsDialog: Building dialog for item ${item.name} with quantityOnHand: ${item.quantityOnHand}',
    );
    return Dialog(
      insetPadding: EdgeInsets.all(10.0),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          color: AppColors.getCardColor(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.getShadowColor(context),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                _buildHeaderSection(context),
                const SizedBox(height: 24),

                // Product Info Section
                _buildSectionHeader(context, 'Product Information', Icons.info_outline),
                const SizedBox(height: 16),
                _buildProductInfoSection(context),
                const SizedBox(height: 24),

                // Pricing Section
                _buildSectionHeader(context, 'Pricing Details', Icons.attach_money),
                const SizedBox(height: 16),
                _buildPricingSection(context),
                const SizedBox(height: 24),

                // Stock Details Section
                _buildSectionHeader(context, 'Stock Details', Icons.inventory),
                const SizedBox(height: 16),
                _buildStockSection(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.getShadowLightColor(context),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildFallbackImage(context),
                  )
                : _buildFallbackImage(context),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: TextStyle(
                  color: AppColors.getTextPrimaryColor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.fade,
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 8,
                children: [
                  _buildBadge(context, item.category, AppColors.getAccentColor(context)),
                  _buildBadge(context, 'SKU: ${item.sku}', AppColors.getSecondaryColor(context)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.getAccentColor(context), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppColors.getTextPrimaryColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildProductInfoSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow(context, 'Category', item.category, Icons.category),
          Wrap(
            children: [
              _buildInfoRow(context, 'Supplier', item.servicePoint, Icons.business),
              _buildInfoRow(
                context,
                'Last Updated',
                DateFormat('dd/MM/yyyy').format(item.lastUpdated),
                Icons.update,
              ),
            ],
          ),
          if (item.expiryDate != null && item.expiryDate!.isNotEmpty)
            _buildInfoRow(context, 'Expiry Date', item.expiryDate!, Icons.date_range),
        ],
      ),
    );
  }

  Widget _buildPricingSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        direction: Axis.horizontal,
        children: [
          _buildInfoRow(
            context,
            'Cost Price',
            currencyFormatter.format(item.costPrice),
            Icons.trending_down,
          ),
          _buildInfoRow(
            context,
            'Selling Price',
            currencyFormatter.format(item.sellingPrice),
            Icons.trending_up,
          ),
        ],
      ),
    );
  }

  Widget _buildStockSection(BuildContext context) {
    final bool isLowStock = item.isLowStock;
    final bool isOverstocked = item.quantityOnHand > 100;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  context,
                  'Quantity on Hand',
                  item.quantityOnHand.toString(),
                  Icons.inventory_2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLowStock
                      ? AppColors.getErrorColor(context).withOpacity(0.2)
                      : isOverstocked
                      ? AppColors.getSuccessColor(context).withOpacity(0.2)
                      : AppColors.getWarningColor(context).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isLowStock
                      ? 'Low Stock'
                      : isOverstocked
                      ? 'Overstocked'
                      : 'Normal',
                  style: TextStyle(
                    color: isLowStock
                        ? AppColors.getErrorColor(context)
                        : isOverstocked
                        ? AppColors.getSuccessColor(context)
                        : AppColors.getWarningColor(context),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          _buildInfoRow(
            context,
            'Reorder Level',
            item.reorderLevel.toString(),
            Icons.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.getAccentColor(context), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.getTextSecondaryColor(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.getTextPrimaryColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildFallbackImage(BuildContext context) {
    return Container(
      color: AppColors.getSurfaceColor(context),
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 20,
        color: AppColors.getTextSecondaryColor(context),
      ),
    );
  }
}
