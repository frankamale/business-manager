import 'package:get/get.dart';
import '../database/db_helper.dart';
import '../services/api_services.dart';
import '../models/service_point.dart';

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
    loadServicePoints();
  }

  // Load service points from database
  Future<void> loadServicePoints() async {
    try {
      print('Loading service points from database...');
      isLoadingServicePoints.value = true;

      final points = await _dbHelper.getServicePoints();
      servicePoints.value = points;

      final salesPoints = await _dbHelper.getSalesServicePoints();
      salesServicePoints.value = salesPoints;

      isLoadingServicePoints.value = false;

      print('Successfully loaded ${points.length} service points from database');
      print('Sales service points: ${salesPoints.length}');
    } catch (e) {
      isLoadingServicePoints.value = false;
      print('Error loading service points from database: $e');
    }
  }

  // Sync service points from API to local database
  Future<void> syncServicePointsFromAPI() async {
    try {
      print('Starting service points sync from API to database...');
      isSyncingServicePoints.value = true;

      // Fetch service points from API
      final points = await _apiService.fetchServicePoints();

      // Save service points to database
      print('Saving ${points.length} service points to local database...');
      await _dbHelper.insertServicePoints(points);

      print('Successfully synced ${points.length} service points to database');

      // Reload service points after sync
      await loadServicePoints();

      isSyncingServicePoints.value = false;
    } catch (e) {
      isSyncingServicePoints.value = false;
      print('Error syncing service points from API: $e');
    }
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
