import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../additions/colors.dart';
import '../../../../shared/database/unified_db_helper.dart';
import '../../controllers/mon_inventory_controller.dart';
import '../../models/inventory_data.dart';
import '../../models/service_points.dart';
import '../../services/api_services.dart';
import '../../widgets/inventory/data_table.dart';
import '../../widgets/inventory/floating_search_bar.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage>
    with SingleTickerProviderStateMixin {
  final _dbHelper = UnifiedDatabaseHelper.instance;
  late MonInventoryController _inventoryController;

  List<MonitorInventoryItem> _allItems = [];
  List<MonitorInventoryItem> _filteredItems = [];
  List<String> _servicePoints = ["All"];
  String _selectedServicePoint = "All";
  Map<String, String> _facilityToType = {};

  String _selectedView = "Inventory";
  final List<String> _viewOptions = ["Inventory", "Services"];

  String _searchQuery = '';
  bool _isLoading = true;
  late FocusNode _searchFocusNode;
  Timer? _debounce;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    // Initialize controller
    if (Get.isRegistered<MonInventoryController>()) {
      _inventoryController = Get.find<MonInventoryController>();
    } else {
      _inventoryController = Get.put(MonInventoryController());
    }
    
    // Load first page of inventory from DB
    _inventoryController.loadInventoryFromDb();
    
    // Listen to controller changes
    _inventoryController.inventoryItems.listen((_) {
      if (mounted) {
        _applyFiltersFromController();
      }
    });
    
    _loadServicePoints();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _debounce?.cancel();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _applyFiltersFromController() {
    setState(() {
      _allItems = List.from(_inventoryController.inventoryItems);
      _filteredItems = _getFilteredItems();
      _isLoading = _inventoryController.isLoading.value && _allItems.isEmpty;
    });
  }

  /// Build search results into MonitorInventoryItem list
  List<MonitorInventoryItem> _buildSearchResults() {
    return _inventoryController.searchResults
        .map((e) => MonitorInventoryItem.fromJson(e))
        .toList();
  }

  Future<void> _loadServicePoints() async {
    try {
      final db = _dbHelper.database;

      final result = await db.query(
        'mon_service_points',
        columns: ['id', 'name', 'facilityName', 'servicepointtype'],
        orderBy: 'facilityName ASC',
      );
      final allPoints = result.map((row) => ServicePoint.fromMap(row)).toList();

      Map<String, String> facilityToType = {};
      List<String> uniqueNames = [];

      for (var sp in allPoints) {
        facilityToType[sp.name] = sp.servicePointType;
        if (!uniqueNames.contains(sp.name)) {
          uniqueNames.add(sp.name);
        }
      }

      setState(() {
        _servicePoints = ['All', ...uniqueNames];
        _facilityToType = facilityToType;
      });
    } catch (e) {
      debugPrint("Error loading service points: $e");
    }
  }

  /// Fetch inventory from server and store in DB, then reload from DB
  Future<void> _refreshInventoryFromServer() async {
    try {
      final apiService = Get.find<MonitorApiService>();
      
      // Fetch inventory from server
      final response = await apiService.getWithAuth('/inventory/');
      if (response.body.isNotEmpty) {
        final inventoryData = json.decode(response.body) as List;
        final items = inventoryData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        
        // Store in database
        await _dbHelper.deleteAllMonInventoryItems();
        await _dbHelper.insertMonInventoryItems(items);
        
        debugPrint("InventoryPage: Fetched and stored ${items.length} inventory items from server");
      }
      
      // Reload from database using controller
      await _inventoryController.refreshInventory();
    } catch (e) {
      debugPrint("InventoryPage: Error refreshing inventory from server: $e");
      // Fall back to loading from local DB
      await _inventoryController.refreshInventory();
    }
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _filteredItems = _getFilteredItems();
      });
      _searchFocusNode.unfocus();
    }
  }

  void _handleSearchChanged(String query) {
    _inventoryController.searchInventory(query);
    if (query.isEmpty) _searchFocusNode.unfocus();
  }

  List<MonitorInventoryItem> _getFilteredItems() {
    List<MonitorInventoryItem> currentItems = _allItems;

    if (_selectedServicePoint != "All") {
      final type = _facilityToType[_selectedServicePoint];
      if (type != null && type.isNotEmpty) {
        currentItems = currentItems
            .where((item) => item.servicePoint == type)
            .toList();
      }
    }

    currentItems = currentItems
        .where(
          (item) =>
              item.name.toLowerCase().contains(_searchQuery) ||
              item.sku.toLowerCase().contains(_searchQuery),
        )
        .toList();

    // Filter by category based on selected view
    if (_selectedView == "Services") {
      currentItems = currentItems
          .where((item) => item.packaging.toLowerCase().contains("service"))
          .toList();
    } else {
      currentItems = currentItems.toList();
    }

    if (_selectedView == "Inventory") {
      switch (_tabController.index) {
        case 0:
          return currentItems
              .where((item) => item.quantityOnHand < 20)
              .toList();
        case 1:
          return currentItems
              .where((item) => item.quantityOnHand > 100)
              .toList();
        default:
          return currentItems;
      }
    } else {
      return currentItems;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar(
                backgroundColor: AppColors.getCardColor(context),
                pinned: true,
                floating: true,
                snap: true,
                forceElevated: innerBoxIsScrolled,
                iconTheme: IconThemeData(color: AppColors.getTextPrimaryColor(context)),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildViewDropdown(context),
                    const SizedBox(width: 10),
                    _buildServicePointDropdown(context),
                  ],
                ),
                expandedHeight: _selectedView == "Services" ? 120.0 : 180,
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: EdgeInsets.only(
                      bottom: _selectedView == "Services" ? 0.0 : 50.0,
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FloatingSearchBar(
                        onSearchChanged: _handleSearchChanged,
                        focusNode: _searchFocusNode,
                      ),
                    ),
                  ),
                ),
                bottom: _selectedView == "Inventory"
                    ? TabBar(
                        controller: _tabController,
                        indicatorColor: AppColors.getAccentColor(context),
                        labelColor: AppColors.getTextPrimaryColor(context),
                        unselectedLabelColor: AppColors.getTextSecondaryColor(context),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        indicatorWeight: 3.0,
                        tabs: const [
                          Tab(text: 'All Items'),
                          Tab(text: 'Low Stock'),
                          Tab(text: 'Overstocked'),

                        ],
                      )
                    : null,
              ),
            ),
          ];
        },
        body: Builder(
          builder: (innerContext) => RefreshIndicator(
            onRefresh: _refreshInventoryFromServer,
            child: _selectedView == "Inventory"
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInventoryList(innerContext),
                      _buildInventoryList(innerContext),
                      _buildInventoryList(innerContext),
                    ],
                  )
                : _buildInventoryList(innerContext),
          ),
        ),
      ),
    );
  }

  Widget _buildViewDropdown(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        dropdownColor: AppColors.getCardColor(context),
        icon: Icon(Icons.arrow_drop_down, color: AppColors.getTextPrimaryColor(context)),
        style: TextStyle(
          color: AppColors.getTextPrimaryColor(context),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        value: _selectedView,
        items: _viewOptions.map((view) {
          return DropdownMenuItem<String>(value: view, child: Text(view));
        }).toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            setState(() {
              _selectedView = newValue;
              _filteredItems = _getFilteredItems();
            });
          }
        },
      ),
    );
  }

  Widget _buildServicePointDropdown(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        dropdownColor: AppColors.getCardColor(context),
        icon: Icon(Icons.arrow_drop_down, color: AppColors.getTextPrimaryColor(context)),
        style: TextStyle(
          color: AppColors.getTextPrimaryColor(context),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        value: _selectedServicePoint,
        items: _servicePoints.map((sp) {
          return DropdownMenuItem<String>(
            value: sp,
            child: Text(sp, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            setState(() {
              _selectedServicePoint = newValue;
              _filteredItems = _getFilteredItems();
            });
          }
        },
      ),
    );
  }

  Widget _buildInventoryList(BuildContext context) {
    return Obx(() {
      final isSearching = _inventoryController.isSearching.value;
      final searchResults = _inventoryController.searchResults;
      final inventoryItems = _inventoryController.inventoryItems;
      final hasMore = _inventoryController.hasMoreItems.value;

      // Use search results when searching, otherwise use normal inventory
      final List<MonitorInventoryItem> displayItems;
      if (searchResults.isNotEmpty) {
        displayItems = searchResults
            .map((e) => MonitorInventoryItem.fromJson(e))
            .toList();
      } else {
        displayItems = _filteredItems;
      }

      if (_isLoading && displayItems.isEmpty) {
        return Center(
          child: CircularProgressIndicator(color: AppColors.getAccentColor(context)),
        );
      }

      if (displayItems.isEmpty && !hasMore) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              "No items found.",
              style: TextStyle(color: AppColors.getTextSecondaryColor(context), fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          // Only load more for normal inventory, not search results
          if (searchResults.isEmpty &&
              scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.8) {
            if (_inventoryController.hasMoreItems.value && !_inventoryController.isLoading.value) {
              _inventoryController.loadMoreInventory();
            }
          }
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 8.0),
              sliver: SliverToBoxAdapter(
                child: InventoryDataTable(items: displayItems, isServicesView: _selectedView == "Services"),
              ),
            ),
            // Loading indicator at bottom when loading more
            if (_inventoryController.isLoading.value && displayItems.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.getAccentColor(context)),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
