import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../services/sync_state_manager.dart';
import '../widgets/finance/date_range.dart';
import 'mon_dashboard_controller.dart';

class MonGrossProfitController extends GetxController {
  // Controllers and database instance
  final MonDashboardController dateController = Get.find();
  final dbHelper = UnifiedDatabaseHelper.instance;

  // Reactive state variables
  var isLoading = true.obs;
  var hasError = false.obs;
  var isInitialized = false.obs;

  var grossProfit = "0".obs;
  var totalSales = "0".obs;
  var cogs = "0".obs;
  var grossProfitTrend = "0%".obs;
  var unit = "UGX".obs;

  @override
  void onInit() {
    super.onInit();
    // Don't fetch data here - let the UI trigger it when ready
    debugPrint('MonGrossProfitController: onInit - NOT fetching data yet');
    
    // Set up listeners for date changes
    ever(dateController.selectedRange, (_) {
      if (isInitialized.value) {
        fetchGrossProfitData();
      }
    });
    ever(dateController.customRange, (_) {
      if (isInitialized.value) {
        fetchGrossProfitData();
      }
    });
  }

  /// Call this manually when the UI is ready
  Future<void> initializeData() async {
    if (isInitialized.value) {
      debugPrint('MonGrossProfitController: Already initialized, skipping');
      return;
    }
    
    debugPrint('MonGrossProfitController: Performing first data fetch');
    await fetchGrossProfitData();
    isInitialized.value = true;
  }

  Future<void> fetchGrossProfitData() async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final db = dbHelper.database;
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;
      DateTime prevStartDate;
      DateTime prevEndDate;

      final range = dateController.selectedRange.value;
      final customRange = dateController.customRange.value;

      // Determine date ranges based on selection
      switch (range) {
        case DateRange.today:
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          prevStartDate = startDate.subtract(const Duration(days: 1));
          prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          break;

        case DateRange.yesterday:
          startDate = DateTime(now.year, now.month, now.day).subtract(
              const Duration(days: 1));
          endDate = DateTime(now.year, now.month, now.day).subtract(
              const Duration(milliseconds: 1));
          prevStartDate = startDate.subtract(const Duration(days: 1));
          prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          break;

        case DateRange.last7Days:
          startDate = now.subtract(const Duration(days: 6));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          prevStartDate = startDate.subtract(const Duration(days: 7));
          prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          break;

        case DateRange.monthToDate:
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          final prevMonth = DateTime(now.year, now.month - 1, 1);
          prevStartDate = prevMonth;
          prevEndDate = DateTime(now.year, now.month, 1).subtract(
              const Duration(milliseconds: 1));
          break;

        case DateRange.custom:
          if (customRange != null) {
            startDate = customRange.start;
            endDate = customRange.end;
            final duration = endDate.difference(startDate);
            prevStartDate = startDate.subtract(duration);
            prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          } else {
            startDate = now.subtract(const Duration(days: 6));
            startDate =
                DateTime(startDate.year, startDate.month, startDate.day);
            endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
            prevStartDate = startDate.subtract(const Duration(days: 7));
            prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          }
          break;
      }

      // Format dates for KPI queries (yyyy-MM-dd)
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final startDateStr = dateFormatter.format(startDate);
      final endDateStr = dateFormatter.format(endDate);
      final prevStartDateStr = dateFormatter.format(prevStartDate);
      final prevEndDateStr = dateFormatter.format(prevEndDate);

      // SQL Query using the KPI table
      // kpiId=5 is Profit (amount1=profit, amount2=transaction value during that day)

      // Get profit data - amount1 is profit, amount2 is transaction value
      const profitQuery = '''
        SELECT SUM(amount1) as profit, SUM(amount2) as sales 
        FROM mon_kpi_sales 
        WHERE kpi_id = 5 AND processing_date BETWEEN ? AND ?
      ''';

      // Query for currency
      const currencyQuery = 'SELECT currency FROM mon_kpi_sales LIMIT 1';

      // Execute queries
      final currentProfitResult = await db.rawQuery(
          profitQuery, [startDateStr, endDateStr]);
      final prevProfitResult = await db.rawQuery(
          profitQuery, [prevStartDateStr, prevEndDateStr]);
      final currencyResult = await db.rawQuery(currencyQuery);

      // Extract results - amount1 is profit, amount2 is transaction value (for that day/range)
      final currentProfit = (currentProfitResult.first['profit'] as num? ?? 0.0)
          .toDouble();
      final currentTransactionValue = (currentProfitResult
          .first['sales'] as num? ?? 0.0).toDouble();
      final prevProfit = (prevProfitResult.first['profit'] as num? ?? 0.0)
          .toDouble();
      final prevTransactionValue = (prevProfitResult.first['sales'] as num? ??
          0.0).toDouble();

      print("Current Profit: $currentProfit");
      print("Current Transaction Value: $currentTransactionValue");
      print("Previous Profit: $prevProfit");
      print("Previous Transaction Value: $prevTransactionValue");

      // Determine currency
      String currency = 'UGX';
      if (currencyResult.isNotEmpty) {
        String? dbCurrency = currencyResult.first['currency'] as String?;
        if (dbCurrency != null) {
          currency = dbCurrency == 'Uganda Shillings' ? 'UGX' : dbCurrency;
        }
      }
      unit.value = currency;

      // Formatters
      final compactFormatter = NumberFormat.compact();
      final percentFormatter = NumberFormat('+#,##0.0%;-#,##0.0%');

      // Calculate trend based on profit
      final grossProfitTrendValue = prevProfit > 0
          ? (currentProfit - prevProfit) / prevProfit
          : (currentProfit > 0 ? 1.0 : 0.0);

      // Update observable values - directly as fetched
      grossProfit.value = compactFormatter.format(currentProfit);
      totalSales.value = compactFormatter.format(currentTransactionValue);
      cogs.value = '0'; // Not provided by KPI, set to 0
      grossProfitTrend.value = percentFormatter.format(grossProfitTrendValue);
    } catch (e) {
      hasError.value = true;
      print("Error fetching gross profit data: $e");
    } finally {
      isLoading.value = false;
    }
  }
}