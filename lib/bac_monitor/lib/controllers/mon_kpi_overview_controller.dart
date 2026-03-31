
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../models/trend_direction.dart';
import '../widgets/finance/date_range.dart'; 
import 'mon_dashboard_controller.dart';

class MonKpiOverviewController extends GetxController {
  final MonDashboardController dateController = Get.find();
  final dbHelper = UnifiedDatabaseHelper.instance;

  var isLoading = true.obs;
  var hasError = false.obs;
  var isInitialized = false.obs; 
  var totalSales = "0".obs;
  var salesTrend = "0%".obs;
  var salesTrendDirection = TrendDirection.none.obs;
  var totalTransactions = "0".obs;
  var subscriptionCount = "0".obs;
  var transactionsTrend = "0%".obs;
  var transactionsTrendDirection = TrendDirection.none.obs;
  var activeTotalStores = "0 / 0".obs;
  var activeMembers = "0".obs;
  var storesTrend = "0%".obs;
  var storesTrendDirection = TrendDirection.none.obs;
  var avgBasketSize = "0".obs;
  var basketTrend = "0%".obs;
  var basketTrendDirection = TrendDirection.none.obs;
  var unit = "UGX".obs;
 
  // Mini KPI data for the new UI
  var cashSales = "0".obs;
  var creditSales = "0".obs;
  var cashSalesTrend = "0%".obs;
  var creditSalesTrend = "0%".obs;
  var cashSalesTrendDirection = TrendDirection.none.obs;
  var creditSalesTrendDirection = TrendDirection.none.obs;

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

  // Inside MonKpiOverviewController
  var userRole = "".obs;

  Future<void> loadUserRole() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    userRole.value = await storage.read(key: "user_role") ?? "";
  }

  /// Call this manually when the UI is ready
  Future<void> initializeData() async {
    if (isInitialized.value) {
      debugPrint('MonKpiOverviewController: Already initialized, skipping');
      return;
    }

    debugPrint('MonKpiOverviewController: Performing first data fetch');
    
    // Load user role first before fetching data
    await loadUserRole();
    debugPrint('User role loaded: ${userRole.value}');
    
    await fetchKpiData();
    isInitialized.value = true;
  }

  Future<void> fetchKpiData() async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final db = dbHelper.database;
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
          prevEndDate = DateTime(
            now.year,
            now.month,
            1,
          ).subtract(const Duration(milliseconds: 1));
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
            startDate = DateTime(
              startDate.year,
              startDate.month,
              startDate.day,
            );
            prevStartDate = startDate.subtract(const Duration(days: 7));
            prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          }
          break;
      }

      // Format dates for KPI queries (yyyy-MM-dd)
      // NOTE: processing_date stores date-only strings (no time component)
      // Use date-only comparisons for accurate filtering
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final startDateStr = dateFormatter.format(startDate);
      final endDateStr = dateFormatter.format(endDate);
      final prevStartDateStr = dateFormatter.format(prevStartDate);
      final prevEndDateStr = dateFormatter.format(prevEndDate);

      // Query the new mon_kpi_sales table
      // KPI ID 0 = All Transactions (total sales)
      // KPI ID 1 = Cash Transactions
      // KPI ID 5 = Profit
      
      // Query for total sales (kpiId=0, sum of amount2 = transaction value)
      const salesQuery = '''
        SELECT SUM(amount1) as total, SUM(quantity) as qty 
        FROM mon_kpi_sales 
        WHERE kpi_id = 0 AND processing_date BETWEEN ? AND ?
      ''';
      
      // Query for previous period sales
      const prevSalesQuery = '''
        SELECT SUM(amount1) as total, SUM(quantity) as qty 
        FROM mon_kpi_sales 
        WHERE kpi_id = 0 AND processing_date BETWEEN ? AND ?
      ''';

      // Query for total transactions (sum of quantity for kpiId=0)
      const transactionsQuery = '''
        SELECT SUM(quantity) as count 
        FROM mon_kpi_sales 
        WHERE kpi_id = 0 AND processing_date BETWEEN ? AND ?
      ''';

      // Query for subscription count (for gym mode - kpiId=7 for stock category "Subscription")
      const subscriptionQuery = '''
        SELECT SUM(quantity) as count 
        FROM mon_kpi_sales 
        WHERE kpi_id = 7 AND kpi = "Subscription" AND processing_date BETWEEN ? AND ?
      ''';
      const prevSubscriptionQuery = '''
        SELECT SUM(quantity) as count 
        FROM mon_kpi_sales 
        WHERE kpi_id = 7 AND kpi = "Subscription" AND processing_date BETWEEN ? AND ?
      ''';

      // Query for inventory sales - non-subscription items (kpiId=7, not Subscription)
      const inventorySalesQuery = '''
        SELECT SUM(amount1) as total 
        FROM mon_kpi_sales 
        WHERE kpi_id = 7 AND kpi != "Subscription" AND processing_date BETWEEN ? AND ?
      ''';
      const prevInventorySalesQuery = '''
        SELECT SUM(amount1) as total 
        FROM mon_kpi_sales 
        WHERE kpi_id = 7 AND kpi != "Subscription" AND processing_date BETWEEN ? AND ?
      ''';

      // Query for subscription revenue (kpiId=7, kpi="Subscription")
      const subscriptionRevenueQuery = '''
        SELECT SUM(amount1) as total 
        FROM mon_kpi_sales 
        WHERE kpi_id = 7 AND kpi = "Subscription" AND processing_date BETWEEN ? AND ?
      '''; 
      const prevSubscriptionRevenueQuery = ''' 
        SELECT SUM(amount1) as total 
        FROM mon_kpi_sales 
        WHERE kpi_id = 7 AND kpi = "Subscription" AND processing_date BETWEEN ? AND ?
      ''';

      // Query for active stores (distinct selling_point)
      const activeStoresQuery = '''
        SELECT COUNT(DISTINCT selling_point) as active 
        FROM mon_kpi_sales 
        WHERE processing_date BETWEEN ? AND ?
      ''';

      // Query for avg basket size (total amount / distinct days or transactions)
      const basketQuery = '''
        SELECT AVG(daily_total) as avg FROM (
          SELECT processing_date, SUM(amount2) as daily_total 
          FROM mon_kpi_sales 
          WHERE kpi_id = 0 AND processing_date BETWEEN ? AND ?
          GROUP BY processing_date
        )
      ''';

      const totalStoresQuery = 'SELECT COUNT(DISTINCT name) as total FROM mon_service_points';
      const currencyQuery = 'SELECT currency FROM mon_kpi_sales LIMIT 1';

      // Query for cash sales (kpiId=1 based on actual data)
      // amount1 = amount actually paid (cash received)
      const cashSalesQuery = '''
        SELECT SUM(amount1) as total
        FROM mon_kpi_sales
        WHERE kpi_id = 1 AND processing_date BETWEEN ? AND ?
      ''';
      const prevCashSalesQuery = '''
        SELECT SUM(amount1) as total
        FROM mon_kpi_sales
        WHERE kpi_id = 1 AND processing_date BETWEEN ? AND ?
      ''';

      // Query for pending payment sales (kpiId=2 based on actual data)
      const creditSalesQuery = '''
        SELECT SUM(amount2 - amount1) as total
        FROM mon_kpi_sales
        WHERE kpi_id = 2 AND processing_date BETWEEN ? AND ?
      ''';
      const prevCreditSalesQuery = '''
        SELECT SUM(amount2 - amount1) as total
        FROM mon_kpi_sales
        WHERE kpi_id = 2 AND processing_date BETWEEN ? AND ?
      ''';

      final customerQuery = 'SELECT COUNT(*) as count FROM customers WHERE statusid == ?';

      // Execute all queries in parallel
      final results = await Future.wait([
        db.rawQuery(salesQuery, [startDateStr, endDateStr]),
        db.rawQuery(prevSalesQuery, [prevStartDateStr, prevEndDateStr]),
        db.rawQuery(transactionsQuery, [startDateStr, endDateStr]),
        db.rawQuery(transactionsQuery, [prevStartDateStr, prevEndDateStr]),
        db.rawQuery(activeStoresQuery, [startDateStr, endDateStr]),
        db.rawQuery(activeStoresQuery, [prevStartDateStr, prevEndDateStr]),
        db.rawQuery(basketQuery, [startDateStr, endDateStr]),
        db.rawQuery(basketQuery, [prevStartDateStr, prevEndDateStr]),
        db.rawQuery(totalStoresQuery),
        db.rawQuery(currencyQuery),
        db.rawQuery(customerQuery, ["00000000-0000-0000-0000-000000000000"]),
        db.rawQuery(subscriptionQuery, [startDateStr, endDateStr]),
        db.rawQuery(prevSubscriptionQuery, [prevStartDateStr, prevEndDateStr]),
        db.rawQuery(inventorySalesQuery, [startDateStr, endDateStr]),
        db.rawQuery(prevInventorySalesQuery, [prevStartDateStr, prevEndDateStr]),
        db.rawQuery(subscriptionRevenueQuery, [startDateStr, endDateStr]),
        db.rawQuery(prevSubscriptionRevenueQuery, [prevStartDateStr, prevEndDateStr]),
        db.rawQuery(cashSalesQuery, [startDateStr, endDateStr]),
        db.rawQuery(prevCashSalesQuery, [prevStartDateStr, prevEndDateStr]),
        db.rawQuery(creditSalesQuery, [startDateStr, endDateStr]),
        db.rawQuery(prevCreditSalesQuery, [prevStartDateStr, prevEndDateStr]),
      ]);

      // Safe access to results with bounds checking
      // Expected 21 results (indices 0-20)
      if (results.length < 21) {
        debugPrint('ERROR: Expected 21 results, got ${results.length}');
        for (int i = 0; i < results.length; i++) {
          final row = results[i].isEmpty ? "empty" : results[i].first;
          debugPrint('results[$i]: $row');
        }
        // Continue with available data - use safe access with null coalescing
        // Index 17: cashSalesQuery (current), Index 18: prevCashSalesQuery (prev)
        // Index 19: creditSalesQuery (current), Index 20: prevCreditSalesQuery (prev)
        final currentCashSales = results.length > 17 && results[17].isNotEmpty
            ? (results[17].first['total'] as num? ?? 0.0).toDouble()
            : 0.0;
        final prevCashSales = results.length > 18 && results[18].isNotEmpty
            ? (results[18].first['total'] as num? ?? 0.0).toDouble()
            : 0.0;
        final currentCreditSales = results.length > 19 && results[19].isNotEmpty
            ? (results[19].first['total'] as num? ?? 0.0).toDouble()
            : 0.0;
        final prevCreditSales = results.length > 20 && results[20].isNotEmpty
            ? (results[20].first['total'] as num? ?? 0.0).toDouble()
            : 0.0;
        
        // Debug output for the values
        debugPrint('Safe currentCashSales: $currentCashSales');
        debugPrint('Safe prevCashSales: $prevCashSales');
        debugPrint('Safe currentCreditSales: $currentCreditSales');
        debugPrint('Safe prevCreditSales: $prevCreditSales');
        
        // Process with what we have - set a flag to skip rest
        isLoading.value = false;
        hasError.value = true;
        return;
      }

      // Original processing - continue below
      final currentSales = (results[0].first['total'] as num? ?? 0.0).toDouble();
      final prevSales = (results[1].first['total'] as num? ?? 0.0).toDouble();
      final currentTransactions = results[2].first['count'] as int? ?? 0;
      final prevTransactions = results[3].first['count'] as int? ?? 0;
      final currentActiveStores = results[4].first['active'] as int? ?? 0;
      final prevActiveStores = results[5].first['active'] as int? ?? 0;
      final currentBasket = (results[6].first['avg'] as num? ?? 0.0).toDouble();
      final prevBasket = (results[7].first['avg'] as num? ?? 0.0).toDouble();
      final totalStores = results[8].first['total'] as int? ?? 0;

      // Subscription counts for gym mode
      final currentSubscriptions = results[11].first['count'] as int? ?? 0;
      final prevSubscriptions = results[12].first['count'] as int? ?? 0;

      // Inventory sales for gym mode (non-subscription transactions)
      final currentInventorySales = (results[13].first['total'] as num? ?? 0.0).toDouble();
      final prevInventorySales = (results[14].first['total'] as num? ?? 0.0).toDouble();

      // Subscription revenue for gym mode
      // Index 15: subscriptionRevenueQuery (current), Index 16: prevSubscriptionRevenueQuery (prev)
      final currentSubscriptionRevenue = (results[15].first['total'] as num? ?? 0.0).toDouble();
      final prevSubscriptionRevenue = (results[16].first['total'] as num? ?? 0.0).toDouble();

      // Cash and Credit sales for the new UI - with bounds checking
      // Index 17: cashSalesQuery (current), Index 18: prevCashSalesQuery (prev)
      // Index 19: creditSalesQuery (current), Index 20: prevCreditSalesQuery (prev)
      final currentCashSales = results[17].isNotEmpty
          ? (results[17].first['total'] as num? ?? 0.0).toDouble()
          : 0.0;
      final prevCashSales = results[18].isNotEmpty
          ? (results[18].first['total'] as num? ?? 0.0).toDouble()
          : 0.0;
      final currentCreditSales = results[19].isNotEmpty
          ? (results[19].first['total'] as num? ?? 0.0).toDouble()
          : 0.0;
      final prevCreditSales = results[20].isNotEmpty
          ? (results[20].first['total'] as num? ?? 0.0).toDouble()
          : 0.0;

      // Debug prints
      debugPrint('Current Sales: $currentSales');
      debugPrint('Current Cash Sales: $currentCashSales');
      debugPrint('Current Credit Sales: $currentCreditSales');
      debugPrint('Date range: $startDateStr to $endDateStr');

      // Check if user is gym (role contains 'fg')
      final isGym = userRole.value.toLowerCase().contains('fg');

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
      final storesTrendValue = prevActiveStores > 0
          ? (currentActiveStores - prevActiveStores) / prevActiveStores
          : (currentActiveStores > 0 ? 1.0 : 0.0);
      final basketTrendValue = prevBasket > 0
          ? (currentBasket - prevBasket) / prevBasket
          : (currentBasket > 0 ? 1.0 : 0.0);

      final customerCount = results[10].first['count'] as int? ?? 0;
      print(customerCount);
      final totalCustomers = fullNumberFormatter.format(customerCount);

      // Store subscription count
      subscriptionCount.value = fullNumberFormatter.format(currentSubscriptions);

      // Calculate transactions trend (use subscription data for gym mode)
      final displayTransactions = isGym ? currentSubscriptions : currentTransactions;
      final prevDisplayTransactions = isGym ? prevSubscriptions : prevTransactions;
      final transactionsTrendValue = prevDisplayTransactions > 0
          ? (displayTransactions - prevDisplayTransactions) / prevDisplayTransactions
          : (displayTransactions > 0 ? 1.0 : 0.0);

      totalSales.value = compactFormatter.format(currentSales);
      salesTrend.value = percentFormatter.format(salesTrendValue);
      salesTrendDirection.value = salesTrendValue > 0.001
          ? TrendDirection.up
          : (salesTrendValue < -0.001
          ? TrendDirection.down
          : TrendDirection.none);

      totalTransactions.value = fullNumberFormatter.format(displayTransactions);
      transactionsTrend.value = percentFormatter.format(transactionsTrendValue);
      transactionsTrendDirection.value = transactionsTrendValue > 0.001
          ? TrendDirection.up
          : (transactionsTrendValue < -0.001
          ? TrendDirection.down
          : TrendDirection.none);

      // For gym mode: use inventory sales instead of avg basket size
      final displayBasket = isGym ? currentInventorySales : currentBasket;
      final prevDisplayBasket = isGym ? prevInventorySales : prevBasket;
      final displayBasketTrendValue = prevDisplayBasket > 0
          ? (displayBasket - prevDisplayBasket) / prevDisplayBasket
          : (displayBasket > 0 ? 1.0 : 0.0);

      // For gym mode: use subscription revenue instead of customer count
      final displayActiveMembers = isGym
          ? compactFormatter.format(currentSubscriptionRevenue)
          : "$totalCustomers";

      activeMembers.value = displayActiveMembers;
      print("Total customers $totalCustomers");
      avgBasketSize.value = compactFormatter.format(displayBasket);
      basketTrend.value = percentFormatter.format(displayBasketTrendValue);
      basketTrendDirection.value = displayBasketTrendValue > 0.001
          ? TrendDirection.up
          : (displayBasketTrendValue < -0.001
          ? TrendDirection.down
          : TrendDirection.none);

      // Process cash and credit sales for mini KPIs
      cashSales.value = compactFormatter.format(currentCashSales);
      creditSales.value = compactFormatter.format(currentCreditSales);

      // Calculate trends for cash and credit
      final cashTrendValue = prevCashSales > 0
          ? (currentCashSales - prevCashSales) / prevCashSales
          : (currentCashSales > 0 ? 1.0 : 0.0);
      final creditTrendValue = prevCreditSales > 0
          ? (currentCreditSales - prevCreditSales) / prevCreditSales
          : (currentCreditSales > 0 ? 1.0 : 0.0);

      cashSalesTrend.value = percentFormatter.format(cashTrendValue);
      cashSalesTrendDirection.value = cashTrendValue > 0.001
          ? TrendDirection.up
          : (cashTrendValue < -0.001
          ? TrendDirection.down
          : TrendDirection.none);

      creditSalesTrend.value = percentFormatter.format(creditTrendValue);
      creditSalesTrendDirection.value = creditTrendValue > 0.001
          ? TrendDirection.up
          : (creditTrendValue < -0.001
          ? TrendDirection.down
          : TrendDirection.none);
    } catch (e) {
      hasError.value = true;
      debugPrint("Error fetching KPI data: $e");
      // Print stack trace for better debugging
      debugPrintStack(stackTrace: StackTrace.current);
    } finally {
      isLoading.value = false;
    }
  }
}
