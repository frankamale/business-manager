import 'package:get/get.dart';
import '../services/api_services.dart';
import '../models/customer.dart';
import '../database/db_helper.dart';
import '../utils/network_helper.dart';

class CustomerController extends GetxController {
  final _apiService = ApiServiceMonitor();
  final _dbHelper = DatabaseHelper();

  // Reactive list of customers
  var customers = <Customer>[].obs;

  // Loading state
  var isLoadingCustomers = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Don't load on init - will be handled by splash screen
  }

  // Load customers from cache (database)
  Future<void> loadCustomersFromCache() async {
    try {
      final cachedCustomers = await _dbHelper.getCustomers();
      customers.value = cachedCustomers;
    } catch (e) {
      // Handle error silently
    }
  }

  // Sync customers from API and save to database
  Future<void> syncCustomersFromAPI({bool showMessage = false}) async {
    try {
      isLoadingCustomers.value = true;

      final fetchedCustomers = await _apiService.fetchCustomers();

      // Save to database
      await _dbHelper.deleteAllCustomers();
      await _dbHelper.insertCustomers(fetchedCustomers);

      // Update sync metadata
      await _dbHelper.updateSyncMetadata('customers', 'success', fetchedCustomers.length);

      // Update in-memory list
      customers.value = fetchedCustomers;

      isLoadingCustomers.value = false;

      if (showMessage) {
        Get.snackbar(
          'Success', "Operation successful",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      isLoadingCustomers.value = false;
      await _dbHelper.updateSyncMetadata('customers', 'failed', 0, e.toString());

      if (showMessage) {
        Get.snackbar(
          'Error',
          'Failed to refresh customers',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  // Refresh customers (pull-to-refresh)
  Future<void> refreshCustomers() async {
    final hasNetwork = await NetworkHelper.hasConnection();
    if (!hasNetwork) {
      Get.snackbar(
        'Offline',
        'Cannot refresh without internet connection',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    await syncCustomersFromAPI(showMessage: true);
  }

  // Get customer by ID
  Customer? getCustomerById(String id) {
    try {
      return customers.firstWhere((customer) => customer.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get customer by fullnames
  Customer? getCustomerByFullnames(String fullnames) {
    try {
      return customers.firstWhere((customer) => customer.fullnames == fullnames);
    } catch (e) {
      return null;
    }
  }
}