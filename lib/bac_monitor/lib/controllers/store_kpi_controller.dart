import 'package:bac_monitor/controllers/store_controller.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/trend_direction.dart';
import '../../db/db_helper.dart';
import '../../widgets/finance/date_range.dart';
import '../models/store.dart';

class StoreKpiTrendController extends GetxController {
  final StoresController storesController = Get.find();
  final dbHelper = DatabaseHelper();

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

  @override
  void onInit() {
    super.onInit(); 
    fetchKpiTrendData();
    ever(storesController.selectedStore, (_) => fetchKpiTrendData());
    ever(storesController.selectedDateRange, (_) => fetchKpiTrendData());
    ever(storesController.customDateRange, (_) => fetchKpiTrendData());
  }

  Future<void> fetchKpiTrendData() async {
    try {
      isLoading.value = true;
      hasError.value = false;

      if (storesController.selectedStore.value == null) {
        throw Exception("No store selected");
      }

      final db = await dbHelper.database;
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

      final startMillis = startDate.millisecondsSinceEpoch;
      final endMillis = endDate.millisecondsSinceEpoch;
      final prevStartMillis = prevStartDate.millisecondsSinceEpoch;
      final prevEndMillis = prevEndDate.millisecondsSinceEpoch;

      final isAllStores = storesController.selectedStore.value!.id == Store.all.id;
      final storeName = storesController.selectedStore.value!.name;

      print('DEBUG: Selected store: ${storesController.selectedStore.value!.name}, isAllStores: $isAllStores, storeName: $storeName');
      if (isAllStores) {
        print('DEBUG: Filtering disabled - querying all stores (no sourcefacility filter)');
      } else {
        print('DEBUG: Filtering enabled - querying only for sourcefacility = "$storeName"');
      }

      final salesQuery = isAllStores
          ? 'SELECT SUM(amount) as total FROM sales WHERE transactiondate BETWEEN ? AND ?'
          : 'SELECT SUM(amount) as total FROM sales WHERE sourcefacility = ? AND transactiondate BETWEEN ? AND ?';
      final transactionsQuery = isAllStores
          ? 'SELECT COUNT(DISTINCT salesId) as count FROM sales WHERE transactiondate BETWEEN ? AND ?'
          : 'SELECT COUNT(DISTINCT salesId) as count FROM sales WHERE sourcefacility = ? AND transactiondate BETWEEN ? AND ?';
      final activeStoresQuery = isAllStores
          ? 'SELECT COUNT(DISTINCT sourcefacility) as active FROM sales WHERE transactiondate BETWEEN ? AND ?'
          : 'SELECT COUNT(DISTINCT sourcefacility) as active FROM sales WHERE sourcefacility = ? AND transactiondate BETWEEN ? AND ?';
      final basketQuery = isAllStores
          ? 'SELECT AVG(total) FROM (SELECT SUM(amount) as total FROM sales WHERE transactiondate BETWEEN ? AND ? GROUP BY salesId)'
          : 'SELECT AVG(total) FROM (SELECT SUM(amount) as total FROM sales WHERE sourcefacility = ? AND transactiondate BETWEEN ? AND ? GROUP BY salesId)';
      const totalStoresQuery = 'SELECT COUNT(DISTINCT name) as total FROM service_points';
      const currencyQuery = 'SELECT currency FROM sales LIMIT 1';

      final argsCurrent = isAllStores
          ? [startMillis, endMillis]
          : [storeName, startMillis, endMillis];
      final argsPrev = isAllStores
          ? [prevStartMillis, prevEndMillis]
          : [storeName, prevStartMillis, prevEndMillis];

      print('DEBUG: Sales Query: $salesQuery, Args Current: $argsCurrent, Args Prev: $argsPrev');
      print('DEBUG: Transactions Query: $transactionsQuery, Args Current: $argsCurrent, Args Prev: $argsPrev');
      print('DEBUG: Active Stores Query: $activeStoresQuery, Args Current: $argsCurrent, Args Prev: $argsPrev');
      print('DEBUG: Basket Query: $basketQuery, Args Current: $argsCurrent, Args Prev: $argsPrev');

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

      print('DEBUG: Current Sales Result: $currentSalesResult');
      print('DEBUG: Prev Sales Result: $prevSalesResult');
      print('DEBUG: Current Transactions Result: $currentTransResult');
      print('DEBUG: Prev Transactions Result: $prevTransResult');
      print('DEBUG: Current Active Stores Result: $currentActiveStoresResult');
      print('DEBUG: Prev Active Stores Result: $prevActiveStoresResult');
      print('DEBUG: Current Basket Result: $currentBasketResult');
      print('DEBUG: Prev Basket Result: $prevBasketResult');
      print('DEBUG: Total Stores Result: $totalStoresResult');
      print('DEBUG: Currency Result: $currencyResult');


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

      final compactFormatter = NumberFormat.compact();
      final fullNumberFormatter = NumberFormat('#,##0');
      final percentFormatter = NumberFormat.compact();

      const double epsilon = 0.01;
      final salesTrendValue = (currentSales - prevSales) / (prevSales.abs() + epsilon);
      final transactionsTrendValue = (currentTransactions - prevTransactions) / (prevTransactions.abs() + epsilon);
      final storesTrendValue = (currentActiveStores - prevActiveStores) / (prevActiveStores.abs() + epsilon);
      final basketTrendValue = (currentBasket - prevBasket) / (prevBasket.abs() + epsilon);

      totalSales.value = compactFormatter.format(currentSales);
      salesTrend.value = percentFormatter.format(salesTrendValue);
      salesTrendDirection.value = salesTrendValue > 0.01
          ? TrendDirection.up
          : (salesTrendValue < -0.01 ? TrendDirection.down : TrendDirection.none);

      totalTransactions.value = fullNumberFormatter.format(currentTransactions);
      transactionsTrend.value = percentFormatter.format(transactionsTrendValue);
      transactionsTrendDirection.value = transactionsTrendValue > 0.01
          ? TrendDirection.up
          : (transactionsTrendValue < -0.01 ? TrendDirection.down : TrendDirection.none);

      activeTotalStores.value = '$currentActiveStores / $totalStores';
      storesTrend.value = percentFormatter.format(storesTrendValue);
      storesTrendDirection.value = storesTrendValue > 0.01
          ? TrendDirection.up
          : (storesTrendValue < -0.01 ? TrendDirection.down : TrendDirection.none);

      avgBasketSize.value = compactFormatter.format(currentBasket);
      basketTrend.value = percentFormatter.format(basketTrendValue);
      basketTrendDirection.value = basketTrendValue > 0.01
          ? TrendDirection.up
          : (basketTrendValue < -0.01 ? TrendDirection.down : TrendDirection.none);

      print('DEBUG: Final KPI Values - Total Sales: ${totalSales.value}, Transactions: ${totalTransactions.value}, Active Stores: ${activeTotalStores.value}, Avg Basket: ${avgBasketSize.value}');
      print('DEBUG: Trends - Sales: ${salesTrend.value}, Transactions: ${transactionsTrend.value}, Stores: ${storesTrend.value}, Basket: ${basketTrend.value}');
    } catch (e) {
      hasError.value = true;
      print("Error fetching store KPI trend data: $e");
      totalSales.value = "-";
      totalTransactions.value = "-";
      activeTotalStores.value = "- / -";
      avgBasketSize.value = "-";
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