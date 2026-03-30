import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import '../models/kpi_sales_data.dart';
import '../services/kpi_api_service.dart';
import '../../../shared/database/unified_db_helper.dart';

/// KPI Repository for data access
/// 
/// Provides methods for:
/// - Fetching KPI data from API and storing in database
/// - Querying KPI data from local database
/// - Aggregating KPI data for analytics
class KpiRepository extends GetxService {
  static KpiRepository get to => Get.find();
  
  final _dbHelper = UnifiedDatabaseHelper.instance;
  late final KpiApiService _kpiApiService;

  @override
  void onInit() {
    super.onInit();
    _kpiApiService = Get.put(KpiApiService());
  }

  /// Fetch KPI data from API and store in database
  /// 
  /// Parameters:
  /// - [startDate]: Start date in ISO format (yyyy-MM-dd)
  /// - [endDate]: End date in ISO format (yyyy-MM-dd)
  /// - [kpiId]: KPI mode (0-8)
  /// - [timeframe]: Timeframe (1-5)
  /// 
  /// Returns the number of records stored
  Future<int> fetchAndStoreKpiData({
    required String startDate,
    required String endDate,
    int kpiId = KpiMode.allTransactions,
    int timeframe = KpiTimeframe.normal,
  }) async {
    return await _kpiApiService.fetchAndStoreKpiData(
      startDate: startDate,
      endDate: endDate,
      kpiId: kpiId,
      timeframe: timeframe,
    );
  }

  /// Sync all KPI data types (0-8) from API
  Future<void> syncAllKpiData(DateTime startDate, DateTime endDate) async {
    await _kpiApiService.syncAllKpiData(startDate, endDate);
  }

  /// Get KPI sales data from database
  /// 
  /// Parameters:
  /// - [kpiId]: Filter by KPI mode (optional)
  /// - [startDate]: Filter by start date (optional)
  /// - [endDate]: Filter by end date (optional)
  /// - [sellingPoint]: Filter by selling point (optional)
  /// 
  /// Returns list of KpiSalesData
  Future<List<KpiSalesData>> getKpiSalesData({
    int? kpiId,
    String? startDate,
    String? endDate,
    String? sellingPoint,
  }) async {
    final db = _dbHelper.database;
    
    String where = '';
    List<dynamic> whereArgs = [];
    
    if (kpiId != null) {
      where = 'kpi_id = ?';
      whereArgs.add(kpiId);
    }
    
    if (startDate != null) {
      where += where.isEmpty ? 'processing_date >= ?' : ' AND processing_date >= ?';
      whereArgs.add(startDate);
    }
    
    if (endDate != null) {
      where += where.isEmpty ? 'processing_date <= ?' : ' AND processing_date <= ?';
      whereArgs.add(endDate);
    }
    
    if (sellingPoint != null) {
      where += where.isEmpty ? 'selling_point = ?' : ' AND selling_point = ?';
      whereArgs.add(sellingPoint);
    }

    final List<Map<String, dynamic>> results = await db.query(
      'mon_kpi_sales',
      where: where.isEmpty ? null : where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'processing_date DESC',
    );

    return results.map((map) => KpiSalesData.fromMap(map)).toList();
  }

  /// Get total sales amount for a date range
  /// 
  /// Uses kpiId=0 (all transactions) and amount2 (transaction value)
  Future<double> getTotalSales({
    required String startDate,
    required String endDate,
    String? sellingPoint,
  }) async {
    final db = _dbHelper.database;
    
    String where = 'kpi_id = ? AND processing_date >= ? AND processing_date <= ?';
    List<dynamic> whereArgs = [KpiMode.allTransactions, startDate, endDate];
    
    if (sellingPoint != null) {
      where += ' AND selling_point = ?';
      whereArgs.add(sellingPoint);
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount2) as total FROM mon_kpi_sales WHERE $where',
      whereArgs,
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get total profit for a date range
  /// 
  /// Uses kpiId=5 (profit) and amount1 (profit)
  Future<double> getTotalProfit({
    required String startDate,
    required String endDate,
    String? sellingPoint,
  }) async {
    final db = _dbHelper.database;
    
    String where = 'kpi_id = ? AND processing_date >= ? AND processing_date <= ?';
    List<dynamic> whereArgs = [KpiMode.profit, startDate, endDate];
    
    if (sellingPoint != null) {
      where += ' AND selling_point = ?';
      whereArgs.add(sellingPoint);
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount1) as profit FROM mon_kpi_sales WHERE $where',
      whereArgs,
    );

    return (result.first['profit'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get total transaction count for a date range
  /// 
  /// Uses kpiId=0 (all transactions) and quantity
  Future<int> getTotalTransactions({
    required String startDate,
    required String endDate,
    String? sellingPoint,
  }) async {
    final db = _dbHelper.database;
    
    String where = 'kpi_id = ? AND processing_date >= ? AND processing_date <= ?';
    List<dynamic> whereArgs = [KpiMode.allTransactions, startDate, endDate];
    
    if (sellingPoint != null) {
      where += ' AND selling_point = ?';
      whereArgs.add(sellingPoint);
    }

    final result = await db.rawQuery(
      'SELECT SUM(quantity) as count FROM mon_kpi_sales WHERE $where',
      whereArgs,
    );

    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  /// Get outstanding payments (pending payments) for a date range
  /// 
  /// Uses kpiId=2 (pending payment) and amount2 (transaction value)
  Future<double> getOutstandingPayments({
    required String startDate,
    required String endDate,
    String? sellingPoint,
  }) async {
    final db = _dbHelper.database;
    
    String where = 'kpi_id = ? AND processing_date >= ? AND processing_date <= ?';
    List<dynamic> whereArgs = [KpiMode.pendingPayment, startDate, endDate];
    
    if (sellingPoint != null) {
      where += ' AND selling_point = ?';
      whereArgs.add(sellingPoint);
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount2) as total FROM mon_kpi_sales WHERE $where',
      whereArgs,
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get daily sales breakdown for a date range
  /// 
  /// Returns map of date to total sales amount
  Future<Map<String, double>> getDailySales({
    required String startDate,
    required String endDate,
    String? sellingPoint,
  }) async {
    final db = _dbHelper.database;
    
    String where = 'kpi_id = ? AND processing_date >= ? AND processing_date <= ?';
    List<dynamic> whereArgs = [KpiMode.allTransactions, startDate, endDate];
    
    if (sellingPoint != null) {
      where += ' AND selling_point = ?';
      whereArgs.add(sellingPoint);
    }

    final result = await db.rawQuery(
      'SELECT processing_date, SUM(amount2) as daily_total FROM mon_kpi_sales WHERE $where GROUP BY processing_date ORDER BY processing_date',
      whereArgs,
    );

    return Map.fromEntries(
      result.map((row) => MapEntry(
        row['processing_date'] as String,
        (row['daily_total'] as num?)?.toDouble() ?? 0.0,
      )),
    );
  }

  /// Get sales by payment mode for a date range
  /// 
  /// Uses kpiId=3 (payment modes)
  Future<Map<String, double>> getSalesByPaymentMode({
    required String startDate,
    required String endDate,
  }) async {
    final db = _dbHelper.database;
    
    final result = await db.rawQuery(
      '''SELECT kpi, SUM(amount2) as total 
         FROM mon_kpi_sales 
         WHERE kpi_id = ? AND processing_date >= ? AND processing_date <= ? 
         GROUP BY kpi''',
      [KpiMode.paymentModes, startDate, endDate],
    );

    return Map.fromEntries(
      result.map((row) => MapEntry(
        row['kpi'] as String,
        (row['total'] as num?)?.toDouble() ?? 0.0,
      )),
    );
  }

  /// Get top selling items for a date range
  /// 
  /// Uses kpiId=8 (by item)
  Future<List<KpiSalesData>> getTopSellingItems({
    required String startDate,
    required String endDate,
    int limit = 10,
    String? sellingPoint,
  }) async {
    final db = _dbHelper.database;
    
    String where = 'kpi_id = ? AND processing_date >= ? AND processing_date <= ?';
    List<dynamic> whereArgs = [KpiMode.byItem, startDate, endDate];
    
    if (sellingPoint != null) {
      where += ' AND selling_point = ?';
      whereArgs.add(sellingPoint);
    }

    final result = await db.rawQuery(
      '''SELECT * FROM mon_kpi_sales 
         WHERE $where 
         GROUP BY kpi 
         ORDER BY SUM(amount2) DESC 
         LIMIT ?''',
      [...whereArgs, limit],
    );

    return result.map((map) => KpiSalesData.fromMap(map)).toList();
  }

  /// Get sales by stock category for a date range
  /// 
  /// Uses kpiId=7 (by stock category)
  Future<Map<String, double>> getSalesByStockCategory({
    required String startDate,
    required String endDate,
  }) async {
    final db = _dbHelper.database;
    
    final result = await db.rawQuery(
      '''SELECT kpi, SUM(amount2) as total, SUM(quantity) as qty
         FROM mon_kpi_sales 
         WHERE kpi_id = ? AND processing_date >= ? AND processing_date <= ? 
         GROUP BY kpi
         ORDER BY total DESC''',
      [KpiMode.stockCategory, startDate, endDate],
    );

    return Map.fromEntries(
      result.map((row) => MapEntry(
        row['kpi'] as String,
        (row['total'] as num?)?.toDouble() ?? 0.0,
      )),
    );
  }

  /// Get sales by salesperson for a date range
  /// 
  /// Uses kpiId=4 (salesperson)
  Future<Map<String, double>> getSalesBySalesperson({
    required String startDate,
    required String endDate,
  }) async {
    final db = _dbHelper.database;
    
    final result = await db.rawQuery(
      '''SELECT kpi, SUM(amount2) as total, SUM(quantity) as transactions
         FROM mon_kpi_sales 
         WHERE kpi_id = ? AND processing_date >= ? AND processing_date <= ? 
         GROUP BY kpi
         ORDER BY total DESC''',
      [KpiMode.salesperson, startDate, endDate],
    );

    return Map.fromEntries(
      result.map((row) => MapEntry(
        row['kpi'] as String,
        (row['total'] as num?)?.toDouble() ?? 0.0,
      )),
    );
  }

  /// Delete KPI data for a specific date range
  Future<void> deleteKpiData({
    int? kpiId,
    String? startDate,
    String? endDate,
  }) async {
    final db = _dbHelper.database;
    
    String where = '';
    List<dynamic> whereArgs = [];
    
    if (kpiId != null) {
      where = 'kpi_id = ?';
      whereArgs.add(kpiId);
    }
    
    if (startDate != null) {
      where += where.isEmpty ? 'processing_date >= ?' : ' AND processing_date >= ?';
      whereArgs.add(startDate);
    }
    
    if (endDate != null) {
      where += where.isEmpty ? 'processing_date <= ?' : ' AND processing_date <= ?';
      whereArgs.add(endDate);
    }

    if (whereArgs.isNotEmpty) {
      await db.delete(
        'mon_kpi_sales',
        where: where,
        whereArgs: whereArgs,
      );
    }
  }

  /// Clear all KPI data
  Future<void> clearAllKpiData() async {
    final db = _dbHelper.database;
    await db.delete('mon_kpi_sales');
  }
}