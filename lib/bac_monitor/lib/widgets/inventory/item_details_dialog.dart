import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../additions/colors.dart';
import '../../models/inventory_data.dart';

class ItemDetailsDialog extends StatelessWidget {
  final InventoryItem item;

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
          gradient: LinearGradient(
            colors: [PrimaryColors.lightBlue, PrimaryColors.darkBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
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
                _buildHeaderSection(),
                const SizedBox(height: 24),

                // Product Info Section
                _buildSectionHeader('Product Information', Icons.info_outline),
                const SizedBox(height: 16),
                _buildProductInfoSection(),
                const SizedBox(height: 24),

                // Pricing Section
                _buildSectionHeader('Pricing Details', Icons.attach_money),
                const SizedBox(height: 16),
                _buildPricingSection(),
                const SizedBox(height: 24),

                // Stock Details Section
                _buildSectionHeader('Stock Details', Icons.inventory),
                const SizedBox(height: 16),
                _buildStockSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
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
                        _buildFallbackImage(),
                  )
                : _buildFallbackImage(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  color: Colors.white,
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
                  _buildBadge(item.category, PrimaryColors.brightYellow),
                  _buildBadge('SKU: ${item.sku}', PrimaryColors.greenBlue),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: PrimaryColors.brightYellow, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildProductInfoSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow('Category', item.category, Icons.category),
          Wrap(
            children: [
              _buildInfoRow('Supplier', item.servicePoint, Icons.business),
              _buildInfoRow(
                'Last Updated',
                DateFormat('dd/MM/yyyy').format(item.lastUpdated),
                Icons.update,
              ),
            ],
          ),
          if (item.expiryDate != null && item.expiryDate!.isNotEmpty)
            _buildInfoRow('Expiry Date', item.expiryDate!, Icons.date_range),
        ],
      ),
    );
  }

  Widget _buildPricingSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        children: [
          _buildInfoRow(
            'Cost Price',
            currencyFormatter.format(item.costPrice),
            Icons.trending_down,
          ),
          _buildInfoRow(
            'Selling Price',
            currencyFormatter.format(item.sellingPrice),
            Icons.trending_up,
          ),
        ],
      ),
    );
  }

  Widget _buildStockSection() {
    final bool isLowStock = item.isLowStock;
    final bool isOverstocked = item.quantityOnHand > 100;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  'Quantity on Hand',
                  item.quantityOnHand.toString(),
                  Icons.inventory_2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLowStock
                      ? Colors.red.withOpacity(0.2)
                      : isOverstocked
                      ? Colors.green.withOpacity(0.2)
                      : Colors.yellow.withOpacity(0.2),
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
                        ? Colors.red
                        : isOverstocked
                        ? Colors.green
                        : Colors.yellow,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          _buildInfoRow(
            'Reorder Level',
            item.reorderLevel.toString(),
            Icons.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: PrimaryColors.brightYellow, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
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

  Widget _buildBadge(String text, Color color) {
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

  Widget _buildFallbackImage() {
    return Container(
      color: Colors.grey.shade700,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 20,
        color: Colors.grey,
      ),
    );
  }
}
