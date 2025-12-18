import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import '../../../../back_pos/utils/network_helper.dart';
import '../../additions/colors.dart';
import '../../controllers/mon_dashboard_controller.dart';
import '../../controllers/mon_gross_profit_controller.dart';
import '../../controllers/mon_kpi_overview_controller.dart';
import '../../controllers/mon_operator_controller.dart';
import '../../controllers/mon_outstanding_payments_controller.dart';
import '../../controllers/mon_inventory_controller.dart';
import '../../controllers/mon_salestrends_controller.dart';
import '../../controllers/mon_store_controller.dart';
import '../../controllers/mon_store_kpi_controller.dart';
import '../../controllers/mon_sync_controller.dart';
import '../../services/api_services.dart';
import '../../db/db_helper.dart';
import '../bottom_nav.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    debugPrint('SplashPage: initState called');
    _initializeApp();
  }

  /// Retrieve stored credentials from FlutterSecureStorage
  Future<Map<String, String?>> _getStoredCredentials() async {
    try {
      final username = await _secureStorage.read(key: 'login_username');
      final password = await _secureStorage.read(key: 'login_password');
      return {
        'username': username,
        'password': password,
      };
    } catch (e) {
      debugPrint('SplashPage: Error retrieving stored credentials - $e');
      return {
        'username': null,
        'password': null,
      };
    }
  }

  /// Check if we have valid stored credentials
  Future<bool> _hasValidCredentials() async {
    try {
      debugPrint('SplashPage: Checking stored credentials');
      final credentials = await _getStoredCredentials();
      final apiService = Get.find<MonitorApiService>();
      final token = await apiService.getStoredToken();
      final companyId = await apiService.getStoredCompanyId();

      return credentials['username'] != null &&
          credentials['username']!.isNotEmpty &&
          credentials['password'] != null &&
          credentials['password']!.isNotEmpty &&
          token != null &&
          token.isNotEmpty &&
          companyId != null &&
          companyId.isNotEmpty;
    } catch (e) {
      debugPrint('SplashPage: Error checking valid credentials - $e');
      return false;
    }
  }

  Future<void> _initializeApp() async {
    debugPrint('SplashPage: Starting app initialization');

    // Run splash delay in parallel with initialization
    await Future.wait([
      _initializeServicesAndDatabase(),
      Future.delayed(const Duration(seconds: 2)),
    ]);
  }

  Future<void> _initializeServicesAndDatabase() async {
    try {
      // STEP 1: Initialize company ID FIRST (before anything else)
      debugPrint('SplashPage: Step 1 - Initializing company ID');
      await _initializeCompanyId();

      // STEP 2: Ensure database is properly opened for the company
      debugPrint('SplashPage: Step 2 - Opening database');
      await _ensureDatabaseIsOpen();

      // STEP 3: Check credentials and token
      debugPrint('SplashPage: Step 3 - Checking credentials');
      final hasValidCredentials = await _hasValidCredentials();

      if (!hasValidCredentials) {
        debugPrint('SplashPage: No valid credentials found, redirecting to login');
        Get.offAll(() => const UnifiedLoginScreen());
        return;
      }

      // STEP 4: Sync data from server if online (BEFORE initializing controllers)
      debugPrint('SplashPage: Step 4 - Syncing data from server');
      await _syncDataFromServer();

      // STEP 5: Initialize controllers AFTER data is synced
      debugPrint('SplashPage: Step 5 - Initializing controllers');
      _initializeControllers();

      // STEP 6: Load initial data from database into controllers
      debugPrint('SplashPage: Step 6 - Loading data into controllers');
      await _loadDataIntoControllers();

      // STEP 7: Navigate to main screen
      debugPrint('SplashPage: Step 7 - Navigating to BottomNav');
      Get.offAll(() => const BottomNav());

    } catch (e) {
      debugPrint('SplashPage: Fatal error during initialization - $e');
      Get.offAll(() => const UnifiedLoginScreen());
    }
  }

  /// Initialize company ID during splash screen - CALLED ONLY ONCE
  Future<void> _initializeCompanyId() async {
    try {
      debugPrint('SplashPage: Initializing company ID');
      final apiService = Get.find<MonitorApiService>();

      // This method now handles caching internally
      await apiService.initializeCompanyId();

      // Get the initialized company ID (from cache)
      final companyId = await apiService.getStoredCompanyId();
      debugPrint('SplashPage: Company ID initialized: $companyId');

    } catch (e) {
      debugPrint('SplashPage: Error initializing company ID - $e');
      throw Exception('Failed to initialize company ID: $e');
    }
  }

  Future<void> _ensureDatabaseIsOpen() async {
    try {
      // Force database to open for the current company
      final db = await _dbHelper.database;
      debugPrint('SplashPage: Database opened successfully');

      // Verify we can query the database
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM service_points');
      debugPrint('SplashPage: Database verification - service_points count: ${result.first['count']}');

    } catch (e) {
      debugPrint('SplashPage: Error opening database - $e');
      throw Exception('Failed to open database: $e');
    }
  }

  /// Sync data from server BEFORE initializing controllers
  Future<void> _syncDataFromServer() async {
    try {
      final apiService = Get.find<MonitorApiService>();
      final isOnline = await NetworkHelper.hasConnection();

      if (isOnline) {
        debugPrint("SplashPage: Device is online. Syncing all data from server...");
        await apiService.fetchAndCacheAllData();
        debugPrint("SplashPage: Data sync completed successfully");
      } else {
        debugPrint("SplashPage: Device is offline. Using cached data.");
      }

      // Load company details into operator controller
      if (!Get.isRegistered<MonOperatorController>()) {
        Get.put(MonOperatorController(), permanent: true);
      }
      await Get.find<MonOperatorController>().loadCompanyDetailsFromDb();

    } catch (e) {
      debugPrint("SplashPage: Error during sync - $e. Will use cached data.");
      // Don't fail - we can work with cached data
    }
  }

  void _initializeControllers() {
    debugPrint('SplashPage: Initializing controllers (without triggering data fetch)');

    // Note: We don't call Get.put here because controllers will
    // auto-initialize when their widgets are built
    // This prevents premature data fetching

    // Only initialize essential non-data controllers
    if (!Get.isRegistered<MonDashboardController>()) {
      Get.put(MonDashboardController(), permanent: true);
    }

    if (!Get.isRegistered<MonSyncController>()) {
      Get.put(MonSyncController(), permanent: true);
    }
  }

  /// Load data into controllers AFTER database is ready
  Future<void> _loadDataIntoControllers() async {
    try {
      debugPrint('SplashPage: Loading data into controllers');

      // Initialize stores controller and load stores
      if (!Get.isRegistered<MonStoresController>()) {
        final storesController = Get.put(MonStoresController(), permanent: true);
        await storesController.fetchAllStores();
      }

      // Initialize inventory controller and load inventory
      if (!Get.isRegistered<MonInventoryController>()) {
        final inventoryController = Get.put(MonInventoryController(), permanent: true);
        await inventoryController.loadInventoryFromDb();
      }

      debugPrint('SplashPage: Controllers loaded with data successfully');

    } catch (e) {
      debugPrint('SplashPage: Error loading data into controllers - $e');
      // Continue anyway - data can be loaded later
    }
  }

  @override
  Widget build(BuildContext context) {
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
              if (!Get.isRegistered<MonOperatorController>()) {
                return const Text(
                  'Welcome',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }

              final operatorController = Get.find<MonOperatorController>();
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
            const SizedBox(height: 16),
            const Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}