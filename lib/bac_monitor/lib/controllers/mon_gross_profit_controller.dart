import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../models/trend_direction.dart';
import '../widgets/finance/date_range.dart';
import 'mon_dashboard_controller.dart';

class MonGrossProfitController extends GetxController {
  // Controllers and database instance
  final MonDashboardController dateController = Get.find();
  final dbHelper = UnifiedDatabaseHelper.instance;

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

      // Format dates for KPI queries (yyyy-MM-dd)
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final startDateStr = dateFormatter.format(startDate);
      final endDateStr = dateFormatter.format(endDate);
      final prevStartDateStr = dateFormatter.format(prevStartDate);
      final prevEndDateStr = dateFormatter.format(prevEndDate);

      // SQL Queries using the new KPI table
      // kpiId=5 is Profit (amount1=profit, amount2=transaction value)
      // kpiId=0 is All Transactions (amount2=total sales)
      
      // Get total sales (kpiId=0, sum of amount2)
      const salesQuery = '''
        SELECT SUM(amount2) as total 
        FROM mon_kpi_sales 
        WHERE kpi_id = 0 AND processing_date BETWEEN ? AND ?
      ''';
      
      // Get profit data (kpiId=5)
      const profitQuery = '''
        SELECT SUM(amount1) as profit, SUM(amount2) as sales 
        FROM mon_kpi_sales 
        WHERE kpi_id = 5 AND processing_date BETWEEN ? AND ?
      ''';

      // Query for currency
      const currencyQuery = 'SELECT currency FROM mon_kpi_sales LIMIT 1';

      // Execute queries
      final currentSalesResult = await db.rawQuery(salesQuery, [startDateStr, endDateStr]);
      final prevSalesResult = await db.rawQuery(salesQuery, [prevStartDateStr, prevEndDateStr]);
      final currentProfitResult = await db.rawQuery(profitQuery, [startDateStr, endDateStr]);
      final prevProfitResult = await db.rawQuery(profitQuery, [prevStartDateStr, prevEndDateStr]);
      final currencyResult = await db.rawQuery(currencyQuery);

      // Extract results - sales
      final currentSales = (currentSalesResult.first['total'] as num? ?? 0.0).toDouble();
      final prevSales = (prevSalesResult.first['total'] as num? ?? 0.0).toDouble();
      
      // Extract results - profit (from kpiId=5)
      final currentProfit = (currentProfitResult.first['profit'] as num? ?? 0.0).toDouble();
      final currentProfitSales = (currentProfitResult.first['sales'] as num? ?? 0.0).toDouble();
      final prevProfit = (prevProfitResult.first['profit'] as num? ?? 0.0).toDouble();
      final prevProfitSales = (prevProfitResult.first['sales'] as num? ?? 0.0).toDouble();

      // For COGS, calculate as sales - profit (or use the sales from profit KPI)
      // Note: The profit KPI provides both profit (amount1) and sales (amount2)
      // COGS = Sales - Profit
      final currentCogs = currentProfitSales > 0 ? currentProfitSales - currentProfit : currentSales;
      final prevCogs = prevProfitSales > 0 ? prevProfitSales - prevProfit : prevSales;

      print("Current Sales (kpi=0): $currentSales");
      print("Current Profit (kpi=5): $currentProfit");
      print("Current COGS: $currentCogs");
      print("Previous Sales: $prevSales");
      print("Previous Profit: $prevProfit");
      print("Previous COGS: $prevCogs");

      // Calculate gross profit (use the profit from KPI or calculate from sales - cogs)
      final currentGrossProfit = currentProfit > 0 ? currentProfit : currentSales - currentCogs;
      final prevGrossProfit = prevProfit > 0 ? prevProfit : prevSales - prevCogs;

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
      totalSales.value = compactFormatter.format(currentSales > 0 ? currentSales : currentProfitSales);
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