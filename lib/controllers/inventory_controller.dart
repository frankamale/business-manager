import 'package:get/get.dart';
import '../database/db_helper.dart';
import '../services/api_services.dart';
import '../models/inventory_item.dart';

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
    loadInventory();
  }

  // Load inventory from database
  Future<void> loadInventory() async {
    try {
      print('📦 Loading inventory from database...');
      isLoadingInventory.value = true;

      final items = await _dbHelper.getInventoryItems();
      inventoryItems.value = items;
      filteredItems.value = items;

      final cats = await _dbHelper.getInventoryCategories();
      categories.value = cats;

      isLoadingInventory.value = false;

      print('✅ Successfully loaded ${items.length} inventory items from database');
      print('📂 Categories found: ${cats.length}');
    } catch (e) {
      isLoadingInventory.value = false;
      print('❌ Error loading inventory from database: $e');
    }
  }

  // Sync inventory from API to local database
  Future<void> syncInventoryFromAPI() async {
    try {
      print('🔄 Starting inventory sync from API to database...');
      isSyncingInventory.value = true;

      // Fetch inventory from API
      final items = await _apiService.fetchInventory();

      // Save inventory to database
      print('💾 Saving ${items.length} inventory items to local database...');
      await _dbHelper.insertInventoryItems(items);

      print('✅ Successfully synced ${items.length} inventory items to database');

      // Reload inventory after sync
      await loadInventory();

      isSyncingInventory.value = false;
    } catch (e) {
      isSyncingInventory.value = false;
      print('❌ Error syncing inventory from API: $e');
      rethrow;
    }
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
