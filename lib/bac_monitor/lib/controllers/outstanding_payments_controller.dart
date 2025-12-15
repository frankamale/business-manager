import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import 'dashboard_controller.dart';
import '../widgets/finance/date_range.dart';

class OutstandingPaymentsController extends GetxController {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final DashboardController dashboardController = Get.find<DashboardController>();

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
      isLoading.value = true;
      hasError.value = false;

      final db = await dbHelper.database;
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

      // Convert to milliseconds for database query
      final startMillis = startDate.millisecondsSinceEpoch;
      final endMillis = endDate.millisecondsSinceEpoch;
      final prevStartMillis = prevStartDate.millisecondsSinceEpoch;
      final prevEndMillis = prevEndDate.millisecondsSinceEpoch;

      // Query for selected period outstanding payments
      const outstandingQuery = '''
        SELECT SUM(balance) as total
        FROM sales
        WHERE transactiondate BETWEEN ? AND ?
        AND balance > 0
      ''';

      final currentResult = await db.rawQuery(
        outstandingQuery,
        [startMillis, endMillis],
      );
      final currentOutstanding = (currentResult.first['total'] as num? ?? 0.0).toDouble();

      // Query for previous period (for trend calculation)
      final prevResult = await db.rawQuery(
        outstandingQuery,
        [prevStartMillis, prevEndMillis],
      );
      final prevOutstanding = (prevResult.first['total'] as num? ?? 0.0).toDouble();

      // Calculate MTD (always calculate regardless of selection)
      final mtdStartDate = DateTime(now.year, now.month, 1);
      final mtdEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final mtdStartMillis = mtdStartDate.millisecondsSinceEpoch;
      final mtdEndMillis = mtdEndDate.millisecondsSinceEpoch;

      final mtdResult = await db.rawQuery(
        outstandingQuery,
        [mtdStartMillis, mtdEndMillis],
      );
      final mtdOutstanding = (mtdResult.first['total'] as num? ?? 0.0).toDouble();

      // Calculate YTD (always calculate regardless of selection)
      final ytdStartDate = DateTime(now.year, 1, 1);
      final ytdEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final ytdStartMillis = ytdStartDate.millisecondsSinceEpoch;
      final ytdEndMillis = ytdEndDate.millisecondsSinceEpoch;

      final ytdResult = await db.rawQuery(
        outstandingQuery,
        [ytdStartMillis, ytdEndMillis],
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
