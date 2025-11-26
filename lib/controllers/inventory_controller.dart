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
      print('📦 Loading inventory from cache...');
      isLoadingInventory.value = true;

      final items = await _dbHelper.getInventoryItems();
      inventoryItems.value = items;
      filteredItems.value = items;

      final cats = await _dbHelper.getInventoryCategories();
      categories.value = cats;

      isLoadingInventory.value = false;

      print('✅ Loaded ${items.length} inventory items from cache');
      print('📂 Categories found: ${cats.length}');
    } catch (e) {
      isLoadingInventory.value = false;
      print('❌ Error loading inventory from cache: $e');
    }
  }

  // Sync inventory from API to local database
  Future<void> syncInventoryFromAPI({bool showMessage = false}) async {
    try {
      print('📦 Syncing inventory from API...');
      isSyncingInventory.value = true;

      // Fetch inventory from API
      final items = await _apiService.fetchInventory();

      // Save inventory to database
      print('💾 Saving ${items.length} inventory items to local database...');
      await _dbHelper.insertInventoryItems(items);

      // Update sync metadata
      await _dbHelper.updateSyncMetadata('inventory', 'success', items.length);

      print('✅ Successfully synced ${items.length} inventory items to database');

      // Reload inventory after sync
      await loadInventoryFromCache();

      isSyncingInventory.value = false;

      if (showMessage) {
        Get.snackbar(
          'Success',
          '${items.length} inventory items refreshed',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      isSyncingInventory.value = false;
      await _dbHelper.updateSyncMetadata('inventory', 'failed', 0, e.toString());
      print('❌ Error syncing inventory from API: $e');

      if (showMessage) {
        Get.snackbar(
          'Error',
          'Failed to refresh inventory: $e',
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

      print('🔍 Search for "$query" returned ${results.length} results');
    } catch (e) {
      isLoadingInventory.value = false;
      print('❌ Error searching inventory: $e');
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
      print('🏷️ Filtered by category "$category": ${filteredItems.length} items');
    } catch (e) {
      isLoadingInventory.value = false;
      print('❌ Error filtering by category: $e');
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
      print('❌ Error getting inventory count: $e');
      return 0;
    }
  }
}
