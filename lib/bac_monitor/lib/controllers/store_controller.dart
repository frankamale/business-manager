
import 'package:bac_pos/bac_monitor/lib/controllers/store_kpi_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/dashboard.dart';
import '../models/hourly_customer_traffic.dart';
import '../models/product.dart';
import '../models/store.dart';
import '../db/db_helper.dart';
import '../widgets/finance/date_range.dart';

class StoresController extends GetxController {
  final dbHelper = DatabaseHelper();

  var isLoading = true.obs;
  var isFetchingKpisAndCharts = true.obs;
  var storeList = <Store>[].obs;
  var selectedStore = Rxn<Store>();
  var selectedDateRange = DateRange.last7Days.obs;
  var customDateRange = Rxn<DateTimeRange>();
  var salesDataPoints = <SalesDataPoint>[].obs;
  var aggregationType = 'daily'.obs;
  var hourlyTrafficData = <HourlyTraffic>[].obs;
  var topSellingProducts = <TopProduct>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchAllStores();
  }

  Future<void> _fetchSalesDataForChart() async {
    try {
      final db = await dbHelper.database;
      final range = _getDateRange();
      final storeId = selectedStore.value!.id;
      final isAllStores = storeId == Store.all.id;

      final startDate = range.start;
      final endDate = range.end;
      final days = endDate.difference(startDate).inDays;

      if (days <= 1)
        aggregationType.value = 'hourly';
      else if (days <= 7)
        aggregationType.value = 'daily';
      else if (days <= 30)
        aggregationType.value = 'weekly';
      else if (days <= 90)
        aggregationType.value = 'monthly';
      else
        aggregationType.value = 'quarterly';

      final Map<String, double> salesByDate = {};
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final hourlyFormatter = DateFormat('yyyy-MM-dd HH:00:00');

      if (aggregationType.value == 'hourly') {
        for (int i = 0; i < 24; i += 3) {
          final hourDate = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
            i,
          );
          salesByDate[hourlyFormatter.format(hourDate)] = 0.0;
        }
      } else if (aggregationType.value == 'daily') {
        for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
          final dayDate = startDate.add(Duration(days: i));
          salesByDate[dateFormatter.format(dayDate)] = 0.0;
        }
      } else if (aggregationType.value == 'weekly') {
        final startWeek = _getWeekNumber(startDate);
        final endWeek = _getWeekNumber(endDate);
        for (int week = startWeek; week <= endWeek; week++) {
          final weekDate = _weekToDate(startDate.year, week);
          salesByDate[dateFormatter.format(weekDate)] = 0.0;
        }
      } else if (aggregationType.value == 'monthly') {
        var currentMonth = DateTime(startDate.year, startDate.month, 1);
        while (currentMonth.isBefore(endDate) ||
            currentMonth.isAtSameMomentAs(endDate)) {
          salesByDate[dateFormatter.format(currentMonth)] = 0.0;
          currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
        }
      } else if (aggregationType.value == 'quarterly') {
        var currentQuarter = DateTime(
          startDate.year,
          ((startDate.month - 1) ~/ 3) * 3 + 1,
          1,
        );
        while (currentQuarter.isBefore(endDate) ||
            currentQuarter.isAtSameMomentAs(endDate)) {
          salesByDate[dateFormatter.format(currentQuarter)] = 0.0;
          currentQuarter = DateTime(
            currentQuarter.year,
            currentQuarter.month + 3,
            1,
          );
        }
      }

      final startMillis = startDate.millisecondsSinceEpoch;
      final endMillis = endDate.millisecondsSinceEpoch;
      String dateGroupClause;

      if (aggregationType.value == 'hourly') {
        dateGroupClause =
            "strftime('%Y-%m-%d ', datetime(transactiondate / 1000, 'unixepoch', 'localtime')) || printf('%02d:00:00', (CAST(strftime('%H', datetime(transactiondate / 1000, 'unixepoch', 'localtime')) AS INTEGER) / 3 * 3))";
      } else if (aggregationType.value == 'daily') {
        dateGroupClause =
            "strftime('%Y-%m-%d', datetime(transactiondate / 1000, 'unixepoch', 'localtime'))";
      } else if (aggregationType.value == 'weekly') {
        dateGroupClause =
            "strftime('%Y-%m-%d', datetime(transactiondate / 1000, 'unixepoch', 'localtime', 'weekday 1', '-7 days'))";
      } else if (aggregationType.value == 'monthly') {
        dateGroupClause =
            "strftime('%Y-%m-01', datetime(transactiondate / 1000, 'unixepoch', 'localtime'))";
      } else if (aggregationType.value == 'quarterly') {
        dateGroupClause =
            "strftime('%Y-', datetime(transactiondate / 1000, 'unixepoch', 'localtime')) || printf('%02d-01', ((CAST(strftime('%m', datetime(transactiondate / 1000, 'unixepoch', 'localtime')) AS INTEGER) - 1) / 3 * 3 + 1))";
      } else {
        dateGroupClause =
            "strftime('%Y-%m-%d', datetime(transactiondate / 1000, 'unixepoch', 'localtime'))";
        aggregationType.value = 'daily';
      }

      final whereClause = isAllStores
          ? 'WHERE transactiondate BETWEEN ? AND ?'
          : 'WHERE sourcefacility = ? AND transactiondate BETWEEN ? AND ?';
      final args = isAllStores
          ? [startMillis, endMillis]
          : [selectedStore.value!.name, startMillis, endMillis];

      final query =
          ''' SELECT date, SUM(grouped_amount) as total FROM (SELECT $dateGroupClause as date, salesId, SUM(amount) as grouped_amount FROM sales $whereClause GROUP BY date, salesId) GROUP BY date ORDER BY date''';
      final result = await db.rawQuery(query, args);

      for (var row in result) {
        final dateKey = row['date'] as String?;
        if (dateKey != null && salesByDate.containsKey(dateKey)) {
          final total = (row['total'] as num?)?.toDouble() ?? 0.0;
          salesByDate[dateKey] = total;
        }
      }

      final formattedData = salesByDate.entries.map((entry) {
        DateTime date = (aggregationType.value == 'hourly')
            ? hourlyFormatter.parse(entry.key)
            : dateFormatter.parse(entry.key);
        return SalesDataPoint(date, entry.value);
      }).toList()..sort((a, b) => a.date.compareTo(b.date));
      salesDataPoints.assignAll(formattedData);
    } catch (e) {
      print("Error fetching sales chart data: $e");
      salesDataPoints.clear();
    }
  }

  Future<void> fetchAllStores() async {
    isLoading.value = true;
    try {
      final db = await dbHelper.database;
      final result = await db.query(
        'service_points',
        where: 'stores = ?',
        whereArgs: [1],
        orderBy: 'name ASC',
      );
      final storesFromDb = result
          .map(
            (row) =>
                Store(id: row['id'] as String, name: row['name'] as String),
          )
          .toList();
      storeList.assignAll([Store.all, ...storesFromDb]);
      if (storeList.isNotEmpty) {
        selectedStore.value = Store.all;
        await fetchAllDataForSelection();
      }
    } catch (e) {
      print("Error fetching stores: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> onStoreChanged(Store? newStore) async {
    if (newStore != null && newStore.id != selectedStore.value?.id) {
      selectedStore.value = newStore;
      await fetchAllDataForSelection();
    }
  }

  Future<void> onDateRangeChanged(
    DateRange newRange,
    DateTimeRange? customRange,
  ) async {
    selectedDateRange.value = newRange;
    customDateRange.value = customRange;
    await fetchAllDataForSelection();
  }

  Future<void> fetchAllDataForSelection() async {
    if (selectedStore.value == null) return;
    isFetchingKpisAndCharts.value = true;
    await Future.wait([
      _fetchSalesDataForChart(),
      _fetchHourlyTrafficData(),
      _fetchTopProductsData(),
      Get.find<StoreKpiTrendController>().fetchKpiTrendData(),
    ]);
    isFetchingKpisAndCharts.value = false;
  }

  Future<void> _fetchHourlyTrafficData() async {
    try {
      final db = await dbHelper.database;
      final range = _getDateRange();
      final isAllStores = selectedStore.value!.id == Store.all.id;
      final whereClause = isAllStores
          ? 'WHERE transactiondate BETWEEN ? AND ?'
          : 'WHERE sourcefacility = ? AND transactiondate BETWEEN ? AND ?';
      final args = isAllStores
          ? [
              range.start.millisecondsSinceEpoch,
              range.end.millisecondsSinceEpoch,
            ]
          : [
              selectedStore.value!.name,
              range.start.millisecondsSinceEpoch,
              range.end.millisecondsSinceEpoch,
            ];
      final query =
          " SELECT CAST(strftime('%H', datetime(transactiondate / 1000, 'unixepoch')) AS INTEGER) as hour, COUNT(DISTINCT salesId) as count FROM sales $whereClause GROUP BY hour ORDER BY hour ";
      final result = await db.rawQuery(query, args);
      hourlyTrafficData.assignAll(
        result
            .map(
              (row) => HourlyTraffic(row['hour'] as int, row['count'] as int),
            )
            .toList(),
      );
    } catch (e) {
      print("Error fetching hourly traffic data: $e");
      hourlyTrafficData.clear();
    }
  }

  Future<void> _fetchTopProductsData() async {
    try {
      final db = await dbHelper.database;
      final range = _getDateRange();
      final isAllStores = selectedStore.value!.id == Store.all.id;
      final whereClause = isAllStores
          ? 'WHERE transactiondate BETWEEN ? AND ?'
          : 'WHERE sourcefacility = ? AND transactiondate BETWEEN ? AND ?';
      final args = isAllStores
          ? [
              range.start.millisecondsSinceEpoch,
              range.end.millisecondsSinceEpoch,
            ]
          : [
              selectedStore.value!.name,
              range.start.millisecondsSinceEpoch,
              range.end.millisecondsSinceEpoch,
            ];

      final query = '''
        SELECT inventoryname, SUM(quantity) as total_quantity, SUM(amount) as total_revenue
        FROM sales
        $whereClause
        GROUP BY inventoryname
        ORDER BY total_quantity DESC
        LIMIT 10
      ''';

      final result = await db.rawQuery(query, args);

      final products = result.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        return TopProduct(
          rank: index + 1,
          name: row['inventoryname'] as String? ?? 'Unknown Product',
          imageUrl: '', // Will be populated from inventory table if available
          unitsSold: (row['total_quantity'] as num?)?.toInt() ?? 0,
          revenue: (row['total_revenue'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      // Try to populate image URLs from inventory table
      for (var product in products) {
        final inventoryResult = await db.query(
          'inventory',
          columns: ['downloadlink'],
          where: 'name = ?',
          whereArgs: [product.name],
          limit: 1,
        );
        if (inventoryResult.isNotEmpty) {
          product = TopProduct(
            rank: product.rank,
            name: product.name,
            imageUrl: inventoryResult.first['downloadlink'] as String? ?? '',
            unitsSold: product.unitsSold,
            revenue: product.revenue,
          );
        }
      }

      topSellingProducts.assignAll(products);
    } catch (e) {
      print("Error fetching top products: $e");
      topSellingProducts.clear();
    }
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;
    final range = selectedDateRange.value;
    final customRangeVal = customDateRange.value;
    switch (range) {
      case DateRange.today:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateRange.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case DateRange.last7Days:
        startDate = now.subtract(const Duration(days: 6));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateRange.monthToDate:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateRange.custom:
        if (customRangeVal != null) {
          startDate = customRangeVal.start;
          endDate = customRangeVal.end;
        } else {
          startDate = now.subtract(const Duration(days: 6));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        }
        break;
      default:
        startDate = now.subtract(const Duration(days: 6));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
    return DateTimeRange(start: startDate, end: endDate);
  }

  DateTime _weekToDate(int year, int week) {
    final jan1 = DateTime(year, 1, 1);
    final firstMonday = jan1.add(Duration(days: (1 - jan1.weekday + 7) % 7));
    return firstMonday.add(Duration(days: (week - 1) * 7));
  }

  int _getWeekNumber(DateTime date) {
    final firstJan = DateTime(date.year, 1, 1);
    final daysSinceFirstJan = date.difference(firstJan).inDays;
    final firstMonday = firstJan.add(
      Duration(days: (1 - firstJan.weekday + 7) % 7),
    );
    if (date.isBefore(firstMonday)) return 1;
    return ((daysSinceFirstJan - firstMonday.difference(firstJan).inDays) ~/
            7) +
        1;
  }
}
