import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:bac_pos/shared/database/unified_db_helper.dart';
import 'package:bac_pos/back_pos/services/api_services.dart';
import 'package:bac_pos/back_pos/models/service_point.dart';
import 'package:bac_pos/back_pos/utils/network_helper.dart';
import 'package:bac_pos/shared/utils/connectivity_helper.dart';

class ServicePointController extends GetxController {
  final _dbHelper = UnifiedDatabaseHelper.instance;
  final _apiService = Get.find<PosApiService>();

  // Reactive list of service points
  var servicePoints = <ServicePoint>[].obs;
  var salesServicePoints = <ServicePoint>[].obs;

  // Loading state
  var isLoadingServicePoints = false.obs;
  var isSyncingServicePoints = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Don't load on init - will be handled by splash screen
  }

  // Load service points from database (cache)
  Future<void> loadServicePointsFromCache() async {
    try {
      isLoadingServicePoints.value = true;

      await _ensureDatabaseOpen();

      final points = await _dbHelper.getServicePoints();
      servicePoints.value = points;

      final salesPoints = await _dbHelper.getSalesServicePoints();
      salesServicePoints.value = salesPoints;

      isLoadingServicePoints.value = false;
    } catch (e) {
      isLoadingServicePoints.value = false;
    }
  }

  /// Opens the last known company database when it is closed.
  /// Without this, getServicePoints() throws "Database not opened" and the
  /// list stays empty (e.g. after a failed server login or when the splash
  /// screen skipped the smart sync on an offline start).
  Future<void> _ensureDatabaseOpen() async {
    if (_dbHelper.isDatabaseOpen) return;

    final companyId = await _readCompanyIdFromStorage();
    if (companyId != null && companyId.isNotEmpty) {
      await _dbHelper.openForCompany(companyId);
    }
  }

  Future<String?> _readCompanyIdFromStorage() async {
    try {
      final companyInfo = await _apiService.getCompanyInfo();
      final companyId = companyInfo['companyId'];
      if (companyId != null && companyId.isNotEmpty) return companyId;
    } catch (e) {
      // Fall back to GetStorage below
    }

    try {
      return GetStorage().read('last_company_id') as String?;
    } catch (e) {
      return null;
    }
  }

  // Sync service points from API to local database
  Future<void> syncServicePointsFromAPI({bool showMessage = false}) async {
    try {
      // Check connectivity before attempting sync
      final isOnline = await ConnectivityHelper.checkConnectivityAndNotify();
      if (!isOnline) {
        return;
      }

      isSyncingServicePoints.value = true;

      // Fetch service points from API
      final points = await _apiService.fetchServicePoints();

      // Save service points to database
      await _dbHelper.insertServicePointModels(points);

      // Update sync metadata
      await _dbHelper.updateSyncMetadata('service_points', 'success', points.length);

      // Reload service points after sync
      await loadServicePointsFromCache();

      isSyncingServicePoints.value = false;

      if (showMessage) {
        Get.snackbar(
          'Success', "Operation successful",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      isSyncingServicePoints.value = false;
      await _dbHelper.updateSyncMetadata('service_points', 'failed', 0, e.toString());

      if (showMessage) {
        Get.snackbar(
          'Error',
          'Failed to refresh service points',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  // Refresh service points (pull-to-refresh)
  Future<void> refreshServicePoints() async {
    final hasNetwork = await NetworkHelper.hasConnection();
    if (!hasNetwork) {
      // Fall back to cache so the list can still be (re)populated offline
      await loadServicePointsFromCache();
      if (servicePoints.isEmpty) {
        Get.snackbar(
          'Offline',
          'Cannot refresh without internet connection',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return;
    }
    await syncServicePointsFromAPI(showMessage: true);
  }

  // Get service point by ID
  ServicePoint? getServicePointById(String id) {
    try {
      return servicePoints.firstWhere((sp) => sp.id == id);
    } catch (e) {
      return null;
    }
  }
}
