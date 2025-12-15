import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

import '../../additions/colors.dart';
import '../../controllers/mon_salestrends_controller.dart';
import 'bar_chat.dart';

Widget buildTopStoresCard(MonSalesTrendsController controller) {
  final stores = "Store";

  return Card(
    color: PrimaryColors.lightBlue,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Top $stores by Sales (UGX)",
            style: const TextStyle(
              color: Colors.white,
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
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'Error loading store data',
                    style: TextStyle(color: Colors.white),
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
