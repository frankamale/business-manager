import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';
import '../back_pos/utils/network_helper.dart';
import '../shared/widgets/app_logo.dart';
import '../shared/services/credential_helper.dart';
import 'app_roots.dart';
import 'unified_login_screen.dart';
import '../bac_monitor/lib/controllers/mon_operator_controller.dart';
import '../bac_monitor/lib/controllers/mon_sync_controller.dart';
import '../bac_monitor/lib/controllers/mon_store_controller.dart';
import '../bac_monitor/lib/controllers/mon_store_kpi_controller.dart';
import '../bac_monitor/lib/controllers/mon_dashboard_controller.dart';
import '../bac_monitor/lib/controllers/mon_kpi_overview_controller.dart';
import '../bac_monitor/lib/controllers/mon_salestrends_controller.dart';
import '../bac_monitor/lib/controllers/mon_gross_profit_controller.dart';
import '../bac_monitor/lib/controllers/mon_outstanding_payments_controller.dart';
import '../bac_monitor/lib/controllers/mon_inventory_controller.dart';
import '../bac_monitor/lib/services/api_services.dart';
import '../bac_monitor/lib/services/sync_state_manager.dart';
import '../shared/database/unified_db_helper.dart';

/// Key for storing company ID in GetStorage for offline access
const String kLastCompanyIdKey = 'last_company_id';

class ConnectivityController extends GetxController {
  var isConnected = false.obs;
  var isLoading = true.obs;
  var hasError = false.obs;
  var isOfflineMode = false.obs;  // Track if we're in offline mode
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  Timer? _retryTimer;

  @override
  void onInit() {
    super.onInit();
    checkConnectivity();
  }

  @override
  void onClose() {
    _retryTimer?.cancel();
    super.onClose();
  }

  // Session timeout for customers (48 hours in milliseconds)
  static const int _customerSessionTimeout = 48 * 60 * 60 * 1000;

  Future<void> checkConnectivity() async {
    isLoading.value = true;
    hasError.value = false;
    _retryTimer?.cancel();

    // Check for customer session first (works offline)
    final customerSession = await _checkCustomerSession();
    if (customerSession == 'valid') {
      // Customer session is valid, go to client home
      Get.offAll(() => const ClientAppRoot());
      return;
    } else if (customerSession == 'expired') {
      // Session expired, continue to login
      debugPrint('SplashScreen: Customer session expired after 48 hours');
    }

    try {
      bool hasConnection = await NetworkHelper.hasConnection();
      if (hasConnection) {
        isConnected.value = true;
        isLoading.value = false;
        final hasCredentials = await _hasValidCredentials();
        if (hasCredentials) {
          // Get role FIRST before initializing controllers
          final role = await _getUserRole();
          
          // Handle null or empty role with fallback logic
          if (role == null || role.isEmpty) {
            debugPrint(
              'SplashScreen: User role is null or empty, using fallback logic',
            );
            // Try to determine role from user data as fallback
            final userData = await Get.find<MonitorApiService>()
                .getStoredUserData();
            if (userData != null && userData.containsKey('roles')) {
              final roles = userData['roles'] as List<dynamic>?;

              if (roles != null && roles.isNotEmpty) {
                final fallbackRole = roles.first.toString();
                await _secureStorage.write(
                  key: 'user_role',
                  value: fallbackRole,
                );
                // Initialize controllers based on role
                _initializeControllersForRole(fallbackRole);
                await _loadDataFromDatabase();
                Get.offAll(() => const MonitorAppRoot());
              } else {
                // Default to POS
                _initializeControllersForRole('pos');
                await _loadDataFromDatabase();
                Get.offAll(() => const PosAppRoot());
              }
            } else {
              // If still no role, default to POS (non-admin)
              debugPrint('SplashScreen: No role found, defaulting to POS app');
              _initializeControllersForRole('pos');
              await _loadDataFromDatabase();
              Get.offAll(() => const PosAppRoot());
            }
          } else if (CredentialHelper.isAdminRole(role)) {
            // Admin user - initialize monitor controllers only
            _initializeControllersForRole('admin');
            await _loadDataFromDatabase();
            Get.offAll(() => const MonitorAppRoot());
          } else {
            // Non-admin user - initialize POS controllers only
            _initializeControllersForRole('pos');
            await _loadDataFromDatabase();
            Get.offAll(() => const PosAppRoot());
          }
        } else {
          // Wait 2 seconds then navigate to login
          Future.delayed(const Duration(seconds: 2), () {
            Get.offAll(() => const UnifiedLoginScreen());
          });
        }
      } else {
        await _handleOfflineMode();
      }
    } catch (e) {
      _setError();
    }
  }

  void _setError() {
    isConnected.value = false;
    isLoading.value = false;
    hasError.value = true;
    // Auto retry every 30 seconds
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      checkConnectivity();
    });
  }

  /// Check customer session validity
  /// Returns: 'valid' if logged in and not expired, 'expired' if session timed out, 'none' if not logged in
  Future<String> _checkCustomerSession() async {
    try {
      final box = GetStorage();
      final isCustomerLoggedIn = box.read('is_customer_logged_in') ?? false;

      if (!isCustomerLoggedIn) {
        return 'none';
      }

      final loginTimestamp = box.read('customer_login_timestamp');
      if (loginTimestamp == null) {
        // No timestamp, clear session and require re-login
        await _clearCustomerSession(box);
        return 'expired';
      }

      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final elapsed = currentTime - loginTimestamp;

      if (elapsed > _customerSessionTimeout) {
        // Session expired (48 hours passed)
        await _clearCustomerSession(box);
        return 'expired';
      }

      // Session is valid
      return 'valid';
    } catch (e) {
      debugPrint('SplashScreen: Error checking customer session - $e');
      return 'none';
    }
  }

  /// Clear customer session data
  Future<void> _clearCustomerSession(GetStorage box) async {
    await box.remove('logged_in_customer');
    await box.remove('is_customer_logged_in');
    await box.remove('customer_login_timestamp');
  }

  Future<bool> _hasValidCredentials() async {
    try {
      final hasCredentials = await CredentialHelper.hasStoredCredentials();
      if (!hasCredentials) return false;

      final token = await Get.find<MonitorApiService>().getStoredToken();
      final companyId = await Get.find<MonitorApiService>().getStoredCompanyId();

      return token != null && token.isNotEmpty &&
          companyId != null && companyId.isNotEmpty;
    } catch (e) {
      debugPrint('SplashScreen: Error checking valid credentials - $e');
      return false;
    }
  }

  Future<String?> _getUserRole() async {
    try {
      // Try to get role from secure storage first
      final role = await _secureStorage.read(key: 'user_role');
      print("Retrieved user role: $role");

      if (role != null && role.isNotEmpty) {
        return role;
      }

      // If not found in secure storage, try to get from user data
      final userData = await Get.find<MonitorApiService>().getStoredUserData();
      if (userData != null &&
          userData.containsKey('roles') &&
          userData['roles'] is List &&
          userData['roles'].isNotEmpty) {
        final userRole = userData['roles'].first.toString();
        // Store it for future use
        await _secureStorage.write(key: 'user_role', value: userRole);
        return userRole;
      }

      return null;
    } catch (e) {
      debugPrint('SplashScreen: Error retrieving user role - $e');
      return null;
    }
  }

  /// Initialize controllers based on user role
  /// Admin users get monitor controllers, POS users get POS controllers
  void _initializeControllersForRole(String role) {
    final isAdmin = CredentialHelper.isAdminRole(role);

    if (isAdmin) {
      debugPrint('SplashScreen: Admin user - initializing monitor controllers');
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
        Get.put(MonDashboardController(), permanent: true);
      }
      if (!Get.isRegistered<MonKpiOverviewController>()) {
        Get.put(MonKpiOverviewController(), permanent: true);
      }
      if (!Get.isRegistered<MonSalesTrendsController>()) {
        Get.put(MonSalesTrendsController(), permanent: true);
      }
      if (!Get.isRegistered<MonGrossProfitController>()) {
        Get.put(MonGrossProfitController(), permanent: true);
      }
      if (!Get.isRegistered<MonOutstandingPaymentsController>()) {
        Get.put(MonOutstandingPaymentsController());
      }
      if (!Get.isRegistered<MonInventoryController>()) {
        Get.put(MonInventoryController());
      }
    } else {
      debugPrint('SplashScreen: Non-admin user - skipping monitor controller initialization');
      // POS controllers are initialized elsewhere in the POS flow
    }
  }

  Future<void> _loadDataFromDatabase() async {
    try {
      // Load data from database for offline use
      final storesController = Get.find<MonStoresController>();
      final inventoryController = Get.find<MonInventoryController>();
      // Load stores from database (fetchAllStores already loads from DB)
      await storesController.fetchAllStores();

      // Load inventory from database
      await inventoryController.loadInventoryFromDb();

      // Fetch KPI data so the dashboard shows actual values
      if (Get.isRegistered<MonKpiOverviewController>()) {
        final kpiController = Get.find<MonKpiOverviewController>();
        await kpiController.fetchKpiData();
        debugPrint('SplashScreen: KPI data fetched - totalSales: ${kpiController.totalSales.value}');
      }

      // Register SyncStateManager and mark today's data as loaded
      // so the dashboard doesn't try to re-fetch
      if (!Get.isRegistered<SyncStateManager>()) {
        Get.put(SyncStateManager(), permanent: true);
      }
      Get.find<SyncStateManager>().markTodayDataLoaded();

      debugPrint('SplashScreen: Data loaded from database successfully');
    } catch (e) {
      debugPrint('SplashScreen: Error loading data from database - $e');
      // Continue even if data loading fails
    }
  }

  Future<void> _handleOfflineMode() async {
    isLoading.value = true;
    hasError.value = false;
    _retryTimer?.cancel();
    try {
      // First, try to use GetStorage offline credentials
      final box = GetStorage();
      final lastCompanyId = box.read('last_company_id') as String?;
      final lastUserRole = box.read('last_user_role') as String?;
      final lastUsername = box.read('last_username') as String?;
      
      if (lastCompanyId != null && lastCompanyId.isNotEmpty) {
        // We have offline credentials - proceed with offline login
        isOfflineMode.value = true;
        debugPrint('SplashScreen: Offline mode detected. Company: $lastCompanyId, Role: $lastUserRole, User: $lastUsername');
        
        try {
          // Open database for the company
          await UnifiedDatabaseHelper.instance.openForCompany(lastCompanyId);
          
          // Determine role from GetStorage or fallback to secure storage
          String effectiveRole = lastUserRole ?? 'pos';
          if (effectiveRole.isEmpty) {
            final storedRole = await _getUserRole();
            effectiveRole = storedRole ?? 'pos';
          }
          
          // Initialize controllers based on role
          _initializeControllersForRole(effectiveRole);
          
          // Load data from local database
          await _loadDataFromDatabase();
          
          // Navigate based on role
          if (CredentialHelper.isAdminRole(effectiveRole)) {
            Get.offAll(() => const MonitorAppRoot());
          } else {
            Get.offAll(() => const PosAppRoot());
          }
        } catch (e) {
          debugPrint('SplashScreen: Error opening offline database - $e');
          _setError();
        }
      } else {
        // No GetStorage credentials - fallback to old method
        final hasCredentials = await _hasValidCredentials();
        if (hasCredentials) {
          isOfflineMode.value = true;
          
          final role = await _getUserRole();
          final effectiveRole = role ?? 'pos';
          _initializeControllersForRole(effectiveRole);
          await _loadDataFromDatabase();
          
          if (CredentialHelper.isAdminRole(effectiveRole)) {
            Get.offAll(() => const MonitorAppRoot());
          } else {
            Get.offAll(() => const PosAppRoot());
          }
        } else {
          _setError();
        }
      }
    } catch (e) {
      debugPrint('SplashScreen: Error in offline mode - $e');
      _setError();
    }
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ConnectivityController controller = Get.put(ConnectivityController());

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final bool isSmallScreen = size.width < 600;

    return Scaffold(
      body: Center(
        child: Obx(() {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'logo',
                child: AppLogoCircle(size: isSmallScreen ? 100 : 120),
              ),
              const SizedBox(height: 20),
              if (controller.isLoading.value)
                const CircularProgressIndicator()
              // else if (controller.hasError.value)
              //   Column(
              //     children: [
              //       const Text('No internet connection'),
              //       const SizedBox(height: 10),
              //       ElevatedButton(
              //         onPressed: controller.checkConnectivity,
              //         child: const Text('Retry'),
              //       ),
              //     ],
              //   ),
            ],
          );
        }),
      ),
    );
  }
}
