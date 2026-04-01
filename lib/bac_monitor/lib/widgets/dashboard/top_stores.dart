import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

import '../../additions/colors.dart';
import '../../controllers/mon_salestrends_controller.dart';
import 'bar_chat.dart';

Widget buildTopStoresCard(BuildContext context, MonSalesTrendsController controller) {
  final stores = "Store";
  final cardColor = AppColors.getCardColor(context);
  final shadowColor = AppColors.getShadowLightColor(context);
  final textPrimary = AppColors.getTextPrimaryColor(context);
  final errorColor = AppColors.getErrorColor(context);

  return Card(
    color: cardColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
    shadowColor: shadowColor,
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Top $stores by Sales (UGX)",
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 10),
          Obx(() {
            if (controller.isLoadingStores.value) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (controller.hasErrorStores.value) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'Error loading store data',
                    style: TextStyle(color: errorColor),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                height: 200,
                child: TopStoresBarChart(storeData: controller.topStoresData),
              ),
            );
          }),
        ],
      ),
    ),
  );
}
