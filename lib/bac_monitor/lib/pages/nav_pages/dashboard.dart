
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../additions/colors.dart';
import '../../components/dashboard/kpi_overview.dart';
import '../../components/dashboard/sales_trends.dart';
import '../../controllers/kpi_overview_controller.dart';
import '../../controllers/operator_controller.dart';
import '../../controllers/salestrends_controller.dart';
import '../../controllers/gross_profit_controller.dart';
import '../../controllers/outstanding_payments_controller.dart';
import '../../services/api_services.dart';
import '../../widgets/dashboard/gross_profit.dart';
import '../../widgets/dashboard/outstanding_payments.dart';
import '../../widgets/dashboard/expenses_card.dart';
import '../../widgets/finance/date_range.dart';
import '../notification.dart';
import '../expenses_detail_page.dart';
import '../../controllers/dashboard_controller.dart';
import '../../models/trend_direction.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  // Add this helper in _DashboardState class
  double _parseCompactNumber(String formatted) {
    formatted = formatted.replaceAll(',', '').toUpperCase();
    if (formatted.endsWith('K')) {
      return double.tryParse(formatted.replaceAll('K', ''))! * 1000;
    } else if (formatted.endsWith('M')) {
      return double.tryParse(formatted.replaceAll('M', ''))! * 1000000;
    } else if (formatted.endsWith('B')) {
      return double.tryParse(formatted.replaceAll('B', ''))! * 1000000000;
    }
    return double.tryParse(formatted) ?? 0.0;
  }

  String _getPeriodLabel(DateRange range, DateTimeRange? customRange) {
    switch (range) {
      case DateRange.today:
        return 'Today';
      case DateRange.yesterday:
        return 'Yesterday';
      case DateRange.last7Days:
        return 'Last 7 Days';
      case DateRange.monthToDate:
        return 'Month to Date';
      case DateRange.custom:
        if (customRange != null) {
          final formatter = DateFormat('MMM d');
          return '${formatter.format(customRange.start)} - ${formatter.format(customRange.end)}';
        }
        return 'Custom';
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize controllers in proper order
    // DashboardController must be initialized first as other controllers depend on it
    Get.put(DashboardController());
    Get.put(OperatorController());
    Get.put(GrossProfitController());
    Get.put(OutstandingPaymentsController());
    Get.put(SalesTrendsController());
    Get.put(KpiOverviewController());
  }

  Future<void> _handleRefresh() async {
    final apiService = Get.find<ApiService>();
    await apiService.syncRecentSales();

    if (Get.isRegistered<KpiOverviewController>()) {
      await Get.find<KpiOverviewController>().fetchKpiData();
    }
    if (Get.isRegistered<GrossProfitController>()) {
      await Get.find<GrossProfitController>();
    }
    if (Get.isRegistered<OutstandingPaymentsController>()) {
      await Get.find<OutstandingPaymentsController>().fetchOutstandingPaymentsData();
    }
    if (Get.isRegistered<SalesTrendsController>()) {
      await Get.find<SalesTrendsController>().fetchAllData();
    }
    if (Get.isRegistered<GrossProfitController>()) {
      await Get.find<GrossProfitController>().fetchGrossProfitData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final operatorController = Get.find<OperatorController>();

    return Scaffold(
      backgroundColor: PrimaryColors.darkBlue,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: PrimaryColors.brightYellow,
        backgroundColor: PrimaryColors.darkBlue,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: PrimaryColors.darkBlue,
              elevation: 2,
              pinned: true,
              centerTitle: true,
              title: Obx(
                () => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      operatorController.companyName.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      operatorController.companyAddress.value,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                        fontSize: 12.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.asset('assets/images/logo.jpeg'),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 28),
                    color: PrimaryColors.brightYellow,
                    onPressed: () {
                      Get.to(() => NotificationsPage());
                    },
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(65.0),
                child: DateRangePicker(
                  onDateRangeSelected: _onDateRangeChanged,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: PrimaryColors.darkBlue,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16),
                      KpiOverviewSection(),
                      SizedBox(height: 24),
                      Obx(() {
                        final controller = Get.find<GrossProfitController>();
                        // Then in the Obx block:
                        final grossProfitValue = _parseCompactNumber(controller.grossProfit.value);
                        final totalSalesValue = _parseCompactNumber(controller.totalSales.value);
                        final cogsValue = _parseCompactNumber(controller.cogs.value);

                        // Calculate previous period profit based on trend
                        final trendPercent =
                            double.tryParse(
                              controller.grossProfitTrend.value
                                  .replaceAll('%', '')
                                  .replaceAll('+', '')
                                  .replaceAll('-', ''),
                            ) ??
                            0.0;
                        final prevProfitValue =
                            controller.grossProfitTrendDirection.value ==
                                TrendDirection.up
                            ? grossProfitValue / (1 + trendPercent / 100)
                            : controller.grossProfitTrendDirection.value ==
                                  TrendDirection.down
                            ? grossProfitValue / (1 - trendPercent / 100)
                            : grossProfitValue;

                        return GrossProfitCard(
                          grossProfit: grossProfitValue,
                          totalSales: totalSalesValue,
                          cogs: cogsValue,
                          previousPeriodProfit: prevProfitValue,
                        );
                      }),
                      const SizedBox(height: 24),
                      Obx(() {
                        final controller = Get.find<OutstandingPaymentsController>();
                        final dashboardController = Get.find<DashboardController>();
                        final periodLabel = _getPeriodLabel(
                          dashboardController.selectedRange.value,
                          dashboardController.customRange.value,
                        );

                        return OutstandingPaymentsCard(
                          outstandingSelectedPeriod: controller.outstandingSelectedPeriod.value,
                          outstandingSelectedPeriodTrend: controller.outstandingSelectedPeriodTrend.value,
                          outstandingMTD: controller.outstandingMTD.value,
                          outstandingYTD: controller.outstandingYTD.value,
                          periodLabel: periodLabel,
                        );
                      }),
                      const SizedBox(height: 24),
                      // Expenses Card
                      Obx(() {
                        final dashboardController = Get.find<DashboardController>();
                        final periodLabel = _getPeriodLabel(
                          dashboardController.selectedRange.value,
                          dashboardController.customRange.value,
                        );

                        return ExpensesCard(
                          stockExpenses: 0.0,
                          nonStockExpenses: 0.0,
                          periodLabel: periodLabel,
                          onStockExpensesTap: () {
                            Get.to(() => ExpensesDetailPage(
                              expenseType: 'stock',
                              periodLabel: periodLabel,
                            ));
                          },
                          onNonStockExpensesTap: () {
                            Get.to(() => ExpensesDetailPage(
                              expenseType: 'non-stock',
                              periodLabel: periodLabel,
                            ));
                          },
                        );
                      }),
                      const SizedBox(height: 24),
                      SalesTrendsSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDateRangeChanged(DateRange newRange, DateTimeRange? customRange) {
    final controller = Get.find<DashboardController>();
    controller.updateDateRange(newRange, customRange);
  }
}
