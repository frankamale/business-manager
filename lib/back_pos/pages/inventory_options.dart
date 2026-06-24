import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/service_point.dart';
import 'stock_taking_list.dart';
import '../../flavors/flavor_colors.dart';

/// Inventory hub for a service point. Currently exposes Stock Taking; more
/// inventory tools can be added as additional tiles here.
class InventoryOptions extends StatelessWidget {
  final ServicePoint servicePoint;

  const InventoryOptions({super.key, required this.servicePoint});

  Color _getColorForServicePoint(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('restaurant')) return Colors.red;
    if (lowerType.contains('bar')) return Colors.purple;
    if (lowerType.contains('cafe') || lowerType.contains('cafeteria')) {
      return Colors.brown;
    }
    if (lowerType.contains('pharmacy')) return Colors.green;
    if (lowerType.contains('hardware')) return Colors.orange;
    if (lowerType.contains('shop')) return FlavorColors.current.primary;
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForServicePoint(servicePoint.servicepointtype);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _tile(
                'STOCK TAKING',
                Icons.fact_check_outlined,
                color,
                () => Get.to(
                  () => StockTakingList(servicePoint: servicePoint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    String label,
    IconData icon,
    Color baseColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [baseColor.withOpacity(0.8), baseColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(icon, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }
}
