import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
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
      //final isGym = kpiTrendController.userRole.value.toLowerCase().contains('fg');
      final isGym = false;

      return Container(
        color: AppColors.getBackgroundColor(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
          child: Skeletonizer(
            enabled: controller.isFetchingKpisAndCharts.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // KPI Cards Section
                GridView.count(
                  padding: EdgeInsets.zero,
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildKpiCard(
                      context,
                      title: isGym ? 'Total Revenue' : 'Total Sales',
                      value: kpiTrendController.totalSales.value,
                      unit: kpiTrendController.unit.value,
                      trend: kpiTrendController.salesTrend.value,
                      trendDirection: kpiTrendController.salesTrendDirection.value,
                      icon: Icons.attach_money,
                      iconColor: AppColors.getSuccessColor(context),
                    ),
                    _buildKpiCard(
                      context,
                      title: isGym ? 'Total Walk Ins' : 'Cash Sales',
                      value: isGym
                          ? kpiTrendController.totalWalkIns.value.toString()
                          : kpiTrendController.cashSales.value,
                      unit: isGym ? '' : kpiTrendController.unit.value,
                      trend: isGym ? null : kpiTrendController.cashSalesTrend.value,
                      trendDirection: isGym ? null : kpiTrendController.cashSalesTrendDirection.value,
                      icon: isGym ? Icons.people : Icons.payments,
                      iconColor: isGym ? AppColors.getInfoColor(context) : AppColors.getSuccessColor(context),
                    ),
                    _buildKpiCard(
                      context,
                      title: isGym ? 'Daily Subs' : 'Avg. Basket Size',
                      value: isGym
                          ? kpiTrendController.dailySubs.value.toString()
                          : kpiTrendController.avgBasketSize.value,
                      unit: isGym ? '' : kpiTrendController.unit.value,
                      trend: kpiTrendController.basketTrend.value,
                      trendDirection: kpiTrendController.basketTrendDirection.value,
                      icon: Icons.shopping_basket,
                      iconColor: AppColors.getWarningColor(context),
                    ),
                    _buildKpiCard(
                      context,
                      title: isGym ? 'Monthly Subs' : 'Pending Payments',
                      value: isGym
                          ? kpiTrendController.monthlySubs.value.toString()
                          : kpiTrendController.pendingPayments.value,
                      unit: isGym ? '' : kpiTrendController.unit.value,
                      trend: isGym ? null : kpiTrendController.pendingPaymentsTrend.value,
                      trendDirection: isGym ? null : kpiTrendController.pendingPaymentsTrendDirection.value,
                      icon: isGym ? Icons.calendar_month : Icons.pending_actions,
                      iconColor: isGym ? AppColors.getPrimaryColor(context) : AppColors.getWarningColor(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Sales Trends Section
                _buildSectionCard(
                  context,
                  title: "Sales Trends",
                  icon: Icons.trending_up,
                  child: SizedBox(
                    height: 250,
                    child: SalesTrendLineGraph(
                      salesData: controller.salesDataPoints,
                      dateRange: controller.selectedDateRange.value,
                      customRange: controller.customDateRange.value,
                      aggregationType: controller.aggregationType.value,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Top Selling Products Section
                _buildSectionCard(
                  context,
                  title: "Top Selling Products",
                  icon: Icons.leaderboard,
                  child: TopProductsList(products: controller.topSellingProducts),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSectionCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Widget child,
      }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadowLightColor(context),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.getTextPrimaryColor(context), size: 17),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildKpiCard(
      BuildContext context, {
        required String title,
        required String value,
        String? unit,
        String? trend,
        TrendDirection? trendDirection,
        required IconData icon,
        required Color iconColor,
      }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 140),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.getCardColor(context),
              AppColors.getSurfaceColor(context),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.getShadowLightColor(context),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background watermark icon
            Positioned(
              right: -12,
              bottom: -12,
              child: Opacity(
                opacity: 0.08,
                child: Icon(
                  icon,
                  size: 100,
                  color: iconColor,
                ),
              ),
            ),
            // Foreground content
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: trend badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (trend != null && trendDirection != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: trendDirection == TrendDirection.up
                                ? AppColors.getSuccessColor(context).withOpacity(0.2)
                                : trendDirection == TrendDirection.down
                                ? AppColors.getErrorColor(context).withOpacity(0.2)
                                : AppColors.getTextDisabledColor(context).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                trendDirection == TrendDirection.up
                                    ? Icons.arrow_upward
                                    : trendDirection == TrendDirection.down
                                    ? Icons.arrow_downward
                                    : Icons.remove,
                                color: trendDirection == TrendDirection.up
                                    ? AppColors.getSuccessColor(context)
                                    : trendDirection == TrendDirection.down
                                    ? AppColors.getErrorColor(context)
                                    : AppColors.getTextSecondaryColor(context),
                                size: 10,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  trend,
                                  style: TextStyle(
                                    color: trendDirection == TrendDirection.up
                                        ? AppColors.getSuccessColor(context)
                                        : trendDirection == TrendDirection.down
                                        ? AppColors.getErrorColor(context)
                                        : AppColors.getTextSecondaryColor(context),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // Bottom section: title and value
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: AppColors.getTextSecondaryColor(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${unit != null && unit.isNotEmpty ? '$unit ' : ''}$value',
                            style: TextStyle(
                              color: AppColors.getTextPrimaryColor(context),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


}
