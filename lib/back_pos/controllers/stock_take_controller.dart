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

  /// Upload a single stock take to the server.
  ///
  /// TODO: Wire this to the real stock-take upload endpoint once it exists.
  /// For now it just marks the record as uploaded locally so the rest of the
  /// flow (fiscalise, badges, "upload later") can be used and tested.
  Future<void> uploadStockTake(
    StockTake take, {
    String? servicePointId,
  }) async {
    // await _apiService.uploadStockTake(take.toServerJson());
    await _dbHelper.updateStockTakeStatus(take.id, 'uploaded');
    await loadStockTakes(servicePointId: servicePointId);
  }

  /// Fiscalise an already-uploaded stock take.
  ///
  /// TODO: Wire this to the real fiscalise endpoint. Only call after a
  /// successful upload (the UI enforces this).
  Future<void> fiscaliseStockTake(
    StockTake take, {
    String? servicePointId,
  }) async {
    // await _apiService.fiscaliseStockTake(take.id);
    await _dbHelper.updateStockTakeStatus(take.id, 'fiscalised');
    await loadStockTakes(servicePointId: servicePointId);
  }

  /// Upload every still-pending stock take. Returns how many were pushed.
  ///
  /// TODO: Replace the per-item local status flip with the real endpoint call
  /// and proper success/failure handling.
  Future<int> uploadAll({String? servicePointId}) async {
    final pending =
        stockTakes.where((t) => t.uploadStatus == 'pending').toList();
    for (final take in pending) {
      // await _apiService.uploadStockTake(take.toServerJson());
      await _dbHelper.updateStockTakeStatus(take.id, 'uploaded');
    }
    await loadStockTakes(servicePointId: servicePointId);
    return pending.length;
  }
}
