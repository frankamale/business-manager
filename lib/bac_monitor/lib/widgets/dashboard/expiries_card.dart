import 'package:bac_pos/bac_monitor/lib/widgets/dashboard/stock_out.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

import '../../additions/colors.dart';
import '../../controllers/mon_salestrends_controller.dart';

Widget buildExpiriesCard(MonSalesTrendsController controller) {
  return Card(
    color: LightColors.card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
    shadowColor: LightColors.shadowLight,
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Expiries",
            style: TextStyle(
              color: LightColors.textPrimary,
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
              return SizedBox(
                height: 140,
                child: Center(
                  child: Text(
                    'Product expiry data is not available.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: LightColors.textSecondary),
                  ),
                ),
              );
            }
            return CategorizedStockAlertsList(alerts: controller.expiries.toList());
          }),
        ],
      ),
    ),
  );
}
