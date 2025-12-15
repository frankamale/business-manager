import 'package:bac_pos/bac_monitor/lib/widgets/dashboard/stock_out.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

import '../../additions/colors.dart';
import '../../controllers/salestrends_controller.dart';

Widget buildExpiriesCard(SalesTrendsController controller) {
  return Card(
    color: PrimaryColors.lightBlue,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Expiries",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Obx(() {
            if (controller.isLoadingExpiries.value) {
              return const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            // Display a message because data is unavailable
            if (controller.expiries.isEmpty) {
              return const SizedBox(
                height: 140,
                child: Center(
                  child: Text(
                    'Product expiry data is not available.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }
            return CategorizedStockAlertsList(alerts: controller.expiries);
          }),
        ],
      ),
    ),
  );
}
