import 'package:flutter/material.dart';
import '../../additions/colors.dart';
import '../../models/dashboard.dart';

class CategorizedStockAlertsList extends StatelessWidget {
  final List<CategorizedStockAlert> alerts;

  const CategorizedStockAlertsList({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
                size: 40,
              ),
              SizedBox(height: 8),
              Text(
                'All stock levels are healthy!',
                style: TextStyle(color: Colors.white70, fontSize: 16),
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
            title: 'Critical Stock (<=5)',
            alerts: criticalAlerts,
            icon: Icons.error_outline,
            color: Colors.red.shade400,
          ),

        // Add a divider if both sections are present
        if (criticalAlerts.isNotEmpty && lowAlerts.isNotEmpty)
          const Divider(color: Colors.white24, height: 24, thickness: 1),

        // Conditionally build the "Low Stock" section
        if (lowAlerts.isNotEmpty)
          _buildAlertSection(
            title: 'Low Stock (6-10)',
            alerts: lowAlerts,
            icon: Icons.warning_amber_rounded,
            color: PrimaryColors.brightYellow,
          ),
      ],
    );
  }

  // A helper widget to build each section (Critical or Low)
  Widget _buildAlertSection({
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
        ...alerts.map((alert) => _buildAlertItem(alert, icon, color)),
      ],
    );
  }

  // A helper widget for a single alert item row
  Widget _buildAlertItem(
    CategorizedStockAlert alert,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              alert.name,
              style: const TextStyle(color: Colors.white, fontSize: 14),
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
