import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/mon_kpi_overview_controller.dart';
import '../../widgets/dashboard/kpi_card.dart';

class KpiOverviewSection extends StatelessWidget {
  const KpiOverviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    final MonKpiOverviewController controller = Get.find<MonKpiOverviewController>();

    return Obx(() {
      if (controller.isLoading.value) {
        return const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (controller.hasError.value) {
        return const SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'Error loading KPI data',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }

      return GridView.count(
        padding: EdgeInsets.zero,
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.3,
        children: [
          KpiCard(
            title: "Total Sales",
            value: controller.totalSales.value,
            trendValue: controller.salesTrend.value,
            trendDirection: controller.salesTrendDirection.value,
            unit: controller.unit.value,
          ),
          KpiCard(
            title: "Avg. Basket Size",
            value: controller.avgBasketSize.value,
            trendValue: controller.basketTrend.value,
            trendDirection: controller.basketTrendDirection.value,
            unit: controller.unit.value,
          ),
          KpiCard(
            title: "Total Transactions",
            value: controller.totalTransactions.value,
            trendValue: controller.transactionsTrend.value,
            trendDirection: controller.transactionsTrendDirection.value,
          ),
          KpiCard(
            title: "Active / Total Stores",
            value: controller.activeTotalStores.value,
            trendValue: controller.storesTrend.value,
            trendDirection: controller.storesTrendDirection.value,
          ),
        ],
      );
    });
  }
}
