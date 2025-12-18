import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../additions/colors.dart';
import '../../controllers/mon_dashboard_controller.dart';
import '../../controllers/mon_salestrends_controller.dart';
import '../../widgets/dashboard/cashiers.dart';
import '../../widgets/dashboard/expiries_card.dart';
import '../../widgets/dashboard/line_graph.dart';
import '../../widgets/dashboard/payment_method.dart';
import '../../widgets/dashboard/stock_Alerts.dart';
import '../../widgets/dashboard/top_stores.dart';

class SalesTrendsSection extends StatelessWidget {
  const SalesTrendsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final MonSalesTrendsController controller = Get.find<MonSalesTrendsController>();
    final MonDashboardController dateController = Get.find<MonDashboardController>();

    return Container(
      color: PrimaryColors.darkBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Sales Trends",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // This Obx for the line graph is correct and unchanged
          Obx(() {
            if (controller.isLoadingSales.value) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (controller.hasErrorSales.value) {
              return const SizedBox(
                height: 300,
                child: Center(
                  child: Text(
                    'Error loading sales data',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            }
            return Container(
              height: 300,
              decoration: BoxDecoration(
                color: PrimaryColors.lightBlue.withOpacity(0.5),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                child: SalesTrendLineGraph(
                  salesData: controller.salesData,
                  dateRange: dateController.selectedRange.value,
                  customRange: dateController.customRange.value,
                  aggregationType: controller.aggregationType.value,
                ),
              ),
            );
          }),
          const SizedBox(height: 24),

          Obx(
            () => PaymentMethodHorizontalBarChart(
              salesData: controller.rawSalesForPeriod.value,
              periodLabel: controller.getPeriodLabel(),
            ),
          ),

          const SizedBox(height: 24),

          Obx(
            () => CashierSalesChart(
              salesData: controller.rawSalesForPeriod.value,
              periodLabel: controller.getPeriodLabel(),
            ),
          ),
          const SizedBox(height: 16),
          buildStockAlertsCard(controller),
          const SizedBox(height: 16),
          buildExpiriesCard(controller),
          const SizedBox(height: 16),
          buildTopStoresCard(controller),
        ],
      ),
    );
  }
}
