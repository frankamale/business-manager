import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../additions/colors.dart';
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

      // Use LayoutBuilder to determine card width based on screen size
      return LayoutBuilder(
        builder: (context, constraints) {
          // Determine number of columns based on available width
          final crossAxisCount = constraints.maxWidth > 600
              ? 3
              : (constraints.maxWidth > 350 ? 3 : 2);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeletonizer(
                enabled: isLoading,
                child: crossAxisCount >= 3
                    ? _buildThreeColumnRow(isGym)
                    : _buildTwoColumnGrid(isGym),
              ),
            ],
          );
        },
      );
    });
  }

  /// Builds a 3-column row for wider screens
  Widget _buildThreeColumnRow(bool isGym) {
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Sales - takes more space with mini KPIs for Cash and Credit
          Expanded(
            flex: 3,
            child: Obx(
              () => KpiCard(
                title: isGym ? "Total Revenue" : "Total Sales",
                value: controller.totalSales.value,
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
                    label: 'Credit Sales',
                    value: controller.creditSales.value,
                    accentColor: const Color(0xFFFFC107),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  /// Builds a 2-column grid for smaller screens
  Widget _buildTwoColumnGrid(bool isGym) {
    return Column(
      children: [
        // First row: Total Sales (wider) with mini KPIs
        SizedBox(
          height: 160,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Obx(
                  () => KpiCard(
                    title: isGym ? "Total Revenue" : "Total Sales",
                    value: controller.totalSales.value,
                    trendValue: controller.salesTrend.value,
                    trendDirection: controller.salesTrendDirection.value,
                    trendReference: 'vs last period',
                    miniKpis: [
                      MiniKpiData(
                        label: isGym ? 'Daily Subs' : 'Cash Sales',
                        value: controller.cashSales.value,
                        accentColor: const Color(0xFF4FC3F7),
                      ),
                      MiniKpiData(
                        label: isGym ? 'Monthly Subs' : 'Credit Sales',
                        value: controller.creditSales.value,
                        accentColor: const Color(0xFFFFC107),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
