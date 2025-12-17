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
      
    
      
    } catch (e) {
      debugPrint('SplashPage: Auto-login failed - $e');
      return false;
    }
    
    return false;
  }

  Future<void> _initializeApp() async {
    debugPrint('SplashPage: Before splash delay');
    
    // Execute initialization sequentially to avoid race conditions
    try {
      await _initializeServicesAndDatabase();
    } catch (e) {
      debugPrint('SplashPage: Critical error during initialization: $e');
      // If initialization fails, still show the splash for minimum time
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('SplashPage: After splash delay (with error)');
      return;
    }
    
    // Only proceed with navigation if initialization was successful
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('SplashPage: After splash delay');
  }

  Future<void> _initializeServicesAndDatabase() async {
    _initializeControllers();
    
    // Initialize company ID FIRST - this is critical
    await _initializeCompanyId();
    
    // Now ensure database is open with the correct company ID
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
    debugPrint('SplashPage: Initializing controllers');
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
      debugPrint('SplashPage: Attempting to open database');
      
      // First, ensure we have a company ID set
      final apiService = Get.find<MonitorApiService>();
      String? companyId = await apiService.getStoredCompanyId();
      
      if (companyId == null || companyId.isEmpty) {
        debugPrint('SplashPage: No company ID found, setting default for offline use');
        await apiService.storeCompanyId('default_offline_company');
        companyId = 'default_offline_company';
      }
      
      debugPrint('SplashPage: Using company ID: $companyId');
      
      // Now open the database
      final db = await _dbHelper.database;
      debugPrint('SplashPage: Database opened successfully');
      
      // Verify we can actually query the database
      try {
        final companyDetails = await Get.find<MonOperatorController>().loadCompanyDetailsFromDb();
        debugPrint('SplashPage: Database verification successful, company details loaded');
      } catch (e) {
        debugPrint('SplashPage: No company details found in database (this is normal for first offline use)');
      }
      
    } catch (e) {
      debugPrint('SplashPage: Error opening database - $e');
      
      // Try to recover by using default company
      try {
        debugPrint('SplashPage: Attempting recovery with default company');
        final apiService = Get.find<MonitorApiService>();
        await apiService.storeCompanyId('default_offline_company');
        final db = await _dbHelper.database;
        debugPrint('SplashPage: Recovery successful with default database');
      } catch (recoveryError) {
        debugPrint('SplashPage: Recovery failed - $recoveryError');
        // If all else fails, we'll continue but the app may have issues
      }
    }
  }

  Future<void> _loadDataFromDatabase() async {
    try {
      debugPrint('SplashPage: Checking network connectivity');
      final hasNetwork = await NetworkHelper.hasConnection();
      debugPrint('SplashPage: Network available = $hasNetwork');

      // Load data from database for offline use
      debugPrint('SplashPage: Loading data from database');
      final storesController = Get.find<MonStoresController>();
      final inventoryController = Get.find<MonInventoryController>();

      // Load stores from database (fetchAllStores already loads from DB)
      try {
        await storesController.fetchAllStores();
        debugPrint('SplashPage: Stores loaded successfully');
        
        // Check if we have any stores
        if (storesController.storeList.isEmpty || storesController.storeList.length == 1) {
          debugPrint('SplashPage: No stores found in database - this might be first offline use');
        }
      } catch (e) {
        debugPrint('SplashPage: Error loading stores - $e');
      }
      
      // Load inventory from database
      try {
        await inventoryController.loadInventoryFromDb();
        debugPrint('SplashPage: Inventory loaded successfully');
        
        // Check if we have any inventory
        if (inventoryController.inventoryItems.isEmpty) {
          debugPrint('SplashPage: No inventory found in database - this might be first offline use');
        }
      } catch (e) {
        debugPrint('SplashPage: Error loading inventory - $e');
      }
      
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
      debugPrint('SplashPage: No valid credentials found, showing error (redirecting to login)');
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
        try {
          await apiService.fetchAndCacheAllData();
          debugPrint("SplashPage: Data sync completed successfully");
        } catch (syncError) {
          debugPrint("SplashPage: Data sync failed, but continuing with local data: $syncError");
          // Even if sync fails, we can still proceed with cached data
        }
      } else {
        debugPrint(
          "SplashPage: Device is offline. Proceeding with local data.",
        );
      }
    } catch (e) {
      debugPrint(
        "SplashPage: Error during network check or sync. Proceeding with local data. Error: $e",
      );
    }

    debugPrint('SplashPage: Before navigation to BottomNav');
    
    // Check if we have sufficient data for offline use
    await _checkOfflineDataAvailability();
    
    Get.offAll(() => const BottomNav());
  }
  
  /// Check if we have sufficient cached data for offline use
  Future<void> _checkOfflineDataAvailability() async {
    try {
      final isOnline = await NetworkHelper.hasConnection();
      
      if (!isOnline) {
        debugPrint('SplashPage: Checking offline data availability');
        
        final storesController = Get.find<MonStoresController>();
        final inventoryController = Get.find<MonInventoryController>();
        final operatorController = Get.find<MonOperatorController>();
        
        bool hasSufficientData = true;
        
        // Check if we have basic company information
        final companyName = operatorController.companyName.value;
        if (companyName.isEmpty || companyName == 'Loading...') {
          debugPrint('SplashPage: No company information available offline');
          hasSufficientData = false;
        }
        
        // Check if we have any stores
        if (storesController.storeList.length <= 1) { // Only the "All" option
          debugPrint('SplashPage: No stores available offline');
          hasSufficientData = false;
        }
        
        // Check if we have any inventory
        if (inventoryController.inventoryItems.isEmpty) {
          debugPrint('SplashPage: No inventory available offline');
          hasSufficientData = false;
        }
        
        if (!hasSufficientData) {
          debugPrint('SplashPage: Insufficient offline data - showing warning');
          // In a real app, you might want to show a warning to the user
          // that they're offline with limited data
        } else {
          debugPrint('SplashPage: Sufficient offline data available');
        }
      }
    } catch (e) {
      debugPrint('SplashPage: Error checking offline data availability: $e');
    }
  }



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


