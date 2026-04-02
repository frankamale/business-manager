import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../services/sync_state_manager.dart';
import '../widgets/finance/date_range.dart';
import 'mon_dashboard_controller.dart';

class MonOutstandingPaymentsController extends GetxController {
  final dbHelper = UnifiedDatabaseHelper.instance;
  final MonDashboardController dashboardController = Get.find<MonDashboardController>();

  // Observables for selected period
  var isLoading = false.obs;
  var hasError = false.obs;
  var outstandingSelectedPeriod = '0'.obs;
  var outstandingSelectedPeriodTrend = '0%'.obs;

  // Observables for MTD and YTD (always displayed)
  var outstandingMTD = '0'.obs;
  var outstandingYTD = '0'.obs;

  final compactFormatter = NumberFormat.compact();
  final percentFormatter = NumberFormat.percentPattern()..maximumFractionDigits = 1;

  @override
  void onInit() {
    super.onInit();
    fetchOutstandingPaymentsData();
    // Listen to date range changes
    ever(dashboardController.selectedRange, (_) => fetchOutstandingPaymentsData());
    ever(dashboardController.customRange, (_) => fetchOutstandingPaymentsData());
  }

  Future<void> fetchOutstandingPaymentsData() async {
    try {
      // Check if data was already loaded by splash page via SyncStateManager
      try {
        if (Get.isRegistered<SyncStateManager>()) {
          final syncManager = Get.find<SyncStateManager>();
          if (!syncManager.shouldFetchTodayData()) {
            print("MonOutstandingPaymentsController: Data already loaded, skipping fetch");
            return;
          }
        }
      } catch (e) {
        print("MonOutstandingPaymentsController: Error checking SyncStateManager: $e");
      }

      isLoading.value = true;
      hasError.value = false;

      final db = dbHelper.database;
      final now = DateTime.now();

      // Calculate selected period range
      late DateTime startDate, endDate;
      late DateTime prevStartDate, prevEndDate;

      final range = dashboardController.selectedRange.value;
      final customRange = dashboardController.customRange.value;

      switch (range) {
        case DateRange.today:
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          prevStartDate = DateTime(now.year, now.month, now.day - 1);
          prevEndDate = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
          break;

        case DateRange.yesterday:
          startDate = DateTime(now.year, now.month, now.day - 1);
          endDate = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
          prevStartDate = DateTime(now.year, now.month, now.day - 2);
          prevEndDate = DateTime(now.year, now.month, now.day - 2, 23, 59, 59);
          break;

        case DateRange.last7Days:
          startDate = DateTime(now.year, now.month, now.day - 6);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          prevStartDate = DateTime(now.year, now.month, now.day - 13);
          prevEndDate = DateTime(now.year, now.month, now.day - 7, 23, 59, 59);
          break;

        case DateRange.monthToDate:
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          // Previous month
          final prevMonth = DateTime(now.year, now.month - 1, 1);
          prevStartDate = DateTime(prevMonth.year, prevMonth.month, 1);
          prevEndDate = DateTime(prevMonth.year, prevMonth.month, now.day, 23, 59, 59);
          break;

        case DateRange.custom:
          if (customRange!.start.isAfter(customRange.end)) {
            hasError.value = true;
            return;
          }
          startDate = customRange.start;
          endDate = customRange.end;
          // Calculate previous period of same duration
          final duration = endDate.difference(startDate);
          prevEndDate = startDate.subtract(const Duration(days: 1));
          prevStartDate = prevEndDate.subtract(duration);
          break;
      }

      // Format dates for KPI queries (yyyy-MM-dd)
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final startDateStr = dateFormatter.format(startDate);
      final endDateStr = dateFormatter.format(endDate);
      final prevStartDateStr = dateFormatter.format(prevStartDate);
      final prevEndDateStr = dateFormatter.format(prevEndDate);

      // Query for selected period outstanding payments
      // Using kpiId=2 (pending payment / credit transactions)
      // amount1 = amount paid, amount2 = amount supposed to be paid
      // Outstanding = amount2 - amount1 (pending amount)
      const outstandingQuery = '''
        SELECT SUM(amount2 - amount1) as total
        FROM mon_kpi_sales
        WHERE kpi_id = 2 AND processing_date BETWEEN ? AND ?
      ''';

      final currentResult = await db.rawQuery(
        outstandingQuery,
        [startDateStr, endDateStr],
      );
      final currentOutstanding = (currentResult.first['total'] as num? ?? 0.0).toDouble();

      // Query for previous period (for trend calculation)
      final prevResult = await db.rawQuery(
        outstandingQuery,
        [prevStartDateStr, prevEndDateStr],
      );
      final prevOutstanding = (prevResult.first['total'] as num? ?? 0.0).toDouble();

      // Calculate MTD (always calculate regardless of selection)
      final mtdStartDate = DateTime(now.year, now.month, 1);
      final mtdEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final mtdStartStr = dateFormatter.format(mtdStartDate);
      final mtdEndStr = dateFormatter.format(mtdEndDate);


      final mtdResult = await db.rawQuery(
        outstandingQuery,
        [mtdStartStr, mtdEndStr],
      );
      final mtdOutstanding = (mtdResult.first['total'] as num? ?? 0.0).toDouble();

      // Calculate YTD (always calculate regardless of selection)
      final ytdStartDate = DateTime(now.year, 1, 1);
      final ytdEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final ytdStartStr = dateFormatter.format(ytdStartDate);
      final ytdEndStr = dateFormatter.format(ytdEndDate);

      final ytdResult = await db.rawQuery(
        outstandingQuery,
        [ytdStartStr, ytdEndStr],
      );
      final ytdOutstanding = (ytdResult.first['total'] as num? ?? 0.0).toDouble();

      // Calculate trend for selected period
      double trendValue = 0.0;
      if (prevOutstanding > 0) {
        trendValue = (currentOutstanding - prevOutstanding) / prevOutstanding;
      } else if (currentOutstanding > 0) {
        trendValue = 1.0; // 100% increase if previous was 0
      }

      // Update observables
      outstandingSelectedPeriod.value = compactFormatter.format(currentOutstanding);
      outstandingSelectedPeriodTrend.value = percentFormatter.format(trendValue);
      outstandingMTD.value = compactFormatter.format(mtdOutstanding);
      outstandingYTD.value = compactFormatter.format(ytdOutstanding);

    } catch (e) {
      print('Error fetching outstanding payments: $e');
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }
}
