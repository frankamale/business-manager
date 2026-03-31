import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../models/trend_direction.dart';
import '../models/store.dart';
import '../widgets/finance/date_range.dart';
import 'mon_store_controller.dart';

class MonStoreKpiTrendController extends GetxController {
  final MonStoresController storesController = Get.find();
  final dbHelper = UnifiedDatabaseHelper.instance;

  var isLoading = true.obs;
  var hasError = false.obs;

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

  // Gym-specific KPIs
  var totalWalkIns = "0".obs;
  var dailySubs = "0".obs;
  var monthlySubs = "0".obs;
  var userRole = "".obs;

  // Additional KPI modes for non-gym users
  var cashSales = "0".obs;
  var cashSalesTrend = "0%".obs;
  var cashSalesTrendDirection = TrendDirection.none.obs;

  @override
  void onInit() {
    super.onInit(); 
    _loadUserRole();
    fetchKpiTrendData();
    ever(storesController.selectedStore, (_) => fetchKpiTrendData());
    ever(storesController.selectedDateRange, (_) => fetchKpiTrendData());
    ever(storesController.customDateRange, (_) => fetchKpiTrendData());
  }

  Future<void> loadUserRole() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    userRole.value = await storage.read(key: "user_role") ?? "";
  }

  Future<void> _loadUserRole() async {
    await loadUserRole();
  }

  Future<void> fetchKpiTrendData() async {
    try {
      isLoading.value = true;
      hasError.value = false;

      if (storesController.selectedStore.value == null) {
        throw Exception("No store selected");
      }

      final db = dbHelper.database;
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;
      DateTime prevStartDate;
      DateTime prevEndDate;

      final range = storesController.selectedDateRange.value;
      final customRange = storesController.customDateRange.value;

      switch (range) {
        case DateRange.today:
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          prevStartDate = startDate.subtract(const Duration(days: 1));
          prevEndDate = DateTime(prevStartDate.year, prevStartDate.month, prevStartDate.day, 23, 59, 59);
          break;
        case DateRange.yesterday:
          startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
          endDate = DateTime(now.year, now.month, now.day).subtract(const Duration(milliseconds: 1));
          prevStartDate = startDate.subtract(const Duration(days: 1));
          prevEndDate = DateTime(prevStartDate.year, prevStartDate.month, prevStartDate.day, 23, 59, 59);
          break;
        case DateRange.last7Days:
          startDate = now.subtract(const Duration(days: 6));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          prevStartDate = startDate.subtract(const Duration(days: 7));
          prevEndDate = prevStartDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
          break;
        case DateRange.monthToDate:
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          prevStartDate = DateTime(now.year, now.month - 1, 1);
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
            prevEndDate = prevStartDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
          }
          break;
      }

      final dateFormatter = DateFormat('yyyy-MM-dd');
      final startDateStr = dateFormatter.format(startDate);
      final endDateStr = dateFormatter.format(endDate);
      final prevStartDateStr = dateFormatter.format(prevStartDate);
      final prevEndDateStr = dateFormatter.format(prevEndDate);

      final isAllStores = storesController.selectedStore.value!.id == Store.all.id;
      final storeName = storesController.selectedStore.value!.name;

      // Using new KPI table (mon_kpi_sales) for aggregated data
      final salesQuery = isAllStores
          ? 'SELECT SUM(amount1) as total FROM mon_kpi_sales WHERE kpi_id = 0 AND processing_date BETWEEN ? AND ?'
          : 'SELECT SUM(amount1) as total FROM mon_kpi_sales WHERE kpi_id = 0 AND (selling_point = ? OR selling_point IS NULL) AND processing_date BETWEEN ? AND ?';
      final transactionsQuery = isAllStores
          ? 'SELECT COUNT(*) as count FROM mon_kpi_sales WHERE kpi_id = 0 AND processing_date BETWEEN ? AND ?'
          : 'SELECT COUNT(*) as count FROM mon_kpi_sales WHERE kpi_id = 0 AND (selling_point = ? OR selling_point IS NULL) AND processing_date BETWEEN ? AND ?';
      final activeStoresQuery = isAllStores
          ? 'SELECT COUNT(DISTINCT selling_point) as active FROM mon_kpi_sales WHERE kpi_id = 0 AND processing_date BETWEEN ? AND ?'
          : 'SELECT COUNT(DISTINCT selling_point) as active FROM mon_kpi_sales WHERE kpi_id = 0 AND (selling_point = ? OR selling_point IS NULL) AND processing_date BETWEEN ? AND ?';
      final basketQuery = isAllStores
          ? 'SELECT AVG(total) FROM (SELECT SUM(amount1) as total FROM mon_kpi_sales WHERE kpi_id = 0 AND processing_date BETWEEN ? AND ? GROUP BY selling_point, processing_date, kpi)'
          : 'SELECT AVG(total) FROM (SELECT SUM(amount1) as total FROM mon_kpi_sales WHERE kpi_id = 0 AND (selling_point = ? OR selling_point IS NULL) AND processing_date BETWEEN ? AND ? GROUP BY selling_point, processing_date, kpi)';
      const totalStoresQuery = 'SELECT COUNT(DISTINCT name) as total FROM mon_service_points';
      const currencyQuery = 'SELECT currency FROM mon_kpi_sales LIMIT 1';

      // Cash sales queries (kpi_id = 1)
      final cashSalesQuery = isAllStores
          ? 'SELECT SUM(amount2) as total FROM mon_kpi_sales WHERE kpi_id = 1 AND processing_date BETWEEN ? AND ?'
          : 'SELECT SUM(amount2) as total FROM mon_kpi_sales WHERE kpi_id = 1 AND (selling_point = ? OR selling_point IS NULL) AND processing_date BETWEEN ? AND ?';

      // Gym-specific subscription queries (using kpi_id = 4 for salesperson which includes subscriptions)
      final subscriptionQuery = isAllStores
          ? 'SELECT COUNT(*) as count FROM mon_kpi_sales WHERE kpi_id = 4 AND processing_date BETWEEN ? AND ?'
          : 'SELECT COUNT(*) as count FROM mon_kpi_sales WHERE kpi_id = 4 AND (selling_point = ? OR selling_point IS NULL) AND processing_date BETWEEN ? AND ?';
      final dailySubQuery = isAllStores
          ? 'SELECT COUNT(*) as count FROM mon_kpi_sales WHERE kpi_id = 4 AND processing_date BETWEEN ? AND ?'
          : 'SELECT COUNT(*) as count FROM mon_kpi_sales WHERE kpi_id = 4 AND (selling_point = ? OR selling_point IS NULL) AND processing_date BETWEEN ? AND ?';
      final monthlySubQuery = isAllStores
          ? 'SELECT COUNT(*) as count FROM mon_kpi_sales WHERE kpi_id = 4 AND processing_date BETWEEN ? AND ?'
          : 'SELECT COUNT(*) as count FROM mon_kpi_sales WHERE kpi_id = 4 AND (selling_point = ? OR selling_point IS NULL) AND processing_date BETWEEN ? AND ?';

      final argsCurrent = isAllStores
          ? [startDateStr, endDateStr]
          : [storeName, startDateStr, endDateStr];
      final argsPrev = isAllStores
          ? [prevStartDateStr, prevEndDateStr]
          : [storeName, prevStartDateStr, prevEndDateStr];

      // print('DEBUG: Sales Query: $salesQuery, Args Current: $argsCurrent, Args Prev: $argsPrev');
      // print('DEBUG: Transactions Query: $transactionsQuery, Args Current: $argsCurrent, Args Prev: $argsPrev');
      // print('DEBUG: Active Stores Query: $activeStoresQuery, Args Current: $argsCurrent, Args Prev: $argsPrev');
      // print('DEBUG: Basket Query: $basketQuery, Args Current: $argsCurrent, Args Prev: $argsPrev');

      final currentSalesResult = await db.rawQuery(salesQuery, argsCurrent);
      final prevSalesResult = await db.rawQuery(salesQuery, argsPrev);
      final currentTransResult = await db.rawQuery(transactionsQuery, argsCurrent);
      final prevTransResult = await db.rawQuery(transactionsQuery, argsPrev);
      final currentActiveStoresResult = await db.rawQuery(activeStoresQuery, argsCurrent);
      final prevActiveStoresResult = await db.rawQuery(activeStoresQuery, argsPrev);
      final currentBasketResult = await db.rawQuery(basketQuery, argsCurrent);
      final prevBasketResult = await db.rawQuery(basketQuery, argsPrev);
      final totalStoresResult = await db.rawQuery(totalStoresQuery);
      final currencyResult = await db.rawQuery(currencyQuery);

      // Execute cash sales queries
      final currentCashSalesResult = await db.rawQuery(cashSalesQuery, argsCurrent);
      final prevCashSalesResult = await db.rawQuery(cashSalesQuery, argsPrev);

      // Execute gym-specific subscription queries
      // Using kpi_id=4 for salesperson (gym subscriptions)
      final argsCurrentWithCategory = isAllStores
          ? [startDateStr, endDateStr]
          : [storeName, startDateStr, endDateStr];
      final argsPrevWithCategory = isAllStores
          ? [prevStartDateStr, prevEndDateStr]
          : [storeName, prevStartDateStr, prevEndDateStr];
      final argsCurrentWithSubcategory = isAllStores
          ? [startDateStr, endDateStr]
          : [storeName, startDateStr, endDateStr];
      final argsPrevWithSubcategory = isAllStores
          ? [prevStartDateStr, prevEndDateStr]
          : [storeName, prevStartDateStr, prevEndDateStr];
      final argsCurrentMonthly = isAllStores
          ? [startDateStr, endDateStr]
          : [storeName, startDateStr, endDateStr];
      final argsPrevMonthly = isAllStores
          ? [prevStartDateStr, prevEndDateStr]
          : [storeName, prevStartDateStr, prevEndDateStr];

      final currentSubscriptionResult = await db.rawQuery(subscriptionQuery, argsCurrentWithCategory);
      final prevSubscriptionResult = await db.rawQuery(subscriptionQuery, argsPrevWithCategory);
      final currentDailySubResult = await db.rawQuery(dailySubQuery, argsCurrentWithSubcategory);
      final prevDailySubResult = await db.rawQuery(dailySubQuery, argsPrevWithSubcategory);
      final currentMonthlySubResult = await db.rawQuery(monthlySubQuery, argsCurrentMonthly);
      final prevMonthlySubResult = await db.rawQuery(monthlySubQuery, argsPrevMonthly);

      // print('DEBUG: Current Sales Result: $currentSalesResult');
      // print('DEBUG: Prev Sales Result: $prevSalesResult');
      // print('DEBUG: Current Transactions Result: $currentTransResult');
      // print('DEBUG: Prev Transactions Result: $prevTransResult');
      // print('DEBUG: Current Active Stores Result: $currentActiveStoresResult');
      // print('DEBUG: Prev Active Stores Result: $prevActiveStoresResult');
      // print('DEBUG: Current Basket Result: $currentBasketResult');
      // print('DEBUG: Prev Basket Result: $prevBasketResult');
      // print('DEBUG: Total Stores Result: $totalStoresResult');
      // print('DEBUG: Currency Result: $currencyResult');


      final currentSales = (currentSalesResult.first['total'] as num? ?? 0.0).toDouble();
      final prevSales = (prevSalesResult.first['total'] as num? ?? 0.0).toDouble();
      final currentTransactions = currentTransResult.first['count'] as int? ?? 0;
      final prevTransactions = prevTransResult.first['count'] as int? ?? 0;
      final currentActiveStores = currentActiveStoresResult.first['active'] as int? ?? 0;
      final prevActiveStores = prevActiveStoresResult.first['active'] as int? ?? 0;
      final currentBasket = (currentBasketResult.first['AVG(total)'] as num? ?? 0.0).toDouble();
      final prevBasket = (prevBasketResult.first['AVG(total)'] as num? ?? 0.0).toDouble();
      final totalStores = totalStoresResult.first['total'] as int? ?? 0;
      var currency = currencyResult.isNotEmpty
          ? currencyResult.first['currency'] as String? ?? 'UGX'
          : 'UGX';

      if (currency.toLowerCase() == 'uganda shillings') {
        currency = 'UGX';
      }

      unit.value = currency;

      // Extract gym-specific subscription values
      final currentSubscriptions = currentSubscriptionResult.first['count'] as int? ?? 0;
      final prevSubscriptions = prevSubscriptionResult.first['count'] as int? ?? 0;
      final currentDailySubs = currentDailySubResult.first['count'] as int? ?? 0;
      final prevDailySubs = prevDailySubResult.first['count'] as int? ?? 0;
      final currentMonthlySubs = currentMonthlySubResult.first['count'] as int? ?? 0;
      final prevMonthlySubs = prevMonthlySubResult.first['count'] as int? ?? 0;

      // Extract cash sales values
      final currentCashSales = (currentCashSalesResult.first['total'] as num? ?? 0.0).toDouble();
      final prevCashSales = (prevCashSalesResult.first['total'] as num? ?? 0.0).toDouble();

      // Update gym-specific observables
      totalWalkIns.value = currentSubscriptions.toString();
      dailySubs.value = currentDailySubs.toString();
      monthlySubs.value = currentMonthlySubs.toString();

      final compactFormatter = NumberFormat.compact();
      final fullNumberFormatter = NumberFormat('#,##0');

      const double epsilon = 0.01;
      final salesTrendValue = (currentSales - prevSales) / (prevSales.abs() + epsilon);
      final transactionsTrendValue = (currentTransactions - prevTransactions) / (prevTransactions.abs() + epsilon);
      final storesTrendValue = (currentActiveStores - prevActiveStores) / (prevActiveStores.abs() + epsilon);
      final basketTrendValue = (currentBasket - prevBasket) / (prevBasket.abs() + epsilon);
      final cashSalesTrendValue = (currentCashSales - prevCashSales) / (prevCashSales.abs() + epsilon);

      // Gym-specific trend calculations
      final walkInsTrendValue = (currentSubscriptions - prevSubscriptions) / (prevSubscriptions.abs() + epsilon);
      final dailySubsTrendValue = (currentDailySubs - prevDailySubs) / (prevDailySubs.abs() + epsilon);
      final monthlySubsTrendValue = (currentMonthlySubs - prevMonthlySubs) / (prevMonthlySubs.abs() + epsilon);

      // Helper to format trend as percentage (cap at 100%)
      String formatTrendPercent(double value) {
        final percent = (value * 100).abs();
        final cappedPercent = percent > 100 ? 100 : percent;
        if (cappedPercent >= 100) {
          return '${cappedPercent.toStringAsFixed(0)}%';
        } else if (cappedPercent >= 10) {
          return '${cappedPercent.toStringAsFixed(0)}%';
        } else {
          return '${cappedPercent.toStringAsFixed(1)}%';
        }
      }

      totalSales.value = compactFormatter.format(currentSales);
      salesTrend.value = formatTrendPercent(salesTrendValue);
      salesTrendDirection.value = salesTrendValue > 0.01
          ? TrendDirection.up
          : (salesTrendValue < -0.01 ? TrendDirection.down : TrendDirection.none);

      totalTransactions.value = fullNumberFormatter.format(currentTransactions);
      transactionsTrend.value = formatTrendPercent(transactionsTrendValue);
      transactionsTrendDirection.value = transactionsTrendValue > 0.01
          ? TrendDirection.up
          : (transactionsTrendValue < -0.01 ? TrendDirection.down : TrendDirection.none);

      activeTotalStores.value = '$currentActiveStores / $totalStores';
      storesTrend.value = formatTrendPercent(storesTrendValue);
      storesTrendDirection.value = storesTrendValue > 0.01
          ? TrendDirection.up
          : (storesTrendValue < -0.01 ? TrendDirection.down : TrendDirection.none);

      avgBasketSize.value = compactFormatter.format(currentBasket);
      basketTrend.value = formatTrendPercent(basketTrendValue);
      basketTrendDirection.value = basketTrendValue > 0.01
          ? TrendDirection.up
          : (basketTrendValue < -0.01 ? TrendDirection.down : TrendDirection.none);

      // Gym-specific KPI trends
      final isGym = userRole.value.toLowerCase().contains('fg');
      if (isGym) {
        // For gym, use subscription counts
        transactionsTrend.value = formatTrendPercent(walkInsTrendValue);
        transactionsTrendDirection.value = walkInsTrendValue > 0.01
            ? TrendDirection.up
            : (walkInsTrendValue < -0.01 ? TrendDirection.down : TrendDirection.none);
        
        basketTrend.value = formatTrendPercent(dailySubsTrendValue);
        basketTrendDirection.value = dailySubsTrendValue > 0.01
            ? TrendDirection.up
            : (dailySubsTrendValue < -0.01 ? TrendDirection.down : TrendDirection.none);
      }

      // Cash sales trends
      cashSales.value = compactFormatter.format(currentCashSales);
      cashSalesTrend.value = formatTrendPercent(cashSalesTrendValue);
      cashSalesTrendDirection.value = cashSalesTrendValue > 0.01
          ? TrendDirection.up
          : (cashSalesTrendValue < -0.01 ? TrendDirection.down : TrendDirection.none);

      // print('DEBUG: Final KPI Values - Total Sales: ${totalSales.value}, Transactions: ${totalTransactions.value}, Active Stores: ${activeTotalStores.value}, Avg Basket: ${avgBasketSize.value}');
      // print('DEBUG: Trends - Sales: ${salesTrend.value}, Transactions: ${transactionsTrend.value}, Stores: ${storesTrend.value}, Basket: ${basketTrend.value}');
    } catch (e) {
      hasError.value = true;
      // print("Error fetching store KPI trend data: $e");
      totalSales.value = "-";
      totalTransactions.value = "-";
      activeTotalStores.value = "- / -";
      avgBasketSize.value = "-";
      cashSales.value = "-";
      cashSalesTrend.value = "0%";
      cashSalesTrendDirection.value = TrendDirection.none;
      salesTrend.value = "0%";
      transactionsTrend.value = "0%";
      storesTrend.value = "0%";
      basketTrend.value = "0%";
      salesTrendDirection.value = TrendDirection.none;
      transactionsTrendDirection.value = TrendDirection.none;
      storesTrendDirection.value = TrendDirection.none;
      basketTrendDirection.value = TrendDirection.none;
    } finally {
      isLoading.value = false;
    }
  }
}