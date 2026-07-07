import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../models/inventory_data.dart';
import '../services/kpi_sync_service.dart';
import '../../../shared/utils/connectivity_helper.dart';

class MonInventoryController extends GetxController {
  final _dbHelper = UnifiedDatabaseHelper.instance;
  
  // Existing observables (keep these)
  var inventoryItems = <MonitorInventoryItem>[].obs;
  var isLoading = false.obs;
  var hasMoreItems = true.obs;
  
  // NEW: Pagination state
  static const int pageSize = 100;
  int _currentPage = 0;
  int _totalItemCount = 0;
  
  // Search state
  var searchResults = <Map<String, dynamic>>[].obs;
  var isSearching = false.obs;
  String _currentSearchQuery = '';
  Timer? _searchDebounceTimer;
  
  @override
  void onInit() {
    super.onInit();
    debugPrint('MonInventoryController: onInit - NOT fetching data yet');
  }
  
  /// Load first page of inventory (called from splash page)
  /// This loads only the first 100 items to prevent memory issues
  Future<void> loadInventoryFromDb() async {
    try {
      debugPrint('MonInventoryController: Loading first page of inventory');
      isLoading.value = true;
      _currentPage = 0;
      inventoryItems.clear();
      hasMoreItems.value = true;
      
      // Get total count first
      final db = _dbHelper.database;
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM mon_inventory');
      _totalItemCount = countResult.first['count'] as int? ?? 0;
      debugPrint('MonInventoryController: Total inventory items: $_totalItemCount');
      
      // Load first page
      await _loadNextPage();
      
      debugPrint('MonInventoryController: Loaded ${inventoryItems.length} items (page 1)');
    } catch (e) {
      debugPrint('MonInventoryController: Error loading inventory - $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Load next page of inventory (called when user scrolls)
  Future<void> loadMoreInventory() async {
    if (!hasMoreItems.value || isLoading.value) {
      debugPrint('MonInventoryController: No more items to load or already loading');
      return;
    }
    await _loadNextPage();
  }
  
  /// Internal method to load next page
  Future<void> _loadNextPage() async {
    try {
      isLoading.value = true;
      final offset = _currentPage * pageSize;
      
      debugPrint('MonInventoryController: Loading page ${_currentPage + 1} (offset: $offset, limit: $pageSize)');
      
      final db = _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT * FROM mon_inventory LIMIT ? OFFSET ?',
        [pageSize, offset],
      );
      
      if (result.isEmpty) {
        hasMoreItems.value = false;
        debugPrint('MonInventoryController: No more items to load');
      } else {
        final newItems = result.map((e) => MonitorInventoryItem.fromJson(e)).toList();
        inventoryItems.addAll(newItems);
        _currentPage++;
        debugPrint('MonInventoryController: Loaded ${result.length} items, total: ${inventoryItems.length}');
        
        // Check if we've loaded everything
        if (inventoryItems.length >= _totalItemCount) {
          hasMoreItems.value = false;
        }
      }
    } catch (e) {
      debugPrint('MonInventoryController: Error loading more inventory - $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Reset pagination and reload
  Future<void> refreshInventory() async {
    _currentPage = 0;
    hasMoreItems.value = true;
    await loadInventoryFromDb();
  }

  /// Fetch inventory from server, save to DB, then reload first page
  Future<void> refreshInventoryFromServer() async {
    try {
      // Check connectivity before attempting to refresh from server
      final isOnline = await ConnectivityHelper.checkConnectivityAndNotify();
      if (!isOnline) {
        return;
      }

      debugPrint('MonInventoryController: Fetching inventory from server...');
      isLoading.value = true;
      
      // Fetch from API via KpiSyncService
      final kpiSyncService = Get.isRegistered<KpiSyncService>() 
          ? Get.find<KpiSyncService>() 
          : null;
      
      if (kpiSyncService != null) {
        final result = await kpiSyncService.fetchBaselineDatasets();
        
        if (result.inventory.isNotEmpty) {
          debugPrint('MonInventoryController: Got ${result.inventory.length} items from server');
          
          // Store to DB in chunks - optimized
          final dbHelper = UnifiedDatabaseHelper.instance;
          final isFirstSync = await dbHelper.rawQuery('SELECT COUNT(*) as count FROM mon_inventory')
              .then((r) => r.first['count'] as int? ?? 0) == 0;
          if (isFirstSync) {
            await dbHelper.deleteAllMonInventoryItems();
          }
          
          const mapChunkSize = 2000;
          const insertBatchSize = 500;
          int totalItems = result.inventory.length;
          
          for (int chunkStart = 0; chunkStart < totalItems; chunkStart += mapChunkSize) {
            final chunkEnd = (chunkStart + mapChunkSize < totalItems) 
                ? chunkStart + mapChunkSize 
                : totalItems;
            final chunk = result.inventory.sublist(chunkStart, chunkEnd);
            
            final mappedChunk = await compute(
              (List<dynamic> items) => items
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
              chunk,
            );
            
            // Insert in batches using transaction (faster)
            for (int i = 0; i < mappedChunk.length; i += insertBatchSize) {
              final batch = mappedChunk.skip(i).take(insertBatchSize).toList();
              await dbHelper.insertMonInventoryItemsInTransaction(batch);
            }
          }
          
          debugPrint('MonInventoryController: Stored $totalItems items to DB');
        }
      }
      
      // Reset pagination and reload first page
      _currentPage = 0;
      hasMoreItems.value = true;
      inventoryItems.clear();
      
      final db = _dbHelper.database;
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM mon_inventory');
      _totalItemCount = countResult.first['count'] as int? ?? 0;
      
      await _loadNextPage();
      
      debugPrint('MonInventoryController: Refreshed inventory from server, loaded ${inventoryItems.length} items');
    } catch (e) {
      debugPrint('MonInventoryController: Error refreshing from server - $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Get current load progress for display
  String getLoadProgress() {
    if (_totalItemCount == 0) return '0 items';
    return '${inventoryItems.length}/$_totalItemCount items';
  }

  /// Search inventory directly from database with debouncing
  /// [query] - Search term (matches name, code fields)
  void searchInventory(String query) {
    _currentSearchQuery = query;
    
    // Cancel previous timer
    _searchDebounceTimer?.cancel();
    
    if (query.isEmpty) {
      searchResults.clear();
      isSearching.value = false;
      return;
    }
    
    isSearching.value = true;
    
    // Debounce: wait 300ms before executing search
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await _executeSearch(query);
    });
  }

  /// Internal method to execute the database search
  Future<void> _executeSearch(String query) async {
    try {
      final db = _dbHelper.database;
      final searchPattern = '%$query%';
      
      debugPrint('MonInventoryController: Searching DB for "$query"');
      
      // Search across name, code, fields
      final result = await db.rawQuery(
        '''
        SELECT * FROM mon_inventory
        WHERE name LIKE ? OR code LIKE ?
        LIMIT 200
        ''',
        [searchPattern, searchPattern],
      );
      
      searchResults.assignAll(result);
      debugPrint('MonInventoryController: Search returned ${result.length} results');
    } catch (e) {
      debugPrint('MonInventoryController: Search error - $e');
      searchResults.clear();
    } finally {
      isSearching.value = false;
    }
  }

  /// Clear search and return to normal browsing
  void clearSearch() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;
    _currentSearchQuery = '';
    searchResults.clear();
    isSearching.value = false;
  }

  /// Get current search query (for TextField controller sync)
  String get currentSearchQuery => _currentSearchQuery;

  @override
  void onClose() {
    _searchDebounceTimer?.cancel();
    super.onClose();
  }
}