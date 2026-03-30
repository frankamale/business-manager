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
                    title: isGym ? 'Monthly Subs' : 'Staff on Duty',
                    value: isGym
                        ? kpiTrendController.monthlySubs.value.toString()
                        : '0',
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
              const Text(
                "Hourly Customer Traffic",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 250,
                child: HourlyTrafficChart(trafficData: controller.hourlyTrafficData),
              ),
              const SizedBox(height: 24),
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
              _buildStoreKpiSection(),
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

  /// Build store-specific KPI section with mode selector
  Widget _buildStoreKpiSection() {
    final numberFormat = NumberFormat('#,##0.00');
    final monKpiController = Get.find<MonKpiController>();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PrimaryColors.lightBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PrimaryColors.brightYellow.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Store Analytics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Obx(() => monKpiController.isLoading.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PrimaryColors.brightYellow,
                        ),
                      )
                    : const Icon(
                        Icons.refresh,
                        color: PrimaryColors.brightYellow,
                      )),
                onPressed: () {
                  monKpiController.syncKpiFromApi();
                },
                tooltip: 'Sync from API',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // KPI Mode Selector Dropdown
          Obx(() => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: PrimaryColors.darkBlue,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: monKpiController.selectedKpiId.value,
                isExpanded: true,
                dropdownColor: PrimaryColors.lightBlue,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                icon: const Icon(Icons.arrow_drop_down, color: PrimaryColors.brightYellow),
                items: KpiMode.all.map((kpiId) {
                  return DropdownMenuItem<int>(
                    value: kpiId,
                    child: Text(KpiMode.getName(kpiId)),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    monKpiController.changeKpiMode(newValue);
                  }
                },
              ),
            ),
          )),
          const SizedBox(height: 16),
          // KPI Data Display
          Obx(() {
            if (monKpiController.isLoading.value && monKpiController.kpiData.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: PrimaryColors.brightYellow),
                ),
              );
            }

            if (monKpiController.hasError.value) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 8),
                      const Text(
                        'Error loading KPI data',
                        style: TextStyle(color: Colors.red),
                      ),
                      TextButton(
                        onPressed: () => monKpiController.fetchKpiData(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = monKpiController.kpiData;
            if (data.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white54, size: 40),
                      const SizedBox(height: 8),
                      const Text(
                        'No data available for this period',
                        style: TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => monKpiController.syncKpiFromApi(),
                        child: const Text('Sync from API'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                // Display KPI data in a table-like format
                ...data.map((item) => _buildStoreKpiDataItem(item, numberFormat)),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// Build individual KPI data item for store
  Widget _buildStoreKpiDataItem(KpiSalesData item, NumberFormat numberFormat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PrimaryColors.darkBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.kpi.isNotEmpty ? item.kpi : 'N/A',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (item.sellingPoint != null && item.sellingPoint!.isNotEmpty)
                  Text(
                    item.sellingPoint!,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Qty',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                Text(
                  item.quantity.toString(),
                  style: const TextStyle(
                    color: PrimaryColors.brightYellow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Amount',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                Text(
                  numberFormat.format(item.amount2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (item.kpiId == KpiMode.profit) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Profit',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  Text(
                    numberFormat.format(item.amount1),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
