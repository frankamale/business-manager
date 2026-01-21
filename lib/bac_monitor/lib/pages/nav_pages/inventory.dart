import 'dart:async';
import 'package:flutter/material.dart';

import '../../additions/colors.dart';
import '../../../../shared/database/unified_db_helper.dart';
import '../../models/inventory_data.dart';
import '../../models/service_points.dart';
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
    _loadInventoryFromDb();
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

  Future<void> _loadInventoryFromDb() async {
    setState(() => _isLoading = true);
    try {
      final db = _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('mon_inventory');
      _allItems = maps.map((map) => MonitorInventoryItem.fromJson(map)).toList();
      setState(() {
        _filteredItems = _getFilteredItems();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading inventory from DB: $e");
      setState(() => _isLoading = false);
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
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query.toLowerCase();
        _filteredItems = _getFilteredItems();
        if (_searchQuery.isEmpty) _searchFocusNode.unfocus();
      });
    });
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
      backgroundColor: PrimaryColors.darkBlue,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar(
                backgroundColor: PrimaryColors.darkBlue,
                pinned: true,
                floating: true,
                snap: true,
                forceElevated: innerBoxIsScrolled,
                iconTheme: const IconThemeData(color: Colors.white),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildViewDropdown(),
                    const SizedBox(width: 10),
                    _buildServicePointDropdown(),
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
                        indicatorColor: PrimaryColors.brightYellow,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        indicatorWeight: 3.0,
                        tabs: const [
                          Tab(text: 'Low Stock'),
                          Tab(text: 'Overstocked'),
                          Tab(text: 'All Items'),
                        ],
                      )
                    : null,
              ),
            ),
          ];
        },
        body: Builder(
          builder: (innerContext) => RefreshIndicator(
            onRefresh: _loadInventoryFromDb,
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

  Widget _buildViewDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        dropdownColor: PrimaryColors.lightBlue,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        style: const TextStyle(
          color: Colors.white,
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

  Widget _buildServicePointDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        dropdownColor: PrimaryColors.lightBlue,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        style: const TextStyle(
          color: Colors.white,
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_filteredItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "No items found.",
            style: TextStyle(color: Colors.white54, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 8.0),
          sliver: SliverToBoxAdapter(
            child: InventoryDataTable(items: _filteredItems, isServicesView: _selectedView == "Services"),
          ),
        ),
      ],
    );
  }
}
