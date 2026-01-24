import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:developer' as developer;
import 'login.dart';
import '../services/api_services.dart';
import '../controllers/auth_controller.dart';
import '../controllers/service_point_controller.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/sales_controller.dart';
import '../controllers/payment_controller.dart';
import '../controllers/customer_controller.dart';
import '../../shared/database/unified_db_helper.dart';
import '../utils/network_helper.dart';
import '../config.dart';

class SplashScreen extends StatefulWidget {
  final Widget? nextScreen;

  const SplashScreen({super.key, this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final PosApiService _apiService = PosApiService();
  final _dbHelper = UnifiedDatabaseHelper.instance;

  String _statusMessage = 'Initializing...';
  bool _hasError = false;
  bool _isOfflineMode = false;
  bool _hasCachedData = false;

  // Logging helper
  void _log(String message, {String level = 'INFO'}) {
    final timestamp = DateTime.now().toIso8601String();
    developer.log(
      '[$level] $message',
      name: 'SplashScreen',
      time: DateTime.now(),
    );
    print('[$timestamp] [SplashScreen] [$level] $message');
  }

  @override
  void initState() {
    super.initState();
    _log('initState: Starting splash screen initialization');
    _setupAnimations();
    _authenticateApp();
  }

  void _setupAnimations() {
    _log('setupAnimations: Configuring animations');

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _animationController.forward();
    _log('setupAnimations: Animations started');
  }

  Future<void> _authenticateApp() async {
    _log('authenticateApp: Starting authentication process');

    try {
      setState(() {
        _statusMessage = 'Checking server credentials...';
      });
      _log('authenticateApp: Checking for server credentials');

      // Check if server credentials are stored
      final hasServerCredentials = await _apiService.hasServerCredentials();
      _log('authenticateApp: Server credentials exist = $hasServerCredentials');

      if (!hasServerCredentials) {
        // First time - navigate to server login
        _log('authenticateApp: No credentials found, redirecting to server login');
        setState(() {
          _statusMessage = 'Redirecting to server login...';
        });

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          _log('authenticateApp: Navigating to ServerLogin screen');
          Get.off(() => const UnifiedLoginScreen());
        }
        return;
      }

      // Get stored credentials
      _log('authenticateApp: Retrieving stored credentials');
      final credentials = await _apiService.getServerCredentials();
      final storedUsername = credentials['username'];
      final storedPassword = credentials['password'];

      _log('authenticateApp: Retrieved username = ${storedUsername != null ? storedUsername : "null"}');
      _log('authenticateApp: Retrieved password = ${storedPassword != null ? storedPassword : "null"}');

      if (storedUsername == null || storedPassword == null) {
        _log('authenticateApp: Credentials are incomplete, redirecting to server login', level: 'WARN');
        setState(() {
          _statusMessage = 'Credentials missing, redirecting to server login...';
        });

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          _log('authenticateApp: Navigating to ServerLogin screen');
          Get.off(() => const UnifiedLoginScreen());
        }
        return;
      }

      setState(() {
        _statusMessage = 'Checking authentication...';
      });
      _log('authenticateApp: Checking authentication status');

      // Check if already authenticated
      final isAuthenticated = await _apiService.isAuthenticated();
      _log('authenticateApp: Is authenticated = $isAuthenticated');

      if (!isAuthenticated) {
        // Check network
        _log('authenticateApp: Not authenticated, checking network connection');
        final hasNetwork = await NetworkHelper.hasConnection();
        _log('authenticateApp: Network available = $hasNetwork');

        if (!hasNetwork) {
          _log('authenticateApp: No network connection, entering error state', level: 'ERROR');
          setState(() {
            _hasError = true;
            _isOfflineMode = true;
            _statusMessage = 'No internet connection';
          });
          return; // Show retry button, don't loop
        }

        // Authenticate with stored credentials
        setState(() {
          _statusMessage = 'Connecting to server...';
        });
        _log('authenticateApp: Attempting to sign in with stored credentials');

        await _apiService.signIn(storedUsername, storedPassword);
        _log('authenticateApp: Sign in successful');

        setState(() {
          _statusMessage = 'Loading company info...';
        });
        _log('authenticateApp: Fetching company information');

        await _apiService.fetchAndStoreCompanyInfo();
        _log('authenticateApp: Company info loaded successfully');
      }

      _log('authenticateApp: Initializing controllers');
      _initializeControllers();

      // Ensure database is open if we have company info
      _log('authenticateApp: Checking if database needs to be opened');
      await _ensureDatabaseIsOpen();

      // Initialize POS-specific data (cash accounts, currency, etc.)
      _log('authenticateApp: Initializing POS data');
      await _initializePosData();

      // Ensure database is open before smart sync
      _log('authenticateApp: Ensuring database is open for smart sync');
      await _ensureDatabaseIsOpenForSmartSync();

      // Smart data loading
      _log('authenticateApp: Starting smart data sync');
      await _loadDataWithSmartSync();
      _log('authenticateApp: Smart data sync completed');

      // Navigate to next screen or login
      setState(() {
        _statusMessage = 'Finishing setup...';
      });
      _log('authenticateApp: Finishing setup, preparing navigation');

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        if (widget.nextScreen != null) {
          _log('authenticateApp: Navigating to custom next screen');
          Get.off(() => widget.nextScreen!);
        } else {
          _log('authenticateApp: Navigating to Login screen');
          Get.off(() => const Login());
        }
      }

      _log('authenticateApp: Authentication process completed successfully');

    } catch (e, stackTrace) {
      _log('authenticateApp: Error occurred - $e', level: 'ERROR');
      _log('authenticateApp: Stack trace - $stackTrace', level: 'ERROR');

      setState(() {
        _hasError = true;
        _statusMessage = 'Error loading app';
      });

      Get.snackbar(
        'Error',
        'Network Error, please check your internet connection and try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 4),
      );
    }
  }

  void _initializeControllers() {
    _log('initializeControllers: Starting controller initialization');

    _log('initializeControllers: Registering AuthController');
    Get.put(AuthController());

    _log('initializeControllers: Registering ServicePointController');
    Get.put(ServicePointController());

    _log('initializeControllers: Registering InventoryController');
    Get.put(InventoryController());

    _log('initializeControllers: Registering SalesController');
    Get.put(SalesController());

    _log('initializeControllers: Registering PaymentController');
    Get.put(PaymentController());

    _log('initializeControllers: Registering CustomerController');
    Get.put(CustomerController());

    _log('initializeControllers: All controllers registered successfully');
  }

  Future<void> _initializePosData() async {
    _log('initializePosData: Starting POS initialization');

    try {
      // Get company info (already stored after login)
      final companyInfo = await _apiService.getCompanyInfo();
      final companyId = companyInfo['companyId'];

      if (companyId == null || companyId.isEmpty) {
        _log('initializePosData: No companyId found, skipping', level: 'WARN');
        return;
      }

      // Ensure DB is open for this company
      await _dbHelper.openForCompany(companyId);
      _log('initializePosData: Database opened for company $companyId');

      // Fetch cash accounts from API
      _log('initializePosData: Fetching cash accounts from API');
      final cashAccounts = await _apiService.fetchCashAccounts();

      // Store in local DB
      await _dbHelper.insertCashAccounts(cashAccounts);
      _log(
        'initializePosData: Cash accounts cached successfully (${cashAccounts.length})',
      );
    } catch (e, stackTrace) {
      _log('initializePosData: Error - $e', level: 'ERROR');
      _log('initializePosData: StackTrace - $stackTrace', level: 'ERROR');
    }
  }

  Future<void> _ensureDatabaseIsOpen() async {
    _log('ensureDatabaseIsOpen: Checking if database needs to be opened');

    try {
      // Check if we have company info stored
      final companyInfo = await _apiService.getCompanyInfo();
      final companyId = companyInfo['companyId'];

      if (companyId != null && companyId.isNotEmpty) {
        _log('ensureDatabaseIsOpen: Company ID found: $companyId');

        // Check if database is already open
        try {
          // Try to access the database - if it's not open, this will throw an exception
          final db = _dbHelper.database;
          _log('ensureDatabaseIsOpen: Database is already open');
        } catch (e) {
          _log('ensureDatabaseIsOpen: Database is not open, opening it now');
          // Database is not open, so open it
          await _dbHelper.openForCompany(companyId);
          _log('ensureDatabaseIsOpen: Database opened successfully');
          _log("---------------------------------------");
          _log("Failed to open");
          _log("---------------------------------------");
        }
      } else {
        _log('ensureDatabaseIsOpen: No company ID found, skipping database open');
      }
    } catch (e) {
      _log('ensureDatabaseIsOpen: Error checking company info - $e', level: 'ERROR');
      // If we can't get company info, we can't open the database
    }
  }

  /// Ensure database is open specifically for smart sync process
  /// This is a more robust version that guarantees database is open
  Future<void> _ensureDatabaseIsOpenForSmartSync() async {
    _log('ensureDatabaseIsOpenForSmartSync: Ensuring database is open for smart sync');

    try {
      // Check if we have company info stored
      final companyInfo = await _apiService.getCompanyInfo();
      final companyId = companyInfo['companyId'];

      if (companyId != null && companyId.isNotEmpty) {
        _log('ensureDatabaseIsOpenForSmartSync: Company ID found: $companyId');

        // Check if database is already open
        if (!_dbHelper.isDatabaseOpen) {
          _log('ensureDatabaseIsOpenForSmartSync: Database is not open, opening it now');
          await _dbHelper.openForCompany(companyId);
          _log('ensureDatabaseIsOpenForSmartSync: Database opened successfully');
        } else {
          _log('ensureDatabaseIsOpenForSmartSync: Database is already open');
        }
      } else {
        _log('ensureDatabaseIsOpenForSmartSync: No company ID found, cannot open database', level: 'WARN');
        // This is a critical error for smart sync
        throw Exception('No company ID available for database initialization');
      }
    } catch (e) {
      _log('ensureDatabaseIsOpenForSmartSync: Error - $e', level: 'ERROR');
      // Re-throw to ensure the calling code knows database couldn't be opened
      throw Exception('Failed to ensure database is open: $e');
    }
  }

  /// Safe wrapper for checking cached data that handles database errors gracefully
  Future<bool> _checkCachedDataSafely(String dataType) async {
    try {
      return await _dbHelper.hasCachedData(dataType);
    } catch (e) {
      _log('checkCachedDataSafely: Error checking cached data for $dataType - $e', level: 'ERROR');
      // If we can't check cached data, assume no cache exists
      return false;
    }
  }

  Future<void> _loadDataWithSmartSync() async {
    _log('loadDataWithSmartSync: Starting smart sync process');

    final hasNetwork = await NetworkHelper.hasConnection();
    _log('loadDataWithSmartSync: Network available = $hasNetwork');

    // Get controllers
    _log('loadDataWithSmartSync: Retrieving controller instances');
    final authController = Get.find<AuthController>();
    final servicePointController = Get.find<ServicePointController>();
    final inventoryController = Get.find<InventoryController>();
    final salesController = Get.find<SalesController>();
    final customerController = Get.find<CustomerController>();
    _log('loadDataWithSmartSync: All controllers retrieved');

    // 1. Users (static - load from cache if exists)
    setState(() {
      _statusMessage = 'Loading users...';
    });
    _log('loadDataWithSmartSync: Step 1 - Loading users');
    final hasUsers = await _checkCachedDataSafely('users');
    _log('loadDataWithSmartSync: Cached users exist = $hasUsers');

    if (!hasUsers && hasNetwork) {
      _log('loadDataWithSmartSync: Syncing users from API');
      await authController.syncUsersFromAPI();
      _log('loadDataWithSmartSync: Users synced successfully from API');
    } else if (hasUsers) {
      _log('loadDataWithSmartSync: Loading users from cache');
      await authController.loadUsersFromCache();
      _log('loadDataWithSmartSync: Users loaded successfully from cache');
    } else {
      _log('loadDataWithSmartSync: No users data available (offline, no cache)', level: 'WARN');
    }

    // 2. Service Points (static - load from cache if exists)
    setState(() {
      _statusMessage = 'Loading service points...';
    });
    _log('loadDataWithSmartSync: Step 2 - Loading service points');
    final hasServicePoints = await _checkCachedDataSafely('service_points');
    _log('loadDataWithSmartSync: Cached service points exist = $hasServicePoints');

    if (!hasServicePoints && hasNetwork) {
      _log('loadDataWithSmartSync: Syncing service points from API');
      await servicePointController.syncServicePointsFromAPI();
      _log('loadDataWithSmartSync: Service points synced successfully from API');
    } else if (hasServicePoints) {
      _log('loadDataWithSmartSync: Loading service points from cache');
      await servicePointController.loadServicePointsFromCache();
      _log('loadDataWithSmartSync: Service points loaded successfully from cache');
    } else {
      _log('loadDataWithSmartSync: No service points data available (offline, no cache)', level: 'WARN');
    }

    // 3. Inventory (dynamic - sync if network available)
    setState(() {
      _statusMessage = 'Loading inventory...';
    });
    _log('loadDataWithSmartSync: Step 3 - Loading inventory');
    final hasInventory = await _checkCachedDataSafely('inventory');
    _log('loadDataWithSmartSync: Cached inventory exists = $hasInventory');

    if (hasNetwork) {
      _log('loadDataWithSmartSync: Syncing inventory from API (network available)');
      await inventoryController.syncInventoryFromAPI();
      _log('loadDataWithSmartSync: Inventory synced successfully from API');
    } else if (hasInventory) {
      _log('loadDataWithSmartSync: Loading inventory from cache (offline mode)');
      await inventoryController.loadInventoryFromCache();
      _log('loadDataWithSmartSync: Inventory loaded successfully from cache');
    } else {
      _log('loadDataWithSmartSync: No inventory data available (offline, no cache)', level: 'WARN');
    }

    // 4. Sales (local only - no remote sync)
    setState(() {
      _statusMessage = 'Loading local sales...';
    });
    _log('loadDataWithSmartSync: Step 4 - Loading local sales');
    await salesController.loadSalesFromCache();
    _log('loadDataWithSmartSync: Local sales loaded successfully');

    // 5. Customers (dynamic - sync if network available)
    setState(() {
      _statusMessage = 'Loading customers...';
    });
    _log('loadDataWithSmartSync: Step 5 - Loading customers');
    final hasCustomers = await _checkCachedDataSafely('customers');
    _log('loadDataWithSmartSync: Cached customers exist = $hasCustomers');

    if (hasNetwork) {
      _log('loadDataWithSmartSync: Syncing customers from API (network available)');
      await customerController.syncCustomersFromAPI();
      _log('loadDataWithSmartSync: Customers synced successfully from API');
    } else if (hasCustomers) {
      _log('loadDataWithSmartSync: Loading customers from cache (offline mode)');
      await customerController.loadCustomersFromCache();
      _log('loadDataWithSmartSync: Customers loaded successfully from cache');
    } else {
      _log('loadDataWithSmartSync: No customers data available (offline, no cache)', level: 'WARN');
    }

    // Check if we have minimum required data
    _hasCachedData = hasUsers && hasServicePoints;
    _log('loadDataWithSmartSync: Has minimum required data = $_hasCachedData (users: $hasUsers, service points: $hasServicePoints)');
    _log('loadDataWithSmartSync: Smart sync process completed');
  }

  @override
  void dispose() {
    _log('dispose: Cleaning up splash screen resources');
    _animationController.dispose();
    _log('dispose: Animation controller disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade700,
              Colors.blue.shade400,
              Colors.cyan.shade300,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with animations
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        "assets/images/logo.png",
                        width: 100,
                        height: 100,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.storefront_rounded,
                            size: 120,
                            color: Colors.blue.shade700,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // App Name
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    AppConfig.appName,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Company Name
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    AppConfig.companyName,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Loading Indicator or Error Icon
                if (!_hasError)
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  )
                else
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: Colors.red.shade200,
                  ),
                const SizedBox(height: 20),

                // Status Message
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // Error Buttons
                if (_hasError) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _isOfflineMode = false;
                      });
                      _authenticateApp();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),

                  // Only show Continue Offline if cached data exists
                  if (_isOfflineMode && _hasCachedData) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        _log('User clicked Continue Offline button');
                        if (widget.nextScreen != null) {
                          _log('Navigating to custom next screen (offline mode)');
                          Get.off(() => widget.nextScreen!);
                        } else {
                          _log('Navigating to Login screen (offline mode)');
                          Get.off(() => const Login());
                        }
                      },
                      icon: const Icon(Icons.offline_bolt, color: Colors.white),
                      label: const Text('Continue Offline'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 40),

                // Footer
                const Spacer(),
                Text(
                  AppConfig.edition,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppConfig.copyright,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}