import 'package:bac_pos/pages/homepage.dart';
import 'package:bac_pos/pages/pos_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

class SalesPointDetails extends StatelessWidget {
  final ServicePoint servicePoint;

  const SalesPointDetails({super.key, required this.servicePoint});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(servicePoint.name),
        backgroundColor: servicePoint.color,
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
                _actionButton("ENTER NEW BILL/SALE", Icons.monetization_on_outlined, "To homescreen"),
                _actionButton("VIEW SALE ORDERS/BILLS", Icons.monetization_on_outlined, "To homescreen"),
                _actionButton("DAILY SUMMARY", Icons.monetization_on_outlined, "To homescreen"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, String string) {
    return InkWell(
      onTap: (() {
        Get.to(() => PosScreen());
      }),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: servicePoint.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: servicePoint.color.withOpacity(0.3),
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
