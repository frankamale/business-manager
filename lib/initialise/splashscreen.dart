import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../back_pos/utils/network_helper.dart';
import 'unified_login_screen.dart';
import '../../bac_monitor/lib/controllers/mon_operator_controller.dart';
import '../../bac_monitor/lib/controllers/mon_sync_controller.dart';
import '../../bac_monitor/lib/controllers/mon_store_controller.dart';
import '../../bac_monitor/lib/controllers/mon_store_kpi_controller.dart';
import '../../bac_monitor/lib/controllers/mon_dashboard_controller.dart';
import '../../bac_monitor/lib/controllers/mon_kpi_overview_controller.dart';
import '../../bac_monitor/lib/controllers/mon_salestrends_controller.dart';
import '../../bac_monitor/lib/controllers/mon_gross_profit_controller.dart';
import '../../bac_monitor/lib/controllers/mon_outstanding_payments_controller.dart';
import '../../bac_monitor/lib/controllers/mon_inventory_controller.dart';
import '../../bac_monitor/lib/services/api_services.dart';
import '../../bac_monitor/lib/db/db_helper.dart';
import '../../bac_monitor/lib/pages/bottom_nav.dart';

class ConnectivityController extends GetxController {
  var isConnected = false.obs;
  var isLoading = true.obs;
  var hasError = false.obs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  final DatabaseHelper _dbHelper = DatabaseHelper();
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

  Future<void> checkConnectivity() async {
    isLoading.value = true;
    hasError.value = false;
    _retryTimer?.cancel();

    try {
      bool hasConnection = await NetworkHelper.hasConnection();
      if (hasConnection) {
        isConnected.value = true;
        isLoading.value = false;
        // Wait 2 seconds then navigate
        Future.delayed(const Duration(seconds: 2), () {
          Get.offAll(() => const UnifiedLoginScreen());
        });
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
  Future<Map<String, String?>> _getStoredCredentials() async {
    try {
      final username = await _secureStorage.read(key: 'login_username');
      final password = await _secureStorage.read(key: 'login_password');
      return {
        'username': username,
        'password': password,
      };
    } catch (e) {
      debugPrint('SplashScreen: Error retrieving stored credentials - $e');
      return {
        'username': null,
        'password': null,
      };
    }
  }
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
      debugPrint('SplashScreen: Error checking valid credentials - $e');
      return false;
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
  Future<void> _loadDataFromDatabase() async {
    try {
      // Load data from database for offline use
      final storesController = Get.find<MonStoresController>();
      final inventoryController = Get.find<MonInventoryController>();
      // Load stores from database (fetchAllStores already loads from DB)
      await storesController.fetchAllStores();
      
      // Load inventory from database
      await inventoryController.loadInventoryFromDb();
      
      debugPrint('SplashScreen: Data loaded from database successfully');
      
    } catch (e) {
      debugPrint('SplashScreen: Error loading data from database - $e');
      // Continue even if data loading fails
    }
  }
  Future<void> _performOfflineAuthAndNavigation() async {
    // Load company details
    await Get.find<MonOperatorController>().loadCompanyDetailsFromDb();
    // Since offline, assume credentials are valid, proceed to BottomNav
    Get.offAll(() => const BottomNav());
  }
  Future<void> _handleOfflineMode() async {
    isLoading.value = true;
    hasError.value = false;
    _retryTimer?.cancel();
    try {
      final hasCredentials = await _hasValidCredentials();
      if (hasCredentials) {
        _initializeControllers();
        await _loadDataFromDatabase();
        await _performOfflineAuthAndNavigation();
      } else {
        _setError();
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
    return Scaffold(
      body: Center(
        child: Obx(() {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', width: 150, height: 150),
              const SizedBox(height: 20),
              if (controller.isLoading.value)
                const CircularProgressIndicator()
              else if (controller.hasError.value)
                Column(
                  children: [
                    const Text('No internet connection'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: controller.checkConnectivity,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
            ],
          );
        }),
      ),
    );
  }
}