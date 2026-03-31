import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../additions/colors.dart';
import '../../controllers/mon_kpi_controller.dart';
import '../../controllers/mon_store_controller.dart';
import '../../controllers/mon_store_kpi_controller.dart';
import '../../models/kpi_sales_data.dart';
import '../../models/trend_direction.dart';
import '../../widgets/dashboard/line_graph.dart';
import '../../widgets/store/hourly_traffic.dart';
import '../../widgets/store/product_list.dart';

class StoreOverview extends StatelessWidget {
  const StoreOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final MonStoresController controller = Get.find();
    final kpiTrendController = Get.find<MonStoreKpiTrendController>();
    final monKpiController = Get.find<MonKpiController>();

    return Obx(() {
      // Load user role and check if user role contains 'fg' (gym)
      kpiTrendController.loadUserRole();
      final isGym = kpiTrendController.userRole.value.toLowerCase().contains('fg');
      
      if (controller.isFetchingKpisAndCharts.value) {
        return const Padding(
          padding: EdgeInsets.only(top: 100.0),
          child: Center(
            child: CircularProgressIndicator(color: PrimaryColors.brightYellow),
          ),
        );
      }
      return Container(
        color: PrimaryColors.darkBlue,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              GridView.count(
                padding: EdgeInsets.zero,
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildKpiCard(
                    title: isGym ? 'Total Revenue' : 'Total Sales',
                    value: kpiTrendController.totalSales.value,
                    unit: kpiTrendController.unit.value,
                    trend: kpiTrendController.salesTrend.value,
                    trendDirection:
                        kpiTrendController.salesTrendDirection.value,
                  ),
                  _buildKpiCard(
                    title: isGym ? 'Total Walk Ins' : 'Transactions',
                    value: isGym 
                        ? kpiTrendController.totalWalkIns.value.toString()
                        : kpiTrendController.totalTransactions.value,
                    trend: kpiTrendController.transactionsTrend.value,
                    trendDirection:
                        kpiTrendController.transactionsTrendDirection.value,
                  ),
                  _buildKpiCard(
                    title: isGym ? 'Daily Subs' : 'Avg. Basket Size',
                    value: isGym
                        ? kpiTrendController.dailySubs.value.toString()
                        : kpiTrendController.avgBasketSize.value,
                    unit: isGym ? '' : kpiTrendController.unit.value,
                    trend: kpiTrendController.basketTrend.value,
                    trendDirection:
                        kpiTrendController.basketTrendDirection.value,
                  ),
                  _buildKpiCard(
                    title: isGym ? 'Monthly Subs' : 'Cash Sales',
                    value: isGym
                        ? kpiTrendController.monthlySubs.value.toString()
                        : kpiTrendController.cashSales.value,
                    unit: isGym ? '' : kpiTrendController.unit.value,
                    trend: isGym ? null : kpiTrendController.cashSalesTrend.value,
                    trendDirection: isGym ? null : kpiTrendController.cashSalesTrendDirection.value,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: EdgeInsetsGeometry.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: PrimaryColors.lightBlue,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Sales Trends",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 250,
                      child: SalesTrendLineGraph(
                        salesData: controller.salesDataPoints,
                        dateRange: controller.selectedDateRange.value,
                        customRange: controller.customDateRange.value,
                        aggregationType: controller.aggregationType.value,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // const Text(
              //   "Hourly Customer Traffic",
              //   style: TextStyle(
              //     fontSize: 20,
              //     fontWeight: FontWeight.bold,
              //     color: Colors.white,
              //   ),
              // ),
              //  const SizedBox(height: 10),
              // SizedBox(
              //   height: 250,
              //   child: HourlyTrafficChart(trafficData: controller.hourlyTrafficData),
              // ),
              // const SizedBox(height: 24),
              const Text(
                "Top Selling Products",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TopProductsList(products: controller.topSellingProducts),
              const SizedBox(height: 24),

            ],
          ),
        ),
      );
    });
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    String? unit,
    String? trend,
    TrendDirection? trendDirection,
  }) {
    return Card(
      color: PrimaryColors.lightBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${unit != null && unit.isNotEmpty ? '$unit ' : ''}$value',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (trend != null && trendDirection != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    trendDirection == TrendDirection.up
                        ? Icons.arrow_upward
                        : trendDirection == TrendDirection.down
                        ? Icons.arrow_downward
                        : Icons.remove,
                    color: trendDirection == TrendDirection.up
                        ? Colors.green
                        : trendDirection == TrendDirection.down
                        ? Colors.red
                        : Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trend,
                    style: TextStyle(
                      color: trendDirection == TrendDirection.up
                          ? Colors.green
                          : trendDirection == TrendDirection.down
                          ? Colors.red
                          : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

 
}
