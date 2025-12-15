import 'package:get/get.dart';
import '../database/db_helper.dart';
import '../services/api_services.dart';
import '../models/inventory_item.dart';
import '../utils/network_helper.dart';

class InventoryController extends GetxController {
  final _dbHelper = DatabaseHelper();
  final _apiService = ApiService();

  // Reactive list of inventory items
  var inventoryItems = <InventoryItem>[].obs;
  var filteredItems = <InventoryItem>[].obs;
  var categories = <String>[].obs;

  // Loading state
  var isLoadingInventory = false.obs;
  var isSyncingInventory = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Don't load on init - will be handled by splash screen
  }

  // Load inventory from database (cache)
  Future<void> loadInventoryFromCache() async {
    try {
      isLoadingInventory.value = true;

      final items = await _dbHelper.getInventoryItems();
      inventoryItems.value = items;
      filteredItems.value = items;

      final cats = await _dbHelper.getInventoryCategories();
      categories.value = cats;

      isLoadingInventory.value = false;
    } catch (e) {
      isLoadingInventory.value = false;
    }
  }

  // Sync inventory from API to local database
  Future<void> syncInventoryFromAPI({bool showMessage = false}) async {
    try {
      isSyncingInventory.value = true;

      // Fetch inventory from API
      final items = await _apiService.fetchInventory();

      // Save inventory to database
      await _dbHelper.insertInventoryItems(items);

      // Update sync metadata
      await _dbHelper.updateSyncMetadata('inventory', 'success', items.length);

      // Reload inventory after sync
      await loadInventoryFromCache();

      isSyncingInventory.value = false;

      if (showMessage) {
        Get.snackbar(
          'Success', "Operation successful",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      isSyncingInventory.value = false;
      await _dbHelper.updateSyncMetadata('inventory', 'failed', 0, e.toString());

      if (showMessage) {
        Get.snackbar(
          'Error',
          'Failed to refresh inventory',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      rethrow;
    }
  }

  // Refresh inventory (pull-to-refresh)
  Future<void> refreshInventory() async {
    final hasNetwork = await NetworkHelper.hasConnection();
    if (!hasNetwork) {
      Get.snackbar(
        'Offline',
        'Cannot refresh without internet connection',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    await syncInventoryFromAPI(showMessage: true);
  }

  // Search inventory items
  Future<void> searchInventory(String query) async {
    try {
      if (query.isEmpty) {
        filteredItems.value = inventoryItems;
        return;
      }

      isLoadingInventory.value = true;
      final results = await _dbHelper.searchInventoryItems(query);
      filteredItems.value = results;
      isLoadingInventory.value = false;
    } catch (e) {
      isLoadingInventory.value = false;
    }
  }

  // Filter by category
  Future<void> filterByCategory(String category) async {
    try {
      isLoadingInventory.value = true;

      if (category.isEmpty || category == 'All') {
        filteredItems.value = inventoryItems;
      } else {
        final results = await _dbHelper.getInventoryItemsByCategory(category);
        filteredItems.value = results;
      }

      isLoadingInventory.value = false;
    } catch (e) {
      isLoadingInventory.value = false;
    }
  }

  // Get inventory item by ID
  InventoryItem? getInventoryItemById(String id) {
    try {
      return inventoryItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get inventory count
  Future<int> getInventoryCount() async {
    try {
      return await _dbHelper.getInventoryCount();
    } catch (e) {
      return 0;
    }
  }

  // Filter by service point type (soldfrom)
  Future<void> filterByServicePointType(String servicePointType) async {
    try {
      isLoadingInventory.value = true;

      final results = await _dbHelper.getInventoryItemsBySoldFrom(servicePointType);
      filteredItems.value = results;

      isLoadingInventory.value = false;
    } catch (e) {
      isLoadingInventory.value = false;
    }
  }
}
