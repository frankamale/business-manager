import 'package:bac_pos/pages/daily_summary.dart';
import 'package:bac_pos/pages/pos_screen.dart';
import 'package:bac_pos/pages/sales_listing.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/service_point.dart';

class SalesPointDetails extends StatelessWidget {
  final ServicePoint servicePoint;

  const SalesPointDetails({super.key, required this.servicePoint});

  Color _getColorForServicePoint(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('restaurant')) return Colors.red;
    if (lowerType.contains('bar')) return Colors.purple;
    if (lowerType.contains('cafe') || lowerType.contains('cafeteria'))
      return Colors.brown;
    if (lowerType.contains('pharmacy')) return Colors.green;
    if (lowerType.contains('hardware')) return Colors.orange;
    if (lowerType.contains('shop')) return Colors.blue;
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForServicePoint(servicePoint.servicepointtype);

    return Scaffold(
      appBar: AppBar(
        title: Text(servicePoint.name),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _actionButton(
                  "ENTER NEW BILL/SALE",
                  Icons.monetization_on_outlined,
                  PosScreen(),
                ),
                _actionButton(
                  "VIEW SALE ORDERS/BILLS",
                  Icons.list,
                  SalesListing(),
                ),
                _actionButton(
                  "DAILY SUMMARY",
                  Icons.dashboard_outlined,
                  DailySummary(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Widget destination) {
    final baseColor = _getColorForServicePoint(servicePoint.servicepointtype);

    return InkWell(
      onTap: () {
        Get.to(() => destination);
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
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
