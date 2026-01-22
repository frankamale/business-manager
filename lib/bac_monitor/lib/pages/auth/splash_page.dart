import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import '../../../../back_pos/utils/network_helper.dart';
import '../../additions/colors.dart';
import '../../controllers/mon_dashboard_controller.dart';
import '../../controllers/mon_operator_controller.dart';
import '../../controllers/mon_inventory_controller.dart';
import '../../controllers/mon_store_controller.dart';
import '../../controllers/mon_sync_controller.dart';
import '../../services/api_services.dart';
import '../../../../shared/database/unified_db_helper.dart';
import '../bottom_nav.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final _dbHelper = UnifiedDatabaseHelper.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
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

  /// Check if we have cached data in the database
  Future<bool> _hasCachedData() async {
    try {
      final db = _dbHelper.database;

      // Check if we have any sales data
      final salesCount = await db.rawQuery('SELECT COUNT(*) as count FROM mon_sales');
      final hasSales = (salesCount.first['count'] as int? ?? 0) > 0;

      // Check if we have service points
      final servicePointsCount = await db.rawQuery('SELECT COUNT(*) as count FROM mon_service_points');
      final hasServicePoints = (servicePointsCount.first['count'] as int? ?? 0) > 0;

      // Check if we have company details
      final companyCount = await db.rawQuery('SELECT COUNT(*) as count FROM company_details');
      final hasCompany = (companyCount.first['count'] as int? ?? 0) > 0;

      debugPrint('SplashPage: Cached data check - Sales: $hasSales, ServicePoints: $hasServicePoints, Company: $hasCompany');

      return hasSales && hasServicePoints && hasCompany;
    } catch (e) {
      debugPrint('SplashPage: Error checking cached data - $e');
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
      // STEP 1: Check network connectivity first
      _updateStatus('Checking network...');
      final isOnline = await NetworkHelper.hasConnection();
      _isOfflineMode = !isOnline;

      if (_isOfflineMode) {
        debugPrint('SplashPage: OFFLINE MODE DETECTED');
        _updateStatus('Offline mode - Loading cached data...');
      } else {
        debugPrint('SplashPage: ONLINE MODE');
        _updateStatus('Online - Syncing data...');
      }

      // STEP 2: Initialize company ID FIRST (works offline)
      _updateStatus('Initializing company...');
      await _initializeCompanyIdOfflineSafe();

      // STEP 3: Ensure database is properly opened for the company
      _updateStatus('Opening database...');
      await _ensureDatabaseIsOpen();

      // STEP 4: Check credentials and token
      _updateStatus('Verifying credentials...');
      final hasValidCredentials = await _hasValidCredentials();

      if (!hasValidCredentials) {
        debugPrint('SplashPage: No valid credentials found, redirecting to login');
        Get.offAll(() => const UnifiedLoginScreen());
        return;
      }

      // STEP 5: Check if we have cached data (important for offline mode)
      final hasCachedData = await _hasCachedData();

      if (_isOfflineMode && !hasCachedData) {
        debugPrint('SplashPage: Offline mode with no cached data - need to go online first');
        _showOfflineNoDataDialog();
        return;
      }

      if (isOnline) {
        final apiService = Get.find<MonitorApiService>();
        final initialSyncDone = await apiService.isInitialSyncCompleted();

        if (!initialSyncDone) {
          _updateStatus('First time sync – downloading data...');
          await apiService.fetchAndCacheAllData();
        } else {
          _updateStatus('Syncing recent sales...');
          await apiService.syncRecentSales();
        }
      } else {
        _updateStatus('Loading cached data...');
        await _loadCompanyDetailsOffline();
      }


      // STEP 7: Initialize controllers AFTER data is synced/loaded
      _updateStatus('Initializing app...');
      _initializeControllers();

      // STEP 8: Load initial data from database into controllers
      _updateStatus('Loading data...');
      await _loadDataIntoControllers();

      // STEP 9: Navigate to main screen
      _updateStatus('Ready!');
      await Future.delayed(const Duration(milliseconds: 500));
      Get.offAll(() => const BottomNav());

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
        if (_dbHelper.isDatabaseOpen && _dbHelper.currentCompanyId == storedCompanyId) {
          debugPrint('SplashPage: Database already open for company: $storedCompanyId');
          return;
        }

        // Open database for the company
        await _dbHelper.openForCompany(storedCompanyId);
        debugPrint('SplashPage: Database opened for company: $storedCompanyId');
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
        throw Exception('No stored company ID available for offline mode');
      }

    } catch (e) {
      debugPrint('SplashPage: Error initializing company ID - $e');

      // If we're offline, we can't proceed without a stored company ID
      if (_isOfflineMode) {
        throw Exception('Cannot use app offline without prior login');
      }

      throw Exception('Failed to initialize company ID: $e');
    }
  }

  Future<void> _ensureDatabaseIsOpen() async {
    try {
      // Check if database is open
      if (!_dbHelper.isDatabaseOpen) {
        debugPrint('SplashPage: Database not open, this should have been done in _initializeCompanyIdOfflineSafe');
        throw Exception('Database was not opened during company initialization');
      }

      debugPrint('SplashPage: Database is open for company: ${_dbHelper.currentCompanyId}');

      // Verify we can query the database
      final db = _dbHelper.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM mon_service_points');
      debugPrint('SplashPage: Database verification - service_points count: ${result.first['count']}');

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

      debugPrint("SplashPage: Device is online. Syncing all data from server...");
      await apiService.fetchAndCacheAllData();
      debugPrint("SplashPage: Data sync completed successfully");

      // Load company details into operator controller
      await _loadCompanyDetailsOffline();

    } catch (e) {
      debugPrint("SplashPage: Error during sync - $e");

      // Check if we have cached data to fall back on
      final hasCachedData = await _hasCachedData();

      if (hasCachedData) {
        debugPrint("SplashPage: Sync failed but we have cached data. Continuing...");
        _isOfflineMode = true; // Switch to offline mode
        await _loadCompanyDetailsOffline();
      } else {
        throw Exception('Failed to sync data and no cached data available');
      }
    }
  }

  void _initializeControllers() {
    debugPrint('SplashPage: Initializing controllers (without triggering data fetch)');

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
            Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            if (_isOfflineMode) ...[
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    color: Colors.orange,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Offline Mode',
                    style: TextStyle(
                      color: Colors.orange,
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
              Icon(
                Icons.cloud_off,
                color: Colors.white,
                size: 16,
              ),
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
