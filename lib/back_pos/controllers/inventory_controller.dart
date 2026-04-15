import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:bac_pos/shared/database/unified_db_helper.dart';
import 'package:bac_pos/back_pos/services/api_services.dart';
import 'package:bac_pos/back_pos/models/inventory_item.dart';
import 'package:bac_pos/back_pos/utils/network_helper.dart';

class InventoryController extends GetxController {
  final _dbHelper = UnifiedDatabaseHelper.instance;
  final _apiService = Get.find<PosApiService>();

  var inventoryItems = <InventoryItem>[].obs;
  var filteredItems = <InventoryItem>[].obs;
  var categories = <String>[].obs;

  var isLoadingInventory = false.obs;
  var isSyncingInventory = false.obs;
  var hasMoreItems = true.obs;

  static const int pageSize = 100;
  int _currentPage = 0;
  int _totalItemCount = 0;

  String _currentSearchQuery = '';
  Timer? _searchDebounceTimer;

  @override
  void onInit() {
    super.onInit();
    // Don't load on init - will be handled by splash screen
  }

  // Load first page of inventory from database (cache) - paginated
  Future<void> loadInventoryFromCache() async {
    try {
      isLoadingInventory.value = true;
      _currentPage = 0;
      inventoryItems.clear();
      hasMoreItems.value = true;

      _totalItemCount = await _dbHelper.getInventoryTotalCount();
      final items = await _dbHelper.getInventoryItems(limit: pageSize, offset: 0);
      inventoryItems.addAll(items);
      filteredItems.value = inventoryItems.toList();

      final cats = await _dbHelper.getInventoryCategories();
      categories.value = cats;

      if (inventoryItems.length >= _totalItemCount) {
        hasMoreItems.value = false;
      }

      isLoadingInventory.value = false;
    } catch (e) {
      isLoadingInventory.value = false;
    }
  }

  // Load more inventory (pagination)
  Future<void> loadMoreInventory() async {
    if (!hasMoreItems.value || isLoadingInventory.value) {
      return;
    }
    try {
      isLoadingInventory.value = true;
      _currentPage++;
      final offset = _currentPage * pageSize;
      final items = await _dbHelper.getInventoryItems(limit: pageSize, offset: offset);
      inventoryItems.addAll(items);
      filteredItems.value = inventoryItems.toList();

      if (inventoryItems.length >= _totalItemCount) {
        hasMoreItems.value = false;
      }
      isLoadingInventory.value = false;
    } catch (e) {
      isLoadingInventory.value = false;
    }
  }

  // Reset and reload first page
  Future<void> reloadInventory() async {
    _currentPage = 0;
    hasMoreItems.value = true;
    inventoryItems.clear();
    await loadInventoryFromCache();
  }

  // Search inventory items - queries directly from DB
  void searchInventory(String query) {
    _currentSearchQuery = query;
    _searchDebounceTimer?.cancel();

    if (query.isEmpty) {
      filteredItems.value = inventoryItems.toList();
      return;
    }

    isLoadingInventory.value = true;
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    try {
      final results = await _dbHelper.searchInventoryItems(query, limit: 200);
      filteredItems.value = results;
    } catch (e) {
      filteredItems.clear();
    } finally {
      isLoadingInventory.value = false;
    }
  }

  void clearSearch() {
    _searchDebounceTimer?.cancel();
    _currentSearchQuery = '';
    filteredItems.value = inventoryItems.toList();
  }

  // Sync inventory from API to local database
  Future<void> syncInventoryFromAPI({bool showMessage = false}) async {
    try {
      isSyncingInventory.value = true;

      // Fetch inventory from API
      final items = await _apiService.fetchInventory();

      if (items.isNotEmpty) {
        debugPrint('InventoryController: Got ${items.length} items from API');
        
        // Delete existing inventory first 
        await _dbHelper.deleteAllInventoryItems();
        
        // Insert in chunks with compute and delays 
        const mapChunkSize = 1000;
        const insertBatchSize = 500;
        int totalItems = items.length;
        
        for (int chunkStart = 0; chunkStart < totalItems; chunkStart += mapChunkSize) {
          final chunkEnd = (chunkStart + mapChunkSize < totalItems) 
              ? chunkStart + mapChunkSize 
              : totalItems;
          final chunk = items.sublist(chunkStart, chunkEnd);
          
          // Convert to maps using compute (off main isolate)
          final mappedChunk = await compute(
            (List<InventoryItem> items) => items.map((e) => e.toMap()).toList(),
            chunk,
          );
          
          // Insert in batches of 500
          for (int i = 0; i < mappedChunk.length; i += insertBatchSize) {
            final batch = mappedChunk.skip(i).take(insertBatchSize).toList();
            await _dbHelper.insertInventoryItems(batch);
            if (i + insertBatchSize < mappedChunk.length) {
              await Future.delayed(const Duration(milliseconds: 50));
            }
          }
          
          await Future.delayed(const Duration(milliseconds: 50));
        }
        
        debugPrint('InventoryController: Stored $totalItems items to DB');
      }

      // Update sync metadata
      await _dbHelper.updateSyncMetadata('inventory', 'success', items.length);

      // Reset pagination and reload first page
      if (items.isNotEmpty) {
        _currentPage = 0;
        hasMoreItems.value = true;
        inventoryItems.clear();
        filteredItems.clear();
        await loadInventoryFromCache();
      }

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
