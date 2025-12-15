import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/trend_direction.dart';
import '../widgets/finance/date_range.dart';
import 'dashboard_controller.dart';

class GrossProfitController extends GetxController {
  // Controllers and database instance
  final DashboardController dateController = Get.find();
  final dbHelper = DatabaseHelper();

  // Reactive state variables
  var isLoading = true.obs;
  var hasError = false.obs;

  var grossProfit = "0".obs;
  var totalSales = "0".obs;
  var cogs = "0".obs;
  var grossProfitTrend = "0%".obs;
  var grossProfitTrendDirection = TrendDirection.none.obs;
  var unit = "UGX".obs;

  @override
  void onInit() {
    super.onInit();
    fetchGrossProfitData();
    ever(dateController.selectedRange, (_) => fetchGrossProfitData());
    ever(dateController.customRange, (_) => fetchGrossProfitData());
  }

  Future<void> fetchGrossProfitData() async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final db = await dbHelper.database;
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
          startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
          endDate = DateTime(now.year, now.month, now.day).subtract(const Duration(milliseconds: 1));
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
          prevEndDate = DateTime(now.year, now.month, 1).subtract(const Duration(milliseconds: 1));
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
            startDate = DateTime(startDate.year, startDate.month, startDate.day);
            endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
            prevStartDate = startDate.subtract(const Duration(days: 7));
            prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          }
          break;
      }

      // Convert to milliseconds
      final startMillis = startDate.millisecondsSinceEpoch;
      final endMillis = endDate.millisecondsSinceEpoch;
      final prevStartMillis = prevStartDate.millisecondsSinceEpoch;
      final prevEndMillis = prevEndDate.millisecondsSinceEpoch;

      // SQL Queries
      const salesQuery = 'SELECT SUM(amount) as total FROM sales WHERE transactiondate BETWEEN ? AND ?';
      const cogsQuery = 'SELECT SUM(costprice * quantity) as total FROM sales WHERE transactiondate BETWEEN ? AND ?';
      const currencyQuery = 'SELECT currency FROM sales LIMIT 1';

      // Execute queries
      final currentSalesResult = await db.rawQuery(salesQuery, [startMillis, endMillis]);
      final prevSalesResult = await db.rawQuery(salesQuery, [prevStartMillis, prevEndMillis]);
      final currentCogsResult = await db.rawQuery(cogsQuery, [startMillis, endMillis]);
      final prevCogsResult = await db.rawQuery(cogsQuery, [prevStartMillis, prevEndMillis]);
      final currencyResult = await db.rawQuery(currencyQuery);

      // Extract results
      final currentSales = (currentSalesResult.first['total'] as num? ?? 0.0).toDouble();
      final prevSales = (prevSalesResult.first['total'] as num? ?? 0.0).toDouble();
      final currentCogs = (currentCogsResult.first['total'] as num? ?? 0.0).toDouble();
      final prevCogs = (prevCogsResult.first['total'] as num? ?? 0.0).toDouble();

      print("Current Sales: $currentSales");
      print("Current COGS: $currentCogs");
      print("Previous Sales: $prevSales");
      print("Previous COGS: $prevCogs");

      // Calculate gross profit
      final currentGrossProfit = currentSales - currentCogs;
      final prevGrossProfit = prevSales - prevCogs;

      print("Current Gross Profit: $currentGrossProfit");
      print("Previous Gross Profit: $prevGrossProfit");

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

      // Calculate trend
      final grossProfitTrendValue = prevGrossProfit > 0
          ? (currentGrossProfit - prevGrossProfit) / prevGrossProfit
          : (currentGrossProfit > 0 ? 1.0 : 0.0);

      // Update observable values
      grossProfit.value = compactFormatter.format(currentGrossProfit);
      totalSales.value = compactFormatter.format(currentSales);
      cogs.value = compactFormatter.format(currentCogs);
      grossProfitTrend.value = percentFormatter.format(grossProfitTrendValue);
      grossProfitTrendDirection.value = grossProfitTrendValue > 0.001
          ? TrendDirection.up
          : (grossProfitTrendValue < -0.001
          ? TrendDirection.down
          : TrendDirection.none);
    } catch (e) {
      hasError.value = true;
      print("Error fetching gross profit data: $e");
    } finally {
      isLoading.value = false;
    }
  }
}
