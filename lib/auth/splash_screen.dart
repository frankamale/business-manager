import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'login.dart';
import '../services/api_services.dart';
import '../controllers/auth_controller.dart';
import '../controllers/service_point_controller.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/sales_controller.dart';
import '../controllers/payment_controller.dart';
import '../controllers/customer_controller.dart';
import '../database/db_helper.dart';
import '../utils/network_helper.dart';
import '../config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  String _statusMessage = 'Initializing...';
  bool _hasError = false;
  bool _isOfflineMode = false;
  bool _hasCachedData = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _authenticateApp();
  }

  void _setupAnimations() {
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
  }

  Future<void> _authenticateApp() async {
    try {
      setState(() {
        _statusMessage = 'Checking authentication...';
      });

      // Check if already authenticated
      final isAuthenticated = await _apiService.isAuthenticated();

      if (!isAuthenticated) {
        // First launch - check network
        final hasNetwork = await NetworkHelper.hasConnection();
        if (!hasNetwork) {
          setState(() {
            _hasError = true;
            _isOfflineMode = true;
            _statusMessage = 'No internet connection';
          });
          return; // Show retry button, don't loop
        }

        // Authenticate
        setState(() {
          _statusMessage = 'Connecting to server...';
        });

        await _apiService.signIn(
          AppConfig.defaultUsername,
          AppConfig.defaultPassword,
        );

        setState(() {
          _statusMessage = 'Loading company info...';
        });

        await _apiService.fetchAndStoreCompanyInfo();
      }

      // Initialize all controllers
      _initializeControllers();

      // Smart data loading
      await _loadDataWithSmartSync();

      // Navigate to login
      setState(() {
        _statusMessage = 'Finishing setup...';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Get.off(() => const Login());
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _statusMessage = 'Error loading app';
      });

      Get.snackbar(
        'Error',
        'Failed to initialize app: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 4),
      );

      // Don't retry automatically - let user control it
    }
  }

  void _initializeControllers() {
    Get.put(AuthController());
    Get.put(ServicePointController());
    Get.put(InventoryController());
    Get.put(SalesController());
    Get.put(PaymentController());
    Get.put(CustomerController());
  }

  Future<void> _loadDataWithSmartSync() async {
    final hasNetwork = await NetworkHelper.hasConnection();

    // Get controllers
    final authController = Get.find<AuthController>();
    final servicePointController = Get.find<ServicePointController>();
    final inventoryController = Get.find<InventoryController>();
    final salesController = Get.find<SalesController>();
    final customerController = Get.find<CustomerController>();

    // 1. Users (static - load from cache if exists)
    setState(() {
      _statusMessage = 'Loading users...';
    });
    final hasUsers = await _dbHelper.hasCachedData('users');
    if (!hasUsers && hasNetwork) {
      await authController.syncUsersFromAPI();
    } else if (hasUsers) {
      await authController.loadUsersFromCache();
    }

    // 2. Service Points (static - load from cache if exists)
    setState(() {
      _statusMessage = 'Loading service points...';
    });
    final hasServicePoints = await _dbHelper.hasCachedData('service_points');
    if (!hasServicePoints && hasNetwork) {
      await servicePointController.syncServicePointsFromAPI();
    } else if (hasServicePoints) {
      await servicePointController.loadServicePointsFromCache();
    }

    // 3. Inventory (dynamic - sync if network available)
    setState(() {
      _statusMessage = 'Loading inventory...';
    });
    final hasInventory = await _dbHelper.hasCachedData('inventory');
    if (hasNetwork) {
      await inventoryController.syncInventoryFromAPI();
    } else if (hasInventory) {
      await inventoryController.loadInventoryFromCache();
    }

    // 4. Sales (local only - no remote sync)
    setState(() {
      _statusMessage = 'Loading local sales...';
    });
    await salesController.loadSalesFromCache();

    // 5. Customers (dynamic - sync if network available)
    setState(() {
      _statusMessage = 'Loading customers...';
    });
    final hasCustomers = await _dbHelper.hasCachedData('customers');
    if (hasNetwork) {
      await customerController.syncCustomersFromAPI();
    } else if (hasCustomers) {
      await customerController.loadCustomersFromCache();
    }

    // Check if we have minimum required data
    _hasCachedData = hasUsers && hasServicePoints;
  }

  @override
  void dispose() {
    _animationController.dispose();
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
                        width: 120,
                        height: 120,
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
                const SizedBox(height: 40),

                // App Name
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    AppConfig.appName,
                    style: TextStyle(
                      fontSize: 36,
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
                const SizedBox(height: 60),

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
                      onPressed: () => Get.off(() => const Login()),
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
