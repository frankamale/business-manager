// ============================================================
// OPTIMIZED MonKpiOverviewController
// ============================================================
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/trend_direction.dart';
import '../widgets/finance/date_range.dart';
import 'mon_dashboard_controller.dart';

class MonKpiOverviewController extends GetxController {
  final MonDashboardController dateController = Get.find();
  final dbHelper = DatabaseHelper();

  var isLoading = true.obs;
  var hasError = false.obs;
  var isInitialized = false.obs; // Track if first load is done

  var totalSales = "0".obs;
  var salesTrend = "0%".obs;
  var salesTrendDirection = TrendDirection.none.obs;
  var totalTransactions = "0".obs;
  var transactionsTrend = "0%".obs;
  var transactionsTrendDirection = TrendDirection.none.obs;
  var activeTotalStores = "0 / 0".obs;
  var storesTrend = "0%".obs;
  var storesTrendDirection = TrendDirection.none.obs;
  var avgBasketSize = "0".obs;
  var basketTrend = "0%".obs;
  var basketTrendDirection = TrendDirection.none.obs;
  var unit = "UGX".obs;

  @override
  void onInit() {
    super.onInit();
    // DON'T fetch data here - let the UI trigger it when ready
    debugPrint('MonKpiOverviewController: onInit - NOT fetching data yet');

    // Set up listeners for date changes
    ever(dateController.selectedRange, (_) {
      if (isInitialized.value) {
        fetchKpiData();
      }
    });

    ever(dateController.customRange, (_) {
      if (isInitialized.value) {
        fetchKpiData();
      }
    });
  }

  /// Call this manually when the UI is ready
  Future<void> initializeData() async {
    if (isInitialized.value) {
      debugPrint('MonKpiOverviewController: Already initialized, skipping');
      return;
    }

    debugPrint('MonKpiOverviewController: Performing first data fetch');
    await fetchKpiData();
    isInitialized.value = true;
  }

  Future<void> fetchKpiData() async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final db = await dbHelper.database;
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      DateTime prevStartDate;
      DateTime prevEndDate;

      final range = dateController.selectedRange.value;
      final customRange = dateController.customRange.value;

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
            prevStartDate = startDate.subtract(const Duration(days: 7));
            prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          }
          break;
        default:
          startDate = now.subtract(const Duration(days: 6));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          prevStartDate = startDate.subtract(const Duration(days: 7));
          prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          break;
      }

      final startMillis = startDate.millisecondsSinceEpoch;
      final endMillis = endDate.millisecondsSinceEpoch;
      final prevStartMillis = prevStartDate.millisecondsSinceEpoch;
      final prevEndMillis = prevEndDate.millisecondsSinceEpoch;

      const salesQuery =
          'SELECT SUM(total) as total FROM (SELECT SUM(amount) as total FROM sales WHERE transactiondate BETWEEN ? AND ? GROUP BY salesId)';
      const transactionsQuery =
          'SELECT COUNT(DISTINCT salesId) as count FROM sales WHERE transactiondate BETWEEN ? AND ?';
      const activeStoresQuery =
          'SELECT COUNT(DISTINCT sourcefacility) as active FROM sales WHERE transactiondate BETWEEN ? AND ?';
      const basketQuery =
          'SELECT AVG(total) as avg FROM (SELECT SUM(amount) as total FROM sales WHERE transactiondate BETWEEN ? AND ? GROUP BY salesId)';
      const totalStoresQuery =
          'SELECT COUNT(DISTINCT name) as total FROM service_points';
      const currencyQuery = 'SELECT currency FROM sales LIMIT 1';

      // Execute all queries in parallel
      final results = await Future.wait([
        db.rawQuery(salesQuery, [startMillis, endMillis]),
        db.rawQuery(salesQuery, [prevStartMillis, prevEndMillis]),
        db.rawQuery(transactionsQuery, [startMillis, endMillis]),
        db.rawQuery(transactionsQuery, [prevStartMillis, prevEndMillis]),
        db.rawQuery(activeStoresQuery, [startMillis, endMillis]),
        db.rawQuery(activeStoresQuery, [prevStartMillis, prevEndMillis]),
        db.rawQuery(basketQuery, [startMillis, endMillis]),
        db.rawQuery(basketQuery, [prevStartMillis, prevEndMillis]),
        db.rawQuery(totalStoresQuery),
        db.rawQuery(currencyQuery),
      ]);

      final currentSales = (results[0].first['total'] as num? ?? 0.0).toDouble();
      final prevSales = (results[1].first['total'] as num? ?? 0.0).toDouble();
      final currentTransactions = results[2].first['count'] as int? ?? 0;
      final prevTransactions = results[3].first['count'] as int? ?? 0;
      final currentActiveStores = results[4].first['active'] as int? ?? 0;
      final prevActiveStores = results[5].first['active'] as int? ?? 0;
      final currentBasket = (results[6].first['avg'] as num? ?? 0.0).toDouble();
      final prevBasket = (results[7].first['avg'] as num? ?? 0.0).toDouble();
      final totalStores = results[8].first['total'] as int? ?? 0;

      String currency = 'UGX';
      if (results[9].isNotEmpty) {
        String? dbCurrency = results[9].first['currency'] as String?;
        if (dbCurrency != null) {
          currency = dbCurrency == 'Uganda Shillings' ? 'UGX' : dbCurrency;
        }
      }
      unit.value = currency;

      final compactFormatter = NumberFormat.compact();
      final fullNumberFormatter = NumberFormat('#,##0');
      final percentFormatter = NumberFormat('+#,##0.0%;-#,##0.0%');

      final salesTrendValue = prevSales > 0
          ? (currentSales - prevSales) / prevSales
          : (currentSales > 0 ? 1.0 : 0.0);
      final transactionsTrendValue = prevTransactions > 0
          ? (currentTransactions - prevTransactions) / prevTransactions
          : (currentTransactions > 0 ? 1.0 : 0.0);
      final storesTrendValue = prevActiveStores > 0
          ? (currentActiveStores - prevActiveStores) / prevActiveStores
          : (currentActiveStores > 0 ? 1.0 : 0.0);
      final basketTrendValue = prevBasket > 0
          ? (currentBasket - prevBasket) / prevBasket
          : (currentBasket > 0 ? 1.0 : 0.0);

      totalSales.value = compactFormatter.format(currentSales);
      salesTrend.value = percentFormatter.format(salesTrendValue);
      salesTrendDirection.value = salesTrendValue > 0.001
          ? TrendDirection.up
          : (salesTrendValue < -0.001 ? TrendDirection.down : TrendDirection.none);

      totalTransactions.value = fullNumberFormatter.format(currentTransactions);
      transactionsTrend.value = percentFormatter.format(transactionsTrendValue);
      transactionsTrendDirection.value = transactionsTrendValue > 0.001
          ? TrendDirection.up
          : (transactionsTrendValue < -0.001 ? TrendDirection.down : TrendDirection.none);

      activeTotalStores.value = '$currentActiveStores / $totalStores';
      storesTrend.value = percentFormatter.format(storesTrendValue);
      storesTrendDirection.value = storesTrendValue > 0.001
          ? TrendDirection.up
          : (storesTrendValue < -0.001 ? TrendDirection.down : TrendDirection.none);

      avgBasketSize.value = compactFormatter.format(currentBasket);
      basketTrend.value = percentFormatter.format(basketTrendValue);
      basketTrendDirection.value = basketTrendValue > 0.001
          ? TrendDirection.up
          : (basketTrendValue < -0.001 ? TrendDirection.down : TrendDirection.none);

    } catch (e) {
      hasError.value = true;
      print("Error fetching KPI data: $e");
    } finally {
      isLoading.value = false;
    }
  }
}
