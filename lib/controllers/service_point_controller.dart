import 'package:get/get.dart';
import '../database/db_helper.dart';
import '../services/api_services.dart';
import '../models/service_point.dart';
import '../utils/network_helper.dart';

class ServicePointController extends GetxController {
  final _dbHelper = DatabaseHelper();
  final _apiService = ApiService();

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

      final points = await _dbHelper.getServicePoints();
      servicePoints.value = points;

      final salesPoints = await _dbHelper.getSalesServicePoints();
      salesServicePoints.value = salesPoints;

      isLoadingServicePoints.value = false;
    } catch (e) {
      isLoadingServicePoints.value = false;
    }
  }

  // Sync service points from API to local database
  Future<void> syncServicePointsFromAPI({bool showMessage = false}) async {
    try {
      isSyncingServicePoints.value = true;

      // Fetch service points from API
      final points = await _apiService.fetchServicePoints();

      // Save service points to database
      await _dbHelper.insertServicePoints(points);

      // Update sync metadata
      await _dbHelper.updateSyncMetadata('service_points', 'success', points.length);

      // Reload service points after sync
      await loadServicePointsFromCache();

      isSyncingServicePoints.value = false;

      if (showMessage) {
        Get.snackbar(
          'Success',
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
      Get.snackbar(
        'Offline',
        'Cannot refresh without internet connection',
        snackPosition: SnackPosition.BOTTOM,
      );
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
