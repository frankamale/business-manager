import 'package:flutter/material.dart';
import '../../additions/colors.dart';
import '../../models/dashboard.dart';

class CategorizedStockAlertsList extends StatelessWidget {
  final List<CategorizedStockAlert> alerts;
  final BuildContext? contextOverride;

  const CategorizedStockAlertsList({
    super.key,
    required this.alerts,
    this.contextOverride,
    required BuildContext context,
  });

  @override
  Widget build(BuildContext context) {
    final buildContext = contextOverride ?? context;
    final successColor = AppColors.getSuccessColor(buildContext);
    final errorColor = AppColors.getErrorColor(buildContext);
    final accentColor = AppColors.getAccentColor(buildContext);
    final borderColor = AppColors.getBorderColor(buildContext);
    final textPrimary = AppColors.getTextPrimaryColor(buildContext);
    final textSecondary = AppColors.getTextSecondaryColor(buildContext);

    if (alerts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: successColor,
                size: 40,
              ),
              SizedBox(height: 8),
              Text(
                'All stock levels are healthy!',
                style: TextStyle(color: textSecondary, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final criticalAlerts = alerts
        .where((a) => a.level == StockLevel.critical)
        .toList();
    final lowAlerts = alerts.where((a) => a.level == StockLevel.low).toList();

    return ListView(
      padding: EdgeInsets.zero, // Remove default padding
      children: [
        // Conditionally build the "Critical Stock" section
        if (criticalAlerts.isNotEmpty)
          _buildAlertSection(
            context: buildContext,
            title: 'Critical Stock (<=5)',
            alerts: criticalAlerts,
            icon: Icons.error_outline,
            color: errorColor,
          ),

        // Add a divider if both sections are present
        if (criticalAlerts.isNotEmpty && lowAlerts.isNotEmpty)
          Divider(color: borderColor, height: 24, thickness: 1),

        // Conditionally build the "Low Stock" section
        if (lowAlerts.isNotEmpty)
          _buildAlertSection(
            context: buildContext,
            title: 'Low Stock (6-10)',
            alerts: lowAlerts,
            icon: Icons.warning_amber_rounded,
            color: accentColor,
          ),
      ],
    );
  }

  // A helper widget to build each section (Critical or Low)
  Widget _buildAlertSection({
    required BuildContext context,
    required String title,
    required List<CategorizedStockAlert> alerts,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ...alerts.map((alert) => _buildAlertItem(context, alert, icon, color)),
      ],
    );
  }

  // A helper widget for a single alert item row
  Widget _buildAlertItem(
    BuildContext context,
    CategorizedStockAlert alert,
    IconData icon,
    Color color,
  ) {
    final textPrimary = AppColors.getTextPrimaryColor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              alert.name,
              style: TextStyle(color: textPrimary, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${alert.quantity} left',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
