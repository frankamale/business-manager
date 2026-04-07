import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../shared/database/unified_db_helper.dart';
import '../models/kpi_sales_data.dart';
import '../repositories/kpi_repository.dart';
import '../widgets/finance/date_range.dart';
import 'mon_dashboard_controller.dart';

/// KPI Controller for fetching and storing KPI data
/// 
/// Handles:
/// - Fetching KPI data from API and storing in database
/// - Querying stored data from database filtered by kpi_id
/// - Syncing all KPI modes (0-8)
/// - Supporting timeframe 1 (normal date)
/// 
/// KPI modes (kpi_id):
/// - 0: all transactions
/// - 1: cash
/// - 2: pending payment
/// - 3: payment modes
/// - 4: salesperson
/// - 5: profit (amount1 is profit, amount2 is transaction value)
/// - 6: efris status
/// - 7: by stock category
/// - 8: by item
class MonKpiController extends GetxController {
  final MonDashboardController dateController = Get.find();
  final dbHelper = UnifiedDatabaseHelper.instance;
  final KpiRepository _kpiRepository = KpiRepository.to;

  // State variables
  var isLoading = false.obs;
  var hasError = false.obs;
  var isInitialized = false.obs;
  var kpiData = <KpiSalesData>[].obs;
  
  // Selected filters
  var selectedKpiId = KpiMode.allTransactions.obs;
  var selectedTimeframe = KpiTimeframe.normal.obs;

  @override
  void onInit() {
    super.onInit();
    debugPrint('MonKpiController: onInit - NOT fetching data yet');
    
    // Set up listeners for date changes - only fetch after initialization
    ever(dateController.selectedRange, (_) {
      if (isInitialized.value) {
        debugPrint('MonKpiController: Date range changed, fetching data');
        fetchKpiData();
      }
    });
    
    ever(dateController.customRange, (_) {
      if (isInitialized.value) {
        debugPrint('MonKpiController: Custom range changed, fetching data');
        fetchKpiData();
      }
    });
    
    // Listen for KPI ID changes
    ever(selectedKpiId, (_) {
      if (isInitialized.value) {
        debugPrint('MonKpiController: KPI ID changed to ${selectedKpiId.value}');
        fetchKpiData();
      }
    });
  }

  /// Call this manually when the UI is ready
  Future<void> initializeData() async {
    if (isInitialized.value) {
      debugPrint('MonKpiController: Already initialized, skipping');
      return;
    }
    
    debugPrint('MonKpiController: Performing first data fetch');
    await fetchKpiData();
    isInitialized.value = true;
  }

  /// Fetch KPI data from database based on current date range and selected KPI
  Future<void> fetchKpiData() async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final dateRange = _getDateRange();
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final startDateStr = dateFormatter.format(dateRange.start);
      final endDateStr = dateFormatter.format(dateRange.end);

      debugPrint('MonKpiController: Fetching KPI data for kpiId=${selectedKpiId.value} from $startDateStr to $endDateStr');

      // Fetch data from repository filtered by kpi_id
      final results = await _kpiRepository.getKpiSalesData(
        kpiId: selectedKpiId.value,
        startDate: startDateStr,
        endDate: endDateStr,
      );

      kpiData.assignAll(results);
      debugPrint('MonKpiController: Retrieved ${results.length} records');
    } catch (e) {
      hasError.value = true;
      debugPrint('MonKpiController: Error fetching KPI data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetch KPI data from API and store in database
  /// 
  /// Parameters:
  /// - [kpiId]: KPI mode to fetch (defaults to selectedKpiId)
  /// - [timeframe]: Timeframe to use (defaults to selectedTimeframe)
  Future<void> syncKpiFromApi({int? kpiId, int? timeframe}) async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final kpiMode = kpiId ?? selectedKpiId.value;
      final timeFrame = timeframe ?? selectedTimeframe.value;
      
      final dateRange = _getDateRange();
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final startDateStr = dateFormatter.format(dateRange.start);
      final endDateStr = dateFormatter.format(dateRange.end);

      debugPrint('MonKpiController: Syncing KPI data from API for kpiId=$kpiMode, timeframe=$timeFrame');

      final count = await _kpiRepository.fetchAndStoreKpiData(
        startDate: startDateStr,
        endDate: endDateStr,
        kpiId: kpiMode,
        timeframe: timeFrame,
      );

      debugPrint('MonKpiController: Stored $count records from API');

      // Refresh local data
      await fetchKpiData();
    } catch (e) {
      hasError.value = true;
      debugPrint('MonKpiController: Error syncing KPI from API: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Sync all KPI modes (0-8) from API
  Future<void> syncAllKpiModes() async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final dateRange = _getDateRange();

      debugPrint('MonKpiController: Syncing all KPI modes from API');

      await _kpiRepository.syncAllKpiData(dateRange.start, dateRange.end);

      debugPrint('MonKpiController: Completed syncing all KPI modes');

      // Refresh local data
      await fetchKpiData();
    } catch (e) {
      hasError.value = true;
      debugPrint('MonKpiController: Error syncing all KPI modes: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get KPI data filtered by specific kpi_id
  /// 
  /// Parameters:
  /// - [kpiId]: KPI mode to filter by
  /// - [startDate]: Optional start date filter
  /// - [endDate]: Optional end date filter
  /// 
  /// Returns list of KpiSalesData
  Future<List<KpiSalesData>> getDataByKpiId({
    required int kpiId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final dateRange = _getDateRange();
      final dateFormatter = DateFormat('yyyy-MM-dd');
      
      final start = startDate ?? dateFormatter.format(dateRange.start);
      final end = endDate ?? dateFormatter.format(dateRange.end);

      debugPrint('MonKpiController: Getting data for kpiId=$kpiId from $start to $end');

      return await _kpiRepository.getKpiSalesData(
        kpiId: kpiId,
        startDate: start,
        endDate: end,
      );
    } catch (e) {
      debugPrint('MonKpiController: Error getting data by kpiId: $e');
      return [];
    }
  }

  /// Get the current date range from the dashboard controller
  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;
    final range = dateController.selectedRange.value;
    final customRange = dateController.customRange.value;

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

  /// Change the selected KPI mode
  void changeKpiMode(int kpiId) {
    if (kpiId >= 0 && kpiId <= 8) {
      selectedKpiId.value = kpiId;
    }
  }

  /// Change the selected timeframe
  void changeTimeframe(int timeframe) {
    if (timeframe >= 1 && timeframe <= 5) {
      selectedTimeframe.value = timeframe;
    }
  }
}
