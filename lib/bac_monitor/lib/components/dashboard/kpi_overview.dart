import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../controllers/mon_kpi_overview_controller.dart';
import '../../widgets/dashboard/kpi_card.dart';


class KpiOverviewSection extends StatefulWidget {
  const KpiOverviewSection({super.key});

  @override
  State<KpiOverviewSection> createState() => _KpiOverviewSectionState();
}

class _KpiOverviewSectionState extends State<KpiOverviewSection> {
  late final MonKpiOverviewController controller;

  @override
  void initState()   {
    super.initState();
    controller = Get.find<MonKpiOverviewController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.initializeData();
    });
  }


  @override
  Widget build(BuildContext context) {

    return Obx(() {
      controller.loadUserRole();
      final isGym = controller.userRole.value.toLowerCase().contains("fg");
      print(controller.userRole.value);
      print(isGym);
      final isLoading = controller.isLoading.value;

      return Skeletonizer(
        enabled: isLoading,
        child: GridView.count(
          padding: EdgeInsets.zero,
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          children: [
            KpiCard(
              title: isGym? "Total Revenue" : "Total Sales",
              value: controller.totalSales.value,
              trendValue: controller.salesTrend.value,
              trendDirection: controller.salesTrendDirection.value,
              unit: controller.unit.value,
            ),
            KpiCard(
              title: isGym? "Inventory Sales" : "Avg. Basket Size",
              value: controller.avgBasketSize.value,
              trendValue: controller.basketTrend.value,
              trendDirection: controller.basketTrendDirection.value,
              unit: isGym? controller.unit.value : null,
            ),
            KpiCard(
              title: isGym? "Total walk-ins" : "Total Transactions",
              value: controller.totalTransactions.value,
              trendValue: controller.transactionsTrend.value,
              trendDirection: controller.transactionsTrendDirection.value,
            ),

            KpiCard(
              title: isGym? "Active Members" : "Active / Total Stores",
              value: isGym? controller.activeMembers.value : controller.activeTotalStores.value,
              trendValue: controller.storesTrend.value,
              trendDirection: controller.storesTrendDirection.value,
            ),
          ],
        ),
      );
    });
  }
}
