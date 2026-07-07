import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import '../models/kpi_sales_data.dart';
import '../../../shared/database/unified_db_helper.dart';
import 'api_services.dart';

/// Top-level function for isolate-based JSON decoding
/// Must be top-level or static for compute() to work
List<dynamic> _decodeJsonList(String jsonString) {
  return json.decode(jsonString) as List<dynamic>;
}

/// KPI API Service for fetching and managing KPI data
/// 
/// Uses the existing MonitorApiService for HTTP requests and 
/// UnifiedDatabaseHelper for database operations
class KpiApiService extends GetxService {
  static const String _baseUrl = 'http://52.30.142.12:8080/rest';
  
  final _dbHelper = UnifiedDatabaseHelper.instance;
  late final MonitorApiService _apiService;

  @override
  void onInit() {
    super.onInit();
    _apiService = Get.find<MonitorApiService>();
  }

  /// Fetch KPI data from the API endpoint
  /// 
  /// Parameters:
  /// - [startDate]: Start date in ISO format (yyyy-MM-dd)
  /// - [endDate]: End date in ISO format (yyyy-MM-dd)
  /// - [kpiId]: KPI mode (0-8, see KpiMode constants)
  /// - [timeframe]: Timeframe (1-5, see KpiTimeframe constants)
  /// 
  /// Returns list of KpiSalesData parsed from API response
  Future<List<KpiSalesData>> fetchKpiData({
    required String startDate,
    required String endDate,
    int kpiId = KpiMode.allTransactions,
    int timeframe = KpiTimeframe.normal,
  }) async {
    final endpoint = 
        '$_baseUrl/sales/reports/kpi?startDate=$startDate&endDate=$endDate&kpiId=$kpiId&timeframe=$timeframe';
    
    debugPrint('KpiApiService: Fetching KPI data with kpiId=$kpiId, timeframe=$timeframe');
    
    final response = await _apiService.getWithAuth(
      '/sales/reports/kpi?startDate=$startDate&endDate=$endDate&kpiId=$kpiId&timeframe=$timeframe',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch KPI data: ${response.statusCode}');
    }

    // Parse JSON in isolate for performance
    final List<dynamic> jsonList = await compute(
      _decodeJsonList,
      response.body,
    );

    // Convert to KpiSalesData objects
    return jsonList.map((json) => KpiSalesData.fromJson(json, kpiId)).toList();
  }

  /// Fetch KPI data for specific mode
  /// 
  /// Convenience method that wraps fetchKpiData with specific KPI mode
  Future<List<KpiSalesData>> fetchKpiByMode({
    required String startDate,
    required String endDate,
    required int kpiId,
    int timeframe = KpiTimeframe.normal,
  }) async {
    return await fetchKpiData(
      startDate: startDate,
      endDate: endDate,
      kpiId: kpiId,
      timeframe: timeframe,
    );
  }

  /// Fetch all KPI data types (0-8) and store in database
  /// 
  /// This ensures all data is available for queries
  Future<void> syncAllKpiData(DateTime startDate, DateTime endDate) async {
    final dateFormatter = _getDateFormatter();
    final startDateStr = dateFormatter.format(startDate);
    final endDateStr = dateFormatter.format(endDate);

    debugPrint('KpiApiService: Syncing all KPI data from $startDateStr to $endDateStr');

    // Get all KPI types
    final kpiTypes = KpiMode.all;

    final db = _dbHelper.database;

    // DO NOT DELETE - use ConflictAlgorithm.replace to update existing records
    // This preserves all existing data and only inserts/updates new records
    debugPrint('KpiApiService: Syncing KPI data (upsert mode - no deletions)');

    // Fetch and insert each KPI type
    for (final kpiId in kpiTypes) {
      try {
        debugPrint('KpiApiService: Fetching KPI data for mode=$kpiId (${KpiMode.getName(kpiId)})');
        
        final data = await fetchKpiData(
          startDate: startDateStr,
          endDate: endDateStr,
          kpiId: kpiId,
          timeframe: KpiTimeframe.normal,
        );

        if (data.isEmpty) {
          debugPrint('KpiApiService: No data for mode=$kpiId');
          continue;
        }

        // Batch insert KPI sales
        final batch = db.batch();
        for (final kpiData in data) {
          batch.insert(
            'mon_kpi_sales',
            kpiData.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        
        debugPrint('KpiApiService: Inserted ${data.length} records for mode=$kpiId');
      } catch (e) {
        debugPrint('KpiApiService: Error fetching mode=$kpiId: $e');
      }
    }

    debugPrint('KpiApiService: Completed syncing all KPI data');
  }

  /// Fetch and store KPI data for a single mode
  /// 
  /// Returns the number of records stored
  Future<int> fetchAndStoreKpiData({
    required String startDate,
    required String endDate,
    required int kpiId,
    int timeframe = KpiTimeframe.normal,
  }) async {
    final data = await fetchKpiData(
      startDate: startDate,
      endDate: endDate,
      kpiId: kpiId,
      timeframe: timeframe,
    );

    if (data.isEmpty) {
      return 0;
    }

    final db = _dbHelper.database;
    final batch = db.batch();

    // Clear existing data for this kpiId in the date range
    batch.delete(
      'mon_kpi_sales',
      where: 'kpi_id = ? AND processing_date >= ? AND processing_date <= ?',
      whereArgs: [kpiId, startDate, endDate],
    );

    // Insert new data
    for (final kpiData in data) {
      batch.insert(
        'mon_kpi_sales',
        kpiData.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    
    debugPrint('KpiApiService: Stored ${data.length} records for kpiId=$kpiId');
    return data.length;
  }

  /// Get date formatter for API requests
  _DateFormatter _getDateFormatter() {
    return _DateFormatter();
  }
}

/// Internal date formatter helper
class _DateFormatter {
  String format(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}