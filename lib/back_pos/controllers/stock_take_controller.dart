import 'package:get/get.dart';
import 'package:bac_pos/shared/database/unified_db_helper.dart';
import 'package:bac_pos/back_pos/models/stock_take.dart';
import 'package:bac_pos/back_pos/models/stock_take_session.dart';

class StockTakeController extends GetxController {
  final _dbHelper = UnifiedDatabaseHelper.instance;

  // Sessions shown on the list screen.
  var sessions = <StockTakeSession>[].obs;
  var isLoading = false.obs;

  // Items of the session currently being viewed.
  var sessionItems = <StockTake>[].obs;
  var isLoadingItems = false.obs;

  // ---- Sessions ----

  Future<void> loadSessions({String? servicePointId}) async {
    try {
      isLoading.value = true;
      sessions.value =
          await _dbHelper.getStockTakeSessions(servicePointId: servicePointId);
    } catch (e) {
      sessions.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<StockTakeSession> createSession({
    String reference = '',
    String note = '',
    String? servicePointId,
  }) async {
    final now = DateTime.now();
    final session = StockTakeSession(
      id: 'sts_${now.microsecondsSinceEpoch}',
      reference: reference,
      note: note,
      servicePointId: servicePointId,
      createdAt: now,
      updatedAt: now,
      uploadStatus: 'pending',
    );
    await _dbHelper.insertStockTakeSession(session);
    await loadSessions(servicePointId: servicePointId);
    return session;
  }

  Future<void> renameSession(
    StockTakeSession session, {
    String? reference,
    String? note,
    String? servicePointId,
  }) async {
    await _dbHelper.updateStockTakeSession(
      session.copyWith(
        reference: reference,
        note: note,
        updatedAt: DateTime.now(),
      ),
    );
    await loadSessions(servicePointId: servicePointId);
  }

  Future<void> deleteSession(String id, {String? servicePointId}) async {
    await _dbHelper.deleteStockTakeSession(id);
    await loadSessions(servicePointId: servicePointId);
  }

  // ---- Line items ----

  Future<void> loadSessionItems(String sessionId) async {
    try {
      isLoadingItems.value = true;
      sessionItems.value = await _dbHelper.getStockTakeItems(sessionId);
    } catch (e) {
      sessionItems.clear();
    } finally {
      isLoadingItems.value = false;
    }
  }

  /// Insert or update a line item (same id => update), then refresh the items
  /// of its session and bump the session's updated_at.
  Future<void> saveItem(StockTake item) async {
    await _dbHelper.insertStockTake(item);
    if (item.stockTakeId.isNotEmpty) {
      await _dbHelper.touchStockTakeSession(item.stockTakeId);
      await loadSessionItems(item.stockTakeId);
    }
  }

  Future<void> deleteItem(String id, {required String stockTakeId}) async {
    await _dbHelper.deleteStockTake(id);
    await loadSessionItems(stockTakeId);
  }

  // ---- Upload / fiscalise (session level) ----

  /// Upload a whole session to the server.
  ///
  /// TODO: Wire to the real stock-take upload endpoint. For now it just marks
  /// the session uploaded locally so the rest of the flow can be used/tested.
  Future<void> uploadSession(
    StockTakeSession session, {
    String? servicePointId,
  }) async {
    // await _apiService.uploadStockTakeSession(session, items);
    await _dbHelper.updateStockTakeSessionStatus(session.id, 'uploaded');
    await loadSessions(servicePointId: servicePointId);
  }

  /// Fiscalise an already-uploaded session.
  ///
  /// TODO: Wire to the real fiscalise endpoint.
  Future<void> fiscaliseSession(
    StockTakeSession session, {
    String? servicePointId,
  }) async {
    // await _apiService.fiscaliseStockTakeSession(session.id);
    await _dbHelper.updateStockTakeSessionStatus(session.id, 'fiscalised');
    await loadSessions(servicePointId: servicePointId);
  }

  /// Upload every still-pending session. Returns how many were pushed.
  Future<int> uploadAll({String? servicePointId}) async {
    final pending =
        sessions.where((s) => s.uploadStatus == 'pending').toList();
    for (final s in pending) {
      // await _apiService.uploadStockTakeSession(...);
      await _dbHelper.updateStockTakeSessionStatus(s.id, 'uploaded');
    }
    await loadSessions(servicePointId: servicePointId);
    return pending.length;
  }
}
