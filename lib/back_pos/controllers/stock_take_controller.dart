import 'package:get/get.dart';
import 'package:bac_pos/shared/database/unified_db_helper.dart';
import 'package:bac_pos/back_pos/models/stock_take.dart';

class StockTakeController extends GetxController {
  final _dbHelper = UnifiedDatabaseHelper.instance;

  var stockTakes = <StockTake>[].obs;
  var isLoading = false.obs;

  /// Load saved stock takes, optionally filtered to a service point.
  Future<void> loadStockTakes({String? servicePointId}) async {
    try {
      isLoading.value = true;
      final takes = await _dbHelper.getStockTakes(servicePointId: servicePointId);
      stockTakes.value = takes;
    } catch (e) {
      stockTakes.clear();
    } finally {
      isLoading.value = false;
    }
  }

  /// Persist a stock take and refresh the in-memory list.
  Future<void> addStockTake(
    StockTake stockTake, {
    String? servicePointId,
  }) async {
    await _dbHelper.insertStockTake(stockTake);
    await loadStockTakes(servicePointId: servicePointId);
  }

  Future<void> deleteStockTake(String id, {String? servicePointId}) async {
    await _dbHelper.deleteStockTake(id);
    await loadStockTakes(servicePointId: servicePointId);
  }
}
