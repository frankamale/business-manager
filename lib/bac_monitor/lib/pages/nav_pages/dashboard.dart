import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../../shared/database/unified_db_helper.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../additions/colors.dart';
import '../../components/dashboard/kpi_overview.dart';
import '../../components/dashboard/sales_trends.dart';
import '../../controllers/mon_dashboard_controller.dart';
import '../../controllers/mon_gross_profit_controller.dart';
import '../../controllers/mon_kpi_controller.dart';
import '../../controllers/mon_kpi_overview_controller.dart';
import '../../controllers/mon_operator_controller.dart';
import '../../controllers/mon_outstanding_payments_controller.dart';
import '../../controllers/mon_salestrends_controller.dart';
import '../../models/kpi_sales_data.dart';
import '../../services/api_services.dart';
import '../../widgets/dashboard/gross_profit.dart';
import '../../widgets/dashboard/outstanding_payments.dart';
import '../../widgets/dashboard/expenses_card.dart';
import '../../widgets/dashboard/horizontal_summary_cards.dart';
import '../../widgets/finance/date_range.dart';
import '../profile.dart';
import '../expenses_detail_page.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
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
    // DashboardController must be initialized first as other controllers depend on it
    if (!Get.isRegistered<MonDashboardController>()) {
      Get.put(MonDashboardController(), permanent: true);
    }
    if (!Get.isRegistered<MonOperatorController>()) {
      Get.put(MonOperatorController(), permanent: true);
    }
    if (!Get.isRegistered<MonOutstandingPaymentsController>()) {
      Get.put(MonOutstandingPaymentsController(), permanent: true);
    }
    if (!Get.isRegistered<MonGrossProfitController>()) {
      Get.put(MonGrossProfitController(), permanent: true);
    }
    if (!Get.isRegistered<MonSalesTrendsController>()) {
      Get.put(MonSalesTrendsController(), permanent: true);
    }
    if (!Get.isRegistered<MonKpiOverviewController>()) {
      Get.put(MonKpiOverviewController(), permanent: true);
    }
    // Initialize MonKpiController for detailed KPI data
    if (!Get.isRegistered<MonKpiController>()) {
      Get.put(MonKpiController(), permanent: true);
    }

    // Initialize controller data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllerData();
    });
  }

  void _initializeControllerData() async {
    // Initialize all controllers that load data from local DB
    // Each controller will query the DB based on the current date range

    // Initialize KPI overview data
    if (Get.isRegistered<MonKpiOverviewController>()) {
      await Get.find<MonKpiOverviewController>().fetchKpiData();
    }
    // Initialize gross profit data
    if (Get.isRegistered<MonGrossProfitController>()) {
      await Get.find<MonGrossProfitController>().fetchGrossProfitData();
    }
    // Initialize sales trends data
    if (Get.isRegistered<MonSalesTrendsController>()) {
      await Get.find<MonSalesTrendsController>().fetchAllData();
    }
    // Initialize outstanding payments data
    if (Get.isRegistered<MonOutstandingPaymentsController>()) {
      await Get.find<MonOutstandingPaymentsController>()
          .fetchOutstandingPaymentsData();
    }
    // Initialize KPI controller for detailed data
    if (Get.isRegistered<MonKpiController>()) {
      await Get.find<MonKpiController>().fetchKpiData();
    }
  }

  Future<void> _handleRefresh() async {
    final apiService = Get.find<MonitorApiService>();
    final dashboardController = Get.find<MonDashboardController>();

    // Get the selected date range
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final range = dashboardController.selectedRange.value;
    final customRange = dashboardController.customRange.value;

    switch (range) {
      case DateRange.today:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case DateRange.yesterday:
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 1));
        endDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(milliseconds: 1));
        break;
      case DateRange.last7Days:
        startDate = now.subtract(const Duration(days: 6));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case DateRange.monthToDate:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case DateRange.custom:
        if (customRange != null) {
          startDate = customRange.start;
          endDate = customRange.end;
        } else {
          startDate = now.subtract(const Duration(days: 6));
        }
        break;
    }

    // Fetch KPI data for the selected date range from server and store in DB
    try {
      await apiService.syncAllKpiData(startDate, endDate);

      // Also fetch service points to ensure they're up to date
      try {
        final servicePointsRes = await apiService.getWithAuth('/servicepoints');
        if (servicePointsRes.body.isNotEmpty) {
          final servicePointsData = json.decode(servicePointsRes.body) as List;
          final filteredServicePoints = servicePointsData.map((e) {
            final sp = Map<String, dynamic>.from(e as Map);
            return {
              'id': sp['id'],
              'name': sp['name'],
              'code': sp['code'],
              'fullName': sp['fullName'] ?? sp['name'] ?? '',
              'servicepointtype': sp['servicepointtype'] ?? '',
              'facilityName': sp['facilityName'] ?? '',
              'sales': (sp['sales'] == true || sp['sales'] == 1) ? 1 : 0,
              'stores': (sp['stores'] == true || sp['stores'] == 1) ? 1 : 0,
              'production': (sp['production'] == true || sp['production'] == 1)
                  ? 1
                  : 0,
              'booking': (sp['booking'] == true || sp['booking'] == 1) ? 1 : 0,
            };
          }).toList();
          await UnifiedDatabaseHelper.instance.deleteAllMonServicePoints();
          await UnifiedDatabaseHelper.instance.insertServicePoints(
            filteredServicePoints,
          );
        }
      } catch (e) {
        debugPrint('Dashboard: Service points fetch failed (non-critical): $e');
      }
    } catch (e) {
      debugPrint('Dashboard: KPI data fetch failed: $e');
    }

    // Refresh all controllers with the new data from DB
    if (Get.isRegistered<MonKpiOverviewController>()) {
      await Get.find<MonKpiOverviewController>().fetchKpiData();
    }
    if (Get.isRegistered<MonGrossProfitController>()) {
      await Get.find<MonGrossProfitController>().fetchGrossProfitData();
    }
    if (Get.isRegistered<MonOutstandingPaymentsController>()) {
      await Get.find<MonOutstandingPaymentsController>()
          .fetchOutstandingPaymentsData();
    }
    if (Get.isRegistered<MonSalesTrendsController>()) {
      await Get.find<MonSalesTrendsController>().fetchAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final operatorController = Get.find<MonOperatorController>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.getAccentColor(context),
        backgroundColor: AppColors.getCardColor(context),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.getCardColor(context),
              elevation: 0,
              pinned: true,
              centerTitle: true,
              title: Obx(
                () => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      operatorController.companyName.value,
                      style: TextStyle(
                        color: AppColors.getTextPrimaryColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      operatorController.companyAddress.value,
                      style: TextStyle(
                        color: AppColors.getTextSecondaryColor(context),
                        fontWeight: FontWeight.w400,
                        fontSize: 12.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              leading: Padding(
                padding: const EdgeInsets.only(left: 20.0),
                child: AppLogo(width: 100, height: 100),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: IconButton(
                    icon: Icon(
                      Icons.account_circle_outlined,
                      size: 28,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                    onPressed: () {
                      Get.to(() => ProfilePage());
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
                color: AppColors.getBackgroundColor(context),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),
                      KpiOverviewSection(),
                      SizedBox(height: 8),
                      Obx(() {
                        final controller = Get.find<MonGrossProfitController>();
                        final grossProfitValue = _parseCompactNumber(
                          controller.grossProfit.value,
                        );
                        final isLoading = controller.isLoading.value;

                        return Skeletonizer(
                          enabled: isLoading,
                          child: GrossProfitCard(
                            grossProfit: grossProfitValue,
                            trend: controller.grossProfitTrend.value,
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      const HorizontalSummaryCards(),
                      const SizedBox(height: 8),
                      // Obx(() {
                      //   final controller =
                      //       Get.find<MonOutstandingPaymentsController>();
                      //   final dashboardController =
                      //       Get.find<MonDashboardController>();
                      //   final periodLabel = _getPeriodLabel(
                      //     dashboardController.selectedRange.value,
                      //     dashboardController.customRange.value,
                      //   );
                      //
                      //   return OutstandingPaymentsCard(
                      //     outstandingSelectedPeriod:
                      //         controller.outstandingSelectedPeriod.value,
                      //     outstandingSelectedPeriodTrend:
                      //         controller.outstandingSelectedPeriodTrend.value,
                      //     outstandingMTD: controller.outstandingMTD.value,
                      //     outstandingYTD: controller.outstandingYTD.value,
                      //     periodLabel: periodLabel,
                      //   );
                      // }),
                      // const SizedBox(height: 24),
                      // // Expenses Card
                      Obx(() {
                        final dashboardController =
                            Get.find<MonDashboardController>();
                        final periodLabel = _getPeriodLabel(
                          dashboardController.selectedRange.value,
                          dashboardController.customRange.value,
                        );

                        return ExpensesCard(
                          stockExpenses: 0.0,
                          nonStockExpenses: 0.0,
                          periodLabel: periodLabel,
                          onStockExpensesTap: () {
                            Get.to(
                              () => ExpensesDetailPage(
                                expenseType: 'stock',
                                periodLabel: periodLabel,
                              ),
                            );
                          },
                          onNonStockExpensesTap: () {
                            Get.to(
                              () => ExpensesDetailPage(
                                expenseType: 'non-stock',
                                periodLabel: periodLabel,
                              ),
                            );
                          },
                        );
                      }),
                      const SizedBox(height: 12),
                      SalesTrendsSection(),
                      const SizedBox(height: 12),
                      // Detailed KPI Section with mode selector
                      // _buildDetailedKpiSection(),
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
    if (!Get.isRegistered<MonDashboardController>()) {
      Get.put(MonDashboardController(), permanent: true);
    }
    final controller = Get.find<MonDashboardController>();
    controller.updateDateRange(newRange, customRange);
  }
}
