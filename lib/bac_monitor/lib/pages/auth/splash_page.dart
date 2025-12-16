import 'dart:async';

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
      final credentials = await _getStoredCredentials();
      final token = await Get.find<MonitorApiService>().getStoredToken();
      final companyId = await Get.find<MonitorApiService>().getStoredCompanyId();
      
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

  /// Attempt to auto-login using stored credentials
  Future<bool> _attemptAutoLogin() async {
    try {
      final credentials = await _getStoredCredentials();
      final apiService = Get.find<MonitorApiService>();
      
      if (credentials['username'] == null || credentials['password'] == null) {
        debugPrint('SplashPage: No stored credentials available for auto-login');
        return false;
      }
      
      debugPrint('SplashPage: Attempting auto-login with stored credentials');
      
      // Check if we already have a valid token (user might already be authenticated)
      final token = await apiService.getStoredToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('SplashPage: Valid token found, skipping re-authentication');
        return true;
      }
      
      // If no token, try to authenticate with stored credentials
      // Note: This would require access to the auth controller, but for now
      // we'll rely on the existing token-based approach
      
    } catch (e) {
      debugPrint('SplashPage: Auto-login failed - $e');
      return false;
    }
    
    return false;
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
    
    // Initialize company ID early in the process
    await _initializeCompanyId();
    
    // Ensure database is open
    await _ensureDatabaseIsOpen();
    
    // Load data from database
    await _loadDataFromDatabase();
    
    // Continue with authentication and navigation
    await _performAuthAndNavigation();
  }

  /// Initialize company ID during splash screen
  Future<void> _initializeCompanyId() async {
    try {
      debugPrint('SplashPage: Initializing company ID');
      final apiService = Get.find<MonitorApiService>();
      await apiService.initializeCompanyId();
      
      // Get the initialized company ID
      final companyId = await apiService.getStoredCompanyId();
      debugPrint('SplashPage: Company ID initialized: $companyId');
      
    } catch (e) {
      debugPrint('SplashPage: Error initializing company ID - $e');
      // Don't fail the app startup if company ID initialization fails
    }
  }

  void _initializeControllers() {
    if (!Get.isRegistered<MonOperatorController>()) {
      Get.put(MonOperatorController());
    }
    
    if (!Get.isRegistered<MonSyncController>()) {
      Get.put(MonSyncController());
    }
    
    if (!Get.isRegistered<MonStoresController>()) {
      Get.put(MonStoresController());
    }
    
    if (!Get.isRegistered<MonStoreKpiTrendController>()) {
      Get.put(MonStoreKpiTrendController());
    }
    
    if (!Get.isRegistered<MonDashboardController>()) {
      Get.put(MonDashboardController());
    }
    
    if (!Get.isRegistered<MonKpiOverviewController>()) {
      Get.put(MonKpiOverviewController());
    }
    
    if (!Get.isRegistered<MonSalesTrendsController>()) {
      Get.put(MonSalesTrendsController());
    }
    
    if (!Get.isRegistered<MonGrossProfitController>()) {
      Get.put(MonGrossProfitController());
    }
    
    if (!Get.isRegistered<MonOutstandingPaymentsController>()) {
      Get.put(MonOutstandingPaymentsController());
    }
    
    if (!Get.isRegistered<MonInventoryController>()) {
      Get.put(MonInventoryController());
    }
  }

  Future<void> _ensureDatabaseIsOpen() async {
    try {
      final db = await _dbHelper.database;
      debugPrint('SplashPage: Database opened successfully');
    } catch (e) {
      debugPrint('SplashPage: Error opening database - $e');
    }
  }

  Future<void> _loadDataFromDatabase() async {
    try {
      final hasNetwork = await NetworkHelper.hasConnection();
      debugPrint('SplashPage: Network available = $hasNetwork');

      // Load data from database for offline use
      final storesController = Get.find<MonStoresController>();
      final inventoryController = Get.find<MonInventoryController>();

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
    final apiService = Get.find<MonitorApiService>();

    // Check if we have valid credentials and company ID
    final hasValidCredentials = await _hasValidCredentials();
    
    if (!hasValidCredentials) {
      debugPrint('SplashPage: No valid credentials found, redirecting to login');
      Get.offAll(() => const UnifiedLoginScreen());
      return;
    }

    // Load company details
    await Get.find<MonOperatorController>().loadCompanyDetailsFromDb();

    final token = await apiService.getStoredToken();
    print('DEBUG: SplashPage._performAuthAndNavigation() - Retrieved token: $token');
    
    if (token == null) {
      print('DEBUG: SplashPage._performAuthAndNavigation() - No token found, redirecting to login');
      Get.offAll(() => const UnifiedLoginScreen());
      return;
    }

    // Attempt auto-login if we have stored credentials but no valid session
    final autoLoginSuccess = await _attemptAutoLogin();
    if (!autoLoginSuccess) {
      debugPrint('SplashPage: Auto-login failed, redirecting to login');
      Get.offAll(() => const UnifiedLoginScreen());
      return;
    }

    // Sync controller is already initialized in _initializeControllers
    
    try {
      final isOnline = await NetworkHelper.hasConnection();
      if (isOnline) {
        debugPrint("SplashPage: Device is online. Syncing recent sales...");
        await apiService.fetchAndCacheAllData();
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
    final operatorController = Get.find<MonOperatorController>();

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


