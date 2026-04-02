import 'package:bac_pos/back_pos/controllers/customer_controller.dart';
import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import '../../../../back_pos/utils/network_helper.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../additions/colors.dart';
import '../../controllers/mon_dashboard_controller.dart';
import '../../controllers/mon_operator_controller.dart';
import '../../controllers/mon_inventory_controller.dart';
import '../../controllers/mon_store_controller.dart';
import '../../controllers/mon_sync_controller.dart';
import '../../controllers/mon_kpi_overview_controller.dart';
import '../../controllers/mon_gross_profit_controller.dart';
import '../../controllers/mon_outstanding_payments_controller.dart';
import '../../controllers/mon_salestrends_controller.dart';
import '../../controllers/mon_data_sync_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../services/api_services.dart';
import '../../services/kpi_sync_service.dart';
import '../../services/sync_state_manager.dart';
import '../../../../shared/database/unified_db_helper.dart';
import '../../../../initialise/splashscreen.dart';
import '../../widgets/more/splash_loader.dart';
import '../bottom_nav.dart';

class SplashPage extends StatefulWidget {
  /// Whether the app is running in offline mode
  final bool isOffline;
  
  const SplashPage({super.key, this.isOffline = false});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final _dbHelper = UnifiedDatabaseHelper.instance;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Track offline mode
  bool _isOfflineMode = false;
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    debugPrint('SplashPage: initState called');
    _initializeApp();
  }

  void _updateStatus(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
      });
    }
    debugPrint('SplashPage: $message');
  }

  /// Retrieve stored credentials from FlutterSecureStorage
  Future<Map<String, String?>> _getStoredCredentials() async {
    try {
      final username = await _secureStorage.read(key: 'login_username');
      final password = await _secureStorage.read(key: 'login_password');
      return {'username': username, 'password': password};
    } catch (e) {
      debugPrint('SplashPage: Error retrieving stored credentials - $e');
      return {'username': null, 'password': null};
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

  /// Check if we have cached data in the database
  Future<bool> _hasCachedData() async {
    try {
      final db = _dbHelper.database;

      // Check if we have any sales data
      final salesCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM mon_sales',
      );
      final hasSales = (salesCount.first['count'] as int? ?? 0) > 0;

      // Check if we have service points
      final servicePointsCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM mon_service_points',
      );
      final hasServicePoints =
          (servicePointsCount.first['count'] as int? ?? 0) > 0;

      // Check if we have company details
      final companyCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM company_details',
      );
      final hasCompany = (companyCount.first['count'] as int? ?? 0) > 0;

      debugPrint(
        'SplashPage: Cached data check - Sales: $hasSales, ServicePoints: $hasServicePoints, Company: $hasCompany',
      );

      return hasSales && hasServicePoints && hasCompany;
    } catch (e) {
      debugPrint('SplashPage: Error checking cached data - $e');
      return false;
    }
  }

  Future<void> _initializeApp() async {
    debugPrint('SplashPage: Starting app initialization (offline: ${widget.isOffline})');
    await _initializeServicesAndDatabase();
  }

  Future<void> _initializeServicesAndDatabase() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Initialize offline mode state from widget parameter
      _isOfflineMode = widget.isOffline;

      // Track network connectivity status (default to true if in offline mode to skip online-only logic)
      bool isOnline = true;

      // STEP 1: Check network connectivity first (if not already in offline mode)
      if (!widget.isOffline) {
        _updateStatus('Checking network...');
        isOnline = await NetworkHelper.hasConnection();
        debugPrint(
          'SplashPage: Network check took ${stopwatch.elapsedMilliseconds}ms - Online: $isOnline',
        );
        if (!isOnline) {
          // Network check failed after starting online - redirect to offline handling
          debugPrint('SplashPage: Lost connection during startup, handling offline mode');
          _isOfflineMode = true;
          await _handleOfflineInitialization();
          return;
        }
      } else {
        debugPrint('SplashPage: Starting in offline mode');
      }

      // STEP 2: Initialize company ID FIRST (works offline)
      _updateStatus('Initializing company...');
      stopwatch.reset();
      await _initializeCompanyIdOfflineSafe();
      debugPrint(
        'SplashPage: Company init took ${stopwatch.elapsedMilliseconds}ms',
      );

      // STEP 3: Ensure database is properly opened for the company
      _updateStatus('Opening database...');
      stopwatch.reset();
      await _ensureDatabaseIsOpen();
      debugPrint(
        'SplashPage: Database check took ${stopwatch.elapsedMilliseconds}ms',
      );

      // STEP 4: Check credentials and token
      _updateStatus('Verifying credentials...');
      stopwatch.reset();
      final hasValidCredentials = await _hasValidCredentials();
      debugPrint(
        'SplashPage: Credentials check took ${stopwatch.elapsedMilliseconds}ms',
      );

      if (!hasValidCredentials) {
        debugPrint(
          'SplashPage: No valid credentials found, redirecting to login',
        );
        Get.offAll(() => const UnifiedLoginScreen());
        return;
      }

      // STEP 5: Check if we have cached data (important for offline mode)
      stopwatch.reset();
      final hasCachedData = await _hasCachedData();
      debugPrint(
        'SplashPage: Cached data check took ${stopwatch.elapsedMilliseconds}ms - Has data: $hasCachedData',
      );

      if (widget.isOffline && !hasCachedData) {
        debugPrint(
          'SplashPage: Offline mode with no cached data - need to go online first',
        );
        _showOfflineNoDataDialog();
        return;
      }

      if (isOnline) {
        // Register SyncStateManager for centralized sync coordination
        _updateStatus('Checking sync status...');
        final syncManager = Get.put(SyncStateManager(), permanent: true);
        final scenario = await syncManager.determineSyncScenario();
        
        switch (scenario) {
          case SyncScenario.firstLogin:
            _updateStatus('First login - fetching today\'s data...');
            await _performFirstLoginSync(syncManager);
            break;
            
          case SyncScenario.subsequentLogin:
            _updateStatus('Refreshing today\'s data...');
            await _performSubsequentLoginSync(syncManager);
            break;
            
          case SyncScenario.offline:
          case SyncScenario.cacheValid:
            debugPrint('SplashPage: Using cached data - no fetch needed');
            break;
        }
      } else if (!widget.isOffline) {
        _updateStatus('Loading cached data...');
        await _loadCompanyDetailsOffline();
      }

      // STEP 7: Initialize controllers AFTER data is synced/loaded
      _updateStatus('Initializing app...');
      stopwatch.reset();
      _initializeControllers();
      debugPrint(
        'SplashPage: Controllers init took ${stopwatch.elapsedMilliseconds}ms',
      );

      // STEP 8: Load initial data from database into controllers
      _updateStatus('Loading data...');
      stopwatch.reset();
      await _loadDataIntoControllers();
      debugPrint(
        'SplashPage: Load data into controllers took ${stopwatch.elapsedMilliseconds}ms',
      );

      // STEP 9: Navigate to main screen after the current frame completes
      // Using WidgetsBinding to schedule navigation after the frame renders,
      // keeping the progress indicator animating during the transition.
      debugPrint(
        'SplashPage: Total initialization complete, navigating to BottomNav',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAll(() => const BottomNav());
        
        // Show offline mode snackbar if in offline mode
        if (widget.isOffline) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (Get.context != null) {
              ScaffoldMessenger.of(Get.context!).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.white),
                      const SizedBox(width: 12),
                      const Text('You are offline. Showing cached data.'),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          });
        }
        
        // STEP 10: Post-mount historical sync (background task)
        // Trigger historical data fetch after UI is mounted (only if online)
        if (!widget.isOffline) {
          _triggerHistoricalSync();
        }
      });
    } catch (e) {
      debugPrint('SplashPage: Fatal error during initialization - $e');
      _showErrorDialog(e.toString());
    }
  }

  /// Initialize company ID with offline support
  Future<void> _initializeCompanyIdOfflineSafe() async {
    try {
      debugPrint('SplashPage: Initializing company ID (offline-safe)');
      final apiService = Get.find<MonitorApiService>();

      // Try to get stored company ID first (works offline)
      final storedCompanyId = await apiService.getStoredCompanyId();

      if (storedCompanyId != null && storedCompanyId.isNotEmpty) {
        debugPrint('SplashPage: Using stored company ID: $storedCompanyId');

        // Check if database is already open for this company
        if (_dbHelper.isDatabaseOpen &&
            _dbHelper.currentCompanyId == storedCompanyId) {
          debugPrint(
            'SplashPage: Database already open for company: $storedCompanyId',
          );
          return;
        }

        // Open database for the company
        await _dbHelper.openForCompany(storedCompanyId);
        debugPrint('SplashPage: Database opened for company: $storedCompanyId');
        return;
      }

      // If no stored ID in secure storage, try GetStorage fallback
      final box = GetStorage();
      final lastCompanyId = box.read(kLastCompanyIdKey) as String?;
      if (lastCompanyId != null && lastCompanyId.isNotEmpty) {
        debugPrint('SplashPage: Using GetStorage company ID: $lastCompanyId');
        await _dbHelper.openForCompany(lastCompanyId);
        // Also store in secure storage for future use
        await apiService.storeCompanyId(lastCompanyId);
        return;
      }

      // If no stored ID and we're online, try to initialize via API service
      if (!_isOfflineMode) {
        debugPrint('SplashPage: No stored company ID, initializing from API');
        await apiService.initializeCompanyId();
        final companyId = await apiService.getStoredCompanyId();
        debugPrint('SplashPage: Company ID initialized from API: $companyId');
      } else {
        // Offline with no stored company ID - this is a problem
        debugPrint('SplashPage: Offline mode with no stored company ID');
        throw Exception('Cannot use app offline without prior login');
      }
    } catch (e) {
      debugPrint('SplashPage: Error initializing company ID - $e');

      // If we're offline, we can't proceed without a stored company ID
      if (_isOfflineMode) {
        debugPrint('SplashPage: Offline mode - cannot proceed without stored company ID');
        throw Exception('Cannot use app offline without prior login');
      }

      throw Exception('Failed to initialize company ID: $e');
    }
  }

  Future<void> _ensureDatabaseIsOpen() async {
    try {
      // Check if database is open
      if (!_dbHelper.isDatabaseOpen) {
        debugPrint(
          'SplashPage: Database not open, this should have been done in _initializeCompanyIdOfflineSafe',
        );
        throw Exception(
          'Database was not opened during company initialization',
        );
      }

      debugPrint(
        'SplashPage: Database is open for company: ${_dbHelper.currentCompanyId}',
      );

      // Verify we can query the database
      final db = _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM mon_service_points',
      );
      debugPrint(
        'SplashPage: Database verification - service_points count: ${result.first['count']}',
      );
    } catch (e) {
      debugPrint('SplashPage: Error verifying database - $e');
      throw Exception('Failed to verify database: $e');
    }
  }

  /// Load company details from database (offline-safe)
  Future<void> _loadCompanyDetailsOffline() async {
    try {
      if (!Get.isRegistered<MonOperatorController>()) {
        Get.put(MonOperatorController(), permanent: true);
      }
      await Get.find<MonOperatorController>().loadCompanyDetailsFromDb();
      debugPrint('SplashPage: Company details loaded from database');
    } catch (e) {
      debugPrint('SplashPage: Error loading company details - $e');
      // Continue anyway - not critical
    }
  }

  /// Sync data from server BEFORE initializing controllers
  Future<void> _syncDataFromServer() async {
    try {
      final apiService = Get.find<MonitorApiService>();

      debugPrint(
        "SplashPage: Device is online. Syncing all data from server...",
      );
      await apiService.fetchAndCacheAllData();
      debugPrint("SplashPage: Data sync completed successfully");

      // Load company details into operator controller
      await _loadCompanyDetailsOffline();
    } catch (e) {
      debugPrint("SplashPage: Error during sync - $e");

      // Check if we have cached data to fall back on
      final hasCachedData = await _hasCachedData();

      if (hasCachedData) {
        debugPrint(
          "SplashPage: Sync failed but we have cached data. Continuing...",
        );
        setState(() {
          _isOfflineMode = true; // Switch to offline mode
        });
        await _loadCompanyDetailsOffline();
      } else {
        throw Exception('Failed to sync data and no cached data available');
      }
    }
  }

  /// First login sync: fetch today's KPI + baseline data only
  Future<void> _performFirstLoginSync(SyncStateManager syncManager) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      MonDataSyncController? dataSyncController;
      if (!Get.isRegistered<MonDataSyncController>()) {
        dataSyncController = Get.put(MonDataSyncController(), permanent: true);
      } else {
        dataSyncController = Get.find<MonDataSyncController>();
      }

      dataSyncController?.syncStatusMessage.listen((message) {
        if (message.isNotEmpty) {
          _updateStatus(message);
        }
      });

      // Only fetch today + baseline (NO historical)
      await dataSyncController?.performInitialSyncWithBaseline();
      syncManager.markBaselineLoaded();
      
      debugPrint('SplashPage: First login sync took ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('SplashPage: First login sync failed - $e');
      final hasCachedData = await _hasCachedData();
      if (!hasCachedData) {
        throw Exception('Failed to sync data and no cached data available');
      }
    }
  }

  /// Subsequent login sync: fetch today's data only if missing/expired
  Future<void> _performSubsequentLoginSync(SyncStateManager syncManager) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      MonDataSyncController? dataSyncController;
      if (!Get.isRegistered<MonDataSyncController>()) {
        dataSyncController = Get.put(MonDataSyncController(), permanent: true);
      } else {
        dataSyncController = Get.find<MonDataSyncController>();
      }

      dataSyncController?.syncStatusMessage.listen((message) {
        if (message.isNotEmpty) {
          _updateStatus(message);
        }
      });

      // Incremental sync only fetches today's delta
      await dataSyncController?.performIncrementalSync();
      
      debugPrint('SplashPage: Subsequent login sync took ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('SplashPage: Subsequent login sync failed - $e');
      // Continue with cache - not fatal
    }
  }

  void _initializeControllers() {
    debugPrint(
      'SplashPage: Initializing controllers (without triggering data fetch)',
    );

    // Only initialize essential non-data controllers
    if (!Get.isRegistered<MonDashboardController>()) {
      Get.put(MonDashboardController(), permanent: true);
    }

    if (!Get.isRegistered<MonSyncController>()) {
      Get.put(MonSyncController(), permanent: true);
    }
    
    // Start periodic background sync for sales data ONLY if online
    if (!widget.isOffline) {
      Get.find<MonSyncController>().startPeriodicSync();
    } else {
      debugPrint('SplashPage: Offline mode - skipping periodic sync initialization');
    }
  }

  /// Load data into controllers AFTER database is ready
  Future<void> _loadDataIntoControllers() async {
    try {
      debugPrint('SplashPage: Loading data into controllers');

      // Initialize stores controller and load stores
      MonStoresController storesController;
      if (!Get.isRegistered<MonStoresController>()) {
        storesController = Get.put(MonStoresController(), permanent: true);
      } else {
        storesController = Get.find<MonStoresController>();
        // Reset and re-fetch for account switch
        storesController.isInitialized.value = false;
      }
      await storesController.fetchAllStores();

      // Initialize inventory controller and load inventory
      MonInventoryController inventoryController;
      if (!Get.isRegistered<MonInventoryController>()) {
        inventoryController = Get.put(
          MonInventoryController(),
          permanent: true,
        );
      } else {
        inventoryController = Get.find<MonInventoryController>();
      }
      // Always ensure inventory is loaded
      await inventoryController.loadInventoryFromDb();

      // Load company details into MonOperatorController
      if (Get.isRegistered<MonOperatorController>()) {
        await Get.find<MonOperatorController>().loadCompanyDetailsFromDb();
      }

      // Load profile data into ProfileController
      if (Get.isRegistered<ProfileController>()) {
        await Get.find<ProfileController>().loadProfileData();
      }

      if (Get.isRegistered<CustomerController>()) {
        final customerController = Get.find<CustomerController>();
        debugPrint('SplashPage: Loading customers from cache...');
        await customerController.loadCustomersFromCache();
        debugPrint('SplashPage: Loaded ${customerController.customers.length} customers from cache');
        
        // Only sync if online
        if (!widget.isOffline) {
          debugPrint('SplashPage: Syncing customers from API...');
          await customerController.syncCustomersFromAPI();
          debugPrint('SplashPage: Synced ${customerController.customers.length} customers from API');
        }
        debugPrint('SplashPage: Customers loaded successfully - Total: ${customerController.customers.length}');
      }

      // Ensure MonKpiOverviewController is registered so it can fetch data
      // before markTodayDataLoaded() is called
      MonKpiOverviewController kpiController;
      if (!Get.isRegistered<MonKpiOverviewController>()) {
        kpiController = Get.put(MonKpiOverviewController(), permanent: true);
      } else {
        kpiController = Get.find<MonKpiOverviewController>();
      }
      // Trigger KPI data fetch to populate activeMembers
      await kpiController.fetchKpiData();
      debugPrint("Total customers ${kpiController.activeMembers.value}");

      // Mark today's data as loaded so controllers don't re-fetch
      if (Get.isRegistered<SyncStateManager>()) {
        Get.find<SyncStateManager>().markTodayDataLoaded();
      }

      debugPrint('SplashPage: Controllers loaded with data successfully');
    } catch (e) {
      debugPrint('SplashPage: Error loading data into controllers - $e');
      // Continue anyway - data can be loaded later
    }
  }

  /// Reset and refresh all dashboard controllers for account switch
  Future<void> _refreshDashboardControllers() async {
    debugPrint('SplashPage: Refreshing dashboard controllers');

    // Reset and refresh KPI Overview Controller
    if (Get.isRegistered<MonKpiOverviewController>()) {
      final kpiController = Get.find<MonKpiOverviewController>();
      kpiController.isInitialized.value = false;
      await kpiController.fetchKpiData();
      kpiController.isInitialized.value = true;
      debugPrint('SplashPage: KPI controller refreshed');
    }

    // Refresh Gross Profit Controller (doesn't have isInitialized)
    if (Get.isRegistered<MonGrossProfitController>()) {
      final grossProfitController = Get.find<MonGrossProfitController>();
      await grossProfitController.fetchGrossProfitData();
      debugPrint('SplashPage: Gross profit controller refreshed');
    }

    // Refresh Outstanding Payments Controller (doesn't have isInitialized)
    if (Get.isRegistered<MonOutstandingPaymentsController>()) {
      final outstandingController =
          Get.find<MonOutstandingPaymentsController>();
      await outstandingController.fetchOutstandingPaymentsData();
      debugPrint('SplashPage: Outstanding payments controller refreshed');
    }

    // Refresh Sales Trends Controller (doesn't have isInitialized)
    if (Get.isRegistered<MonSalesTrendsController>()) {
      final salesTrendsController = Get.find<MonSalesTrendsController>();
      await salesTrendsController.fetchAllData();
      debugPrint('SplashPage: Sales trends controller refreshed');
    }
  }

  /// Trigger historical data sync in background - fetches month by month
  void _triggerHistoricalSync() {
    _runHistoricalLoop();
  }

  Future<void> _runHistoricalLoop() async {
    try {
      final syncManager = Get.isRegistered<SyncStateManager>() 
          ? Get.find<SyncStateManager>() 
          : null;
          
      while (true) {
        String? nextMonth;
        if (syncManager != null) {
          nextMonth = await syncManager.getNextHistoricalMonthToFetch();
        } else {
          // Fallback: check DB directly
          final now = DateTime.now();
          bool found = false;
          for (int i = 1; i < 12; i++) {
            final monthStart = DateTime(now.year, now.month - i, 1);
            final monthEnd = DateTime(now.year, now.month - i + 1, 0);
            final hasData = await _dbHelper.hasKpiDataForDateRange(
              DateFormat('yyyy-MM-dd').format(monthStart),
              DateFormat('yyyy-MM-dd').format(monthEnd),
            );
            if (!hasData) {
              nextMonth = DateFormat('yyyy-MM').format(monthStart);
              found = true;
              break;
            }
          }
          if (!found) break;
        }
        
        if (nextMonth == null) {
          debugPrint('[SplashPage] All historical data loaded');
          break;
        }
        
        debugPrint('[SplashPage] Fetching historical month: $nextMonth');
        final parts = nextMonth.split('-');
        final monthStart = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
        final monthEnd = DateTime(int.parse(parts[0]), int.parse(parts[1]) + 1, 0);
        
        final apiService = Get.find<MonitorApiService>();
        await apiService.syncAllKpiData(monthStart, monthEnd);
        
        syncManager?.markHistoricalMonthLoaded(nextMonth);
        
        // Small delay between months to prevent server overload
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('[SplashPage] Historical sync loop failed: $e');
    }
  }

  /// Handle offline initialization when connection is lost during startup
  Future<void> _handleOfflineInitialization() async {
    try {
      debugPrint('SplashPage: Handling offline initialization');
      
      // Try to get company ID from GetStorage
      final box = GetStorage();
      final lastCompanyId = box.read('last_company_id') as String?;
      final lastUserRole = box.read('last_user_role') as String?;
      
      if (lastCompanyId != null && lastCompanyId.isNotEmpty) {
        // Open database for the company
        await _dbHelper.openForCompany(lastCompanyId);
        
        // Load company details
        await _loadCompanyDetailsOffline();
        
        // Initialize controllers
        _initializeControllers();
        
        // Load data into controllers
        await _loadDataIntoControllers();
        
        // Navigate to main screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offAll(() => const BottomNav());
          
          // Show offline snackbar
          Future.delayed(const Duration(milliseconds: 500), () {
            if (Get.context != null) {
              ScaffoldMessenger.of(Get.context!).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.white),
                      const SizedBox(width: 12),
                      const Text('You are offline. Showing cached data.'),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          });
        });
      } else {
        debugPrint('SplashPage: No offline credentials found');
        _showOfflineNoDataDialog();
      }
    } catch (e) {
      debugPrint('SplashPage: Error in offline initialization - $e');
      _showErrorDialog('Failed to initialize offline: $e');
    }
  }

  void _showOfflineNoDataDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('No Internet Connection'),
        content: const Text(
          'You are offline and there is no cached data available. '
          'Please connect to the internet to sync data first.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.offAll(() => const UnifiedLoginScreen());
            },
            child: const Text('OK'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _showErrorDialog(String error) {
    Get.dialog(
      AlertDialog(
        title: const Text('Initialization Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.offAll(() => const UnifiedLoginScreen());
            },
            child: const Text('Back to Login'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? DarkColors.background : LightColors.background;
    final textColor = isDark ? DarkColors.textPrimary : LightColors.textPrimary;
    final textSecondaryColor = isDark ? DarkColors.textSecondary : LightColors.textSecondary;
    final offlineColor = isDark ? DarkColors.warning : LightColors.warning;

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        toolbarHeight: 0,
        backgroundColor: backgroundColor,
      ),
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'logo',
              child: AppLogoCircle(size: isSmallScreen ? 100 : 120),
            ),
            const SizedBox(height: 24),
            Obx(() {
              if (!Get.isRegistered<MonOperatorController>()) {
                return Text(
                  'Welcome ',
                  style: TextStyle(
                    color: textColor,
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
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              );
            }),
            const SizedBox(height: 40),
            MonSplashLoader(
              statusMessage: _statusMessage,
              isOfflineMode: _isOfflineMode,
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: TextStyle(color: textSecondaryColor, fontSize: 14),
            ),
            if (_isOfflineMode) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, color: offlineColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Offline Mode',
                    style: TextStyle(
                      color: offlineColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: NetworkHelper.hasConnection(),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;

        if (isOnline) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'Offline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
