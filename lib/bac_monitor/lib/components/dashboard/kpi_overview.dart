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
  void initState() {
    super.initState();
    controller = Get.find<MonKpiOverviewController>();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isGym = controller.userRole.value.toLowerCase().contains("fg");
      print(controller.userRole.value);
      print(isGym);

      final isLoading = controller.isLoading.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeletonizer(
            enabled: isLoading,
            child: KpiCard(
              title: isGym ? "Total Revenue" : "Total Sales",
              value: controller.totalSales.value,
              unit: controller.unit.value,
              trendValue: controller.salesTrend.value,
              trendDirection: controller.salesTrendDirection.value,
              trendReference: 'vs last period',
              miniKpis: [
                MiniKpiData(
                  label: 'Cash Sales',
                  value: controller.cashSales.value,
                  accentColor: const Color(0xFF4FC3F7),
                ),
                MiniKpiData(
                  label: 'Pending Payment',
                  value: controller.creditSales.value,
                  accentColor: const Color(0xFFFFC107),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
