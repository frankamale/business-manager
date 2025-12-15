import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../back_pos/utils/network_helper.dart';
import '../../additions/colors.dart';
import '../../controllers/operator_controller.dart';
import '../../controllers/sync_controller.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/gross_profit_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/kpi_overview_controller.dart';
import '../../controllers/outstanding_payments_controller.dart';
import '../../controllers/salestrends_controller.dart';
import '../../controllers/store_controller.dart';
import '../../controllers/store_kpi_controller.dart';
import '../../services/api_services.dart';
import '../../db/db_helper.dart';
import '../bottom_nav.dart';
import 'Login.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.wait([
      _initializeServicesAndDatabase(),
      Future.delayed(const Duration(seconds: 2)),
    ]);
  }

  Future<void> _initializeServicesAndDatabase() async {
    // Initialize all required controllers
    _initializeControllers();
    
    // Ensure database is open
    await _ensureDatabaseIsOpen();
    
    // Load data from database
    await _loadDataFromDatabase();
    
    // Continue with authentication and navigation
    await _performAuthAndNavigation();
  }

  void _initializeControllers() {
    // Register controllers if not already registered
    if (!Get.isRegistered<OperatorController>()) {
      Get.put(OperatorController());
    }
    
    if (!Get.isRegistered<SyncController>()) {
      Get.put(SyncController());
    }
    
    if (!Get.isRegistered<StoresController>()) {
      Get.put(StoresController());
    }
    
    if (!Get.isRegistered<StoreKpiTrendController>()) {
      Get.put(StoreKpiTrendController());
    }
    
    if (!Get.isRegistered<DashboardController>()) {
      Get.put(DashboardController());
    }
    
    if (!Get.isRegistered<KpiOverviewController>()) {
      Get.put(KpiOverviewController());
    }
    
    if (!Get.isRegistered<SalesTrendsController>()) {
      Get.put(SalesTrendsController());
    }
    
    if (!Get.isRegistered<GrossProfitController>()) {
      Get.put(GrossProfitController());
    }
    
    if (!Get.isRegistered<OutstandingPaymentsController>()) {
      Get.put(OutstandingPaymentsController());
    }
    
    if (!Get.isRegistered<InventoryController>()) {
      Get.put(InventoryController());
    }
  }

  Future<void> _ensureDatabaseIsOpen() async {
    try {
      // Get the database instance - this will open it if not already open
      final db = await _dbHelper.database;
      debugPrint('SplashPage: Database opened successfully');
    } catch (e) {
      debugPrint('SplashPage: Error opening database - $e');
      // Continue even if database fails to open
    }
  }

  Future<void> _loadDataFromDatabase() async {
    try {
      final hasNetwork = await NetworkHelper.hasConnection();
      debugPrint('SplashPage: Network available = $hasNetwork');

      // Load data from database for offline use
      final storesController = Get.find<StoresController>();
      final inventoryController = Get.find<InventoryController>();

      // Load stores from database (fetchAllStores already loads from DB)
      await storesController.fetchAllStores();
      
      // Load inventory from database
      await inventoryController.loadInventoryFromDb();
      
      debugPrint('SplashPage: Data loaded from database successfully');
      
    } catch (e) {
      debugPrint('SplashPage: Error loading data from database - $e');
      // Continue even if data loading fails
    }
  }

  Future<void> _performAuthAndNavigation() async {
    final apiService = Get.find<ApiService>();

    // Load company details
    await Get.find<OperatorController>().loadCompanyDetailsFromDb();

    final token = apiService.getStoredToken();
    if (token == null) {
      Get.offAll(() => const LoginPage());
      return;
    }

    // Sync controller is already initialized in _initializeControllers
    
    try {
      final isOnline = await NetworkHelper.hasConnection();
      if (isOnline) {
        debugPrint("SplashPage: Device is online. Syncing recent sales...");
        await apiService.syncRecentSales();
      } else {
        debugPrint(
          "SplashPage: Device is offline. Proceeding with local data.",
        );
      }
    } catch (e) {
      debugPrint(
        "SplashPage: Error during initial sync. Proceeding with local data. Error: $e",
      );
    }

    Get.offAll(() => const BottomNav());
  }

  // Future<bool> _checkConnectivity() async {
  //   try {
  //     final connectivityResult = await Connectivity().checkConnectivity();
  //     return connectivityResult != ConnectivityResult.none;
  //   } catch (e) {
  //     return false;
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final operatorController = Get.find<OperatorController>();

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        toolbarHeight: 0,
        backgroundColor: PrimaryColors.darkBlue,
      ),
      backgroundColor: PrimaryColors.darkBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.storefront,
              color: PrimaryColors.brightYellow,
              size: 100,
            ),
            const SizedBox(height: 24),
            Obx(() {
              final companyName = operatorController.companyName.value;
              return Text(
                companyName.isNotEmpty && companyName != 'Loading...'
                    ? companyName
                    : 'Welcome',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              );
            }),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                PrimaryColors.brightYellow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


