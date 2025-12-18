import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../db/db_helper.dart';
import '../models/dashboard.dart';
import '../widgets/finance/date_range.dart';
import 'mon_dashboard_controller.dart';

class MonSalesTrendsController extends GetxController {
  final MonDashboardController dateController = Get.find();
  final dbHelper = DatabaseHelper();

  var salesData = <SalesDataPoint>[].obs;
  var isLoadingSales = true.obs;
  var hasErrorSales = false.obs;
  var aggregationType = 'daily'.obs;
  var topStoresData = <StorePerformance>[].obs;
  var isLoadingStores = true.obs;
  var hasErrorStores = false.obs;

  var rawSalesForPeriod = <Map<String, dynamic>>[].obs;

  var stockAlerts = <CategorizedStockAlert>[].obs;
  var isLoadingStock = true.obs;
  var hasErrorStock = false.obs;
  var expiries = <CategorizedStockAlert>[].obs;
  var isLoadingExpiries = true.obs;
  var hasErrorExpiries = false.obs;

  String getPeriodLabel() {
    final range = dateController.selectedRange.value;
    final customRange = dateController.customRange.value;
    final formatter = DateFormat('MMM d, yyyy');

    switch (range) {
      case DateRange.today:
        return 'For ${formatter.format(DateTime.now())}';
      case DateRange.yesterday:
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        return 'For ${formatter.format(yesterday)}';
      case DateRange.last7Days:
        final now = DateTime.now();
        final start = now.subtract(const Duration(days: 6));
        return 'From ${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(now)}';
      case DateRange.monthToDate:
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        return 'From ${DateFormat('MMM d').format(monthStart)} - ${DateFormat('MMM d, yyyy').format(now)}';
      case DateRange.custom:
        if (customRange != null) {
          return 'From ${DateFormat('MMM d').format(customRange.start)} - ${DateFormat('MMM d, yyyy').format(customRange.end)}';
        }
        return 'Custom Period';
      default:
        return '';
    }
  }

  @override
  void onInit() {
    super.onInit();
    print("SalesTrendsController onInit - Starting initial data fetch");
    print("Initial date range: ${dateController.selectedRange.value}");
    fetchAllData();
    ever(dateController.selectedRange, (_) {
      print("Date range changed to: ${dateController.selectedRange.value}");
      fetchAllData();
    });
    ever(dateController.customRange, (_) {
      print("Custom range changed to: ${dateController.customRange.value}");
      fetchAllData();
    });
  }

  Future<void> fetchAllData() async {
    print("fetchAllData called");
    final dateRange = _getDateRange();
    print("Fetching data for date range: ${dateRange.start} to ${dateRange.end}");
    await fetchSalesData(dateRange);
    await fetchTopStores(dateRange);
    await fetchRawSalesData(dateRange);
    await fetchStockAlerts();
    await fetchExpiries();
    print("fetchAllData completed");
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;
    final range = dateController.selectedRange.value;
    final customRange = dateController.customRange.value;
    print("_getDateRange called with range: $range, customRange: $customRange");

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
        if (customRange != null) {
          startDate = customRange.start;
          endDate = customRange.end;
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

  Future<void> fetchRawSalesData(DateTimeRange dateRange) async {
    try {
      final db = await dbHelper.database;
      final startMillis = dateRange.start.millisecondsSinceEpoch;
      final endMillis = dateRange.end.millisecondsSinceEpoch;

      print("Fetching raw sales data from ${dateRange.start} to ${dateRange.end}");
      final result = await db.query(
        'sales',
        where: 'transactiondate >= ? AND transactiondate <= ?',
        whereArgs: [startMillis, endMillis],
      );
      print("Raw sales data fetched: ${result.length} records");
      if (result.isNotEmpty) {
        print("Sample data: ${result.first}");
      }
      rawSalesForPeriod.assignAll(result);
    } catch (e) {
      print("Error fetching raw sales data for charts: $e");
      rawSalesForPeriod.assignAll([]);
    }
  }

  Future<void> fetchSalesData(DateTimeRange dateRange) async {
    try {
      isLoadingSales.value = true;
      hasErrorSales.value = false;
      final db = await dbHelper.database;
      final startDate = dateRange.start;
      final endDate = dateRange.end;
      // Add 1 to include both start and end dates
      final days = endDate.difference(startDate).inDays + 1;

      // Determine aggregation based on date range type and duration
      final range = dateController.selectedRange.value;

      print("Date range: $startDate to $endDate ($days days, range type: $range)");

      if (range == DateRange.today || range == DateRange.yesterday || days <= 1) {
        aggregationType.value = 'hourly';
      } else if (range == DateRange.last7Days || (days > 1 && days <= 7)) {
        aggregationType.value = 'daily';
      } else if (range == DateRange.monthToDate || (days > 7 && days <= 31)) {
        // Use daily aggregation for month view, but we'll show labels at 5-day intervals
        aggregationType.value = 'daily';
      } else if (days > 31 && days <= 90) {
        aggregationType.value = 'monthly';
      } else if (days > 90 && days <= 365) {
        aggregationType.value = 'monthly';
      } else {
        aggregationType.value = 'quarterly';
      }

      print("Selected aggregation type: ${aggregationType.value}");

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
        // For monthly view, group by weeks within the period
        if (range == DateRange.monthToDate) {
          // Calculate weeks in the month starting from the 1st
          final monthStart = DateTime(startDate.year, startDate.month, 1);
          int weekNum = 1;
          DateTime weekStart = monthStart;

          while (weekStart.isBefore(endDate) || weekStart.isAtSameMomentAs(endDate)) {
            salesByDate[dateFormatter.format(weekStart)] = 0.0;
            weekStart = weekStart.add(const Duration(days: 7));
            weekNum++;
          }
        } else {
          // For other ranges, group by week numbers
          final startWeek = _getWeekNumber(startDate);
          final endWeek = _getWeekNumber(endDate);
          for (int week = startWeek; week <= endWeek; week++) {
            final weekDate = _weekToDate(startDate.year, week);
            salesByDate[dateFormatter.format(weekDate)] = 0.0;
          }
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
        if (range == DateRange.monthToDate) {
          // For month-to-date, group by weeks from the 1st of the month
          // Calculate which week of the month (starting from day 1)
          dateGroupClause =
              "strftime('%Y-%m-', datetime(transactiondate / 1000, 'unixepoch', 'localtime')) || printf('%02d', ((CAST(strftime('%d', datetime(transactiondate / 1000, 'unixepoch', 'localtime')) AS INTEGER) - 1) / 7 * 7 + 1))";
        } else {
          // For other ranges, group by week start (Monday)
          dateGroupClause =
              "strftime('%Y-%m-%d', datetime(transactiondate / 1000, 'unixepoch', 'localtime', 'weekday 1', '-7 days'))";
        }
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

      final query =
          ''' SELECT date, SUM(grouped_amount) as total FROM (SELECT $dateGroupClause as date, salesId, SUM(amount) as grouped_amount FROM sales WHERE transactiondate >= ? AND transactiondate <= ? GROUP BY date, salesId) GROUP BY date ''';

      print("Executing SQL query for aggregation type: ${aggregationType.value}");
      print("Query: $query");
      final result = await db.rawQuery(query, [startMillis, endMillis]);
      print("Query returned ${result.length} rows");

      // Update salesByDate with actual values from database
      for (var row in result) {
        final dateKey = row['date'] as String?;
        final total = (row['total'] as num?)?.toDouble() ?? 0.0;

        if (dateKey != null) {
          if (salesByDate.containsKey(dateKey)) {
            salesByDate[dateKey] = total;
            print("Matched date: $dateKey = $total");
          } else {
            // Add unmatched dates for debugging
            print("WARNING: Date from query not in initialized map: $dateKey = $total");
            salesByDate[dateKey] = total;
          }
        }
      }

      print("Final salesByDate map has ${salesByDate.length} entries");

      // Convert to list of SalesDataPoint objects
      final formattedData = salesByDate.entries.map((entry) {
        DateTime date;
        try {
          date = (aggregationType.value == 'hourly')
              ? hourlyFormatter.parse(entry.key)
              : dateFormatter.parse(entry.key);
        } catch (e) {
          print("Error parsing date: ${entry.key} - $e");
          // Fallback to current time if parsing fails
          date = DateTime.now();
        }
        return SalesDataPoint(date, entry.value);
      }).toList()..sort((a, b) => a.date.compareTo(b.date));

      print("Formatted data has ${formattedData.length} points");
      if (formattedData.isNotEmpty) {
        print("First point: ${formattedData.first.date} = ${formattedData.first.amount}");
        print("Last point: ${formattedData.last.date} = ${formattedData.last.amount}");
      }

      salesData.assignAll(formattedData);
    } catch (e) {
      hasErrorSales.value = true;
      print("Error fetching sales data: $e");
    } finally {
      isLoadingSales.value = false;
    }
  }

  Future<void> fetchTopStores(DateTimeRange dateRange) async {
    try {
      isLoadingStores.value = true;
      hasErrorStores.value = false;
      final db = await dbHelper.database;
      final startMillis = dateRange.start.millisecondsSinceEpoch;
      final endMillis = dateRange.end.millisecondsSinceEpoch;

      const query = '''
        SELECT
          sp.name as storeName,
          COALESCE(SUM(grouped_amount), 0) as total
        FROM service_points sp
        LEFT JOIN (SELECT sourcefacility, salesId, SUM(amount) as grouped_amount FROM sales WHERE transactiondate >= ? AND transactiondate <= ? GROUP BY sourcefacility, salesId) s ON sp.name = s.sourcefacility
        WHERE sp.stores = 1
        GROUP BY sp.id, sp.name
        ORDER BY total DESC
      ''';
      final result = await db.rawQuery(query, [startMillis, endMillis]);
      print("Top stores query result: $result");
      topStoresData.assignAll(
        result.map((row) {
          return StorePerformance(
            row['storeName'] as String? ?? 'Unknown',
            (row['total'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList(),
      );
      print("Top stores data after mapping: $topStoresData");
    } catch (e) {
      hasErrorStores.value = true;
      print("Error fetching store data: $e");
    } finally {
      isLoadingStores.value = false;
    }
  }

  Future<void> fetchStockAlerts() async {
    isLoadingStock.value = true;
    await Future.delayed(const Duration(milliseconds: 500));
    stockAlerts.assignAll([]);
    isLoadingStock.value = false;
  }

  Future<void> fetchExpiries() async {
    isLoadingExpiries.value = true;
    await Future.delayed(const Duration(milliseconds: 500));
    expiries.assignAll([]);
    isLoadingExpiries.value = false;
  }
}
