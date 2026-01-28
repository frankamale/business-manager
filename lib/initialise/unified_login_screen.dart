import 'package:bac_pos/back_pos/services/api_services.dart';
import 'package:bac_pos/bac_monitor/lib/services/api_services.dart';
import 'package:bac_pos/bac_monitor/lib/services/account_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bac_pos/back_pos/controllers/auth_controller.dart';
import 'package:bac_pos/back_pos/config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../bac_monitor/lib/controllers/mon_dashboard_controller.dart';
import '../bac_monitor/lib/controllers/mon_operator_controller.dart';
import '../bac_monitor/lib/controllers/mon_store_controller.dart';
import '../back_pos/controllers/inventory_controller.dart';
import 'app_roots.dart';

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  PosApiService _apiService = PosApiService();
  final MonitorApiService _monitorApiService = MonitorApiService();
  final AccountManager _accountManager = Get.find<AccountManager>();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthController _authController = Get.find<AuthController>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Initialize secure storage for credentials
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Keys for secure storage
  static const String _usernameKey = 'login_username';
  static const String _passwordKey = 'login_password';

  @override
  void initState() {
    super.initState();
    _loadUserRoles();
    _loadStoredCredentials();
    // Note: We don't initialize company ID here because:
    // 1. On fresh login, there's no company yet
    // 2. AuthController.serverLogin handles opening the database after authentication
  }

  // Load stored credentials if they exist (for auto-fill or remember me functionality)
  Future<void> _loadStoredCredentials() async {
    try {
      final credentials = await _getStoredCredentials();
      if (credentials['username'] != null &&
          credentials['username']!.isNotEmpty) {
        // Auto-fill username if credentials are stored
        _usernameController.text = credentials['username']!;
        print('DEBUG: UnifiedLoginScreen - Loaded stored username: ${credentials['username']}');
      }
    } catch (e) {
      print('DEBUG: UnifiedLoginScreen - Error loading stored credentials: $e');
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRoles() async {
    // This may fail if database isn't open yet, which is fine for login screen
    try {
      await _authController.loadUserRoles();
    } catch (e) {
      print('DEBUG: UnifiedLoginScreen - Could not load user roles (expected on fresh login): $e');
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        print('DEBUG: UnifiedLoginScreen._handleLogin() - Starting login');

        // Authenticate user - returns all needed data so we don't re-read
        final loginResult = await _authController.serverLogin(
          _usernameController.text,
          _passwordController.text,
        );

        if (loginResult != null) {
          // Extract data from login result (no storage reads needed)
          final companyId = loginResult['companyId'] as String;
          final token = loginResult['token'] as String;
          final userData = loginResult['userData'] as Map<String, dynamic>;
          final roles = userData['roles'] as List<dynamic>?;

          print('DEBUG: UnifiedLoginScreen._handleLogin() - User roles: $roles');

          // Determine if user is admin (monitor) or regular POS user
          final isAdmin = roles != null &&
              roles.any((role) => role.toString().toLowerCase().contains("admin"));

          // Fire-and-forget: Store credentials for auto-fill (non-blocking)
          _storeCredentialsSecurely(_usernameController.text, _passwordController.text);

          // Fire-and-forget: Sync to monitor service if admin (non-blocking)
          if (isAdmin) {
            _syncToMonitorService(token, companyId, userData, _usernameController.text, _passwordController.text);
          }

          print('DEBUG: UnifiedLoginScreen._handleLogin() - Navigating to ${isAdmin ? 'monitor' : 'pos'} app');

          if (isAdmin) {
            // Initialize monitor controllers (fast in-memory operations)
            if (!Get.isRegistered<MonDashboardController>()) {
              Get.put(MonDashboardController());
            }
            if (!Get.isRegistered<MonOperatorController>()) {
              Get.put(MonOperatorController());
            }
            if (!Get.isRegistered<MonStoresController>()) {
              Get.put(MonStoresController());
            }
            if (!Get.isRegistered<InventoryController>()) {
              Get.put(InventoryController());
            }
            Get.offAll(() => const MonitorAppRoot());
          } else {
            Get.offAll(() => const PosAppRoot());
          }
        }
      } catch (e) {
        print('ERROR: UnifiedLoginScreen._handleLogin() - Login error: $e');
        setState(() {
          _errorMessage = 'Network error: Please check your internet connection and try again.';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Fire-and-forget sync to monitor service
  void _syncToMonitorService(String token, String companyId, Map<String, dynamic> userData, String username, String password) {
    // Run in background - don't await
    Future.wait([
      _monitorApiService.storeToken(token),
      _monitorApiService.storeCompanyId(companyId),
      _monitorApiService.storeUserData({...userData, 'companyId': companyId}),
      _monitorApiService.saveServerCredentials(username, password),
    ]).then((_) {
      print('DEBUG: UnifiedLoginScreen - Monitor service sync completed in background');
    }).catchError((e) {
      print('DEBUG: UnifiedLoginScreen - Monitor service sync error (non-fatal): $e');
    });
  }

  // Store credentials securely using FlutterSecureStorage (fire-and-forget)
  void _storeCredentialsSecurely(String username, String password) {
    // Run in background - don't block navigation
    Future.wait([
      _secureStorage.write(key: _usernameKey, value: username),
      _secureStorage.write(key: _passwordKey, value: password),
    ]).then((_) {
      print('DEBUG: Credentials stored for auto-fill');
    }).catchError((e) {
      print('DEBUG: Credential storage error (non-fatal): $e');
    });
  }

  Future<Map<String, String?>> _getStoredCredentials() async {
    try {
      // Read both in parallel
      final results = await Future.wait([
        _secureStorage.read(key: _usernameKey),
        _secureStorage.read(key: _passwordKey),
      ]);
      return {'username': results[0], 'password': results[1]};
    } catch (e) {
      print('Error retrieving stored credentials: $e');
      return {'username': null, 'password': null};
    }
  }

  // Clear stored credentials (for logout or security purposes)
  Future<void> _clearStoredCredentials() async {
    try {
      // Delete both in parallel
      await Future.wait([
        _secureStorage.delete(key: _usernameKey),
        _secureStorage.delete(key: _passwordKey),
      ]);
      print('Stored credentials cleared successfully');
    } catch (e) {
      print('Error clearing stored credentials: $e');
    }
  }

  // Check if credentials are stored securely
  Future<bool> _hasStoredCredentials() async {
    try {
      // Read both in parallel
      final results = await Future.wait([
        _secureStorage.read(key: _usernameKey),
        _secureStorage.read(key: _passwordKey),
      ]);
      final username = results[0];
      final password = results[1];
      return username != null &&
          username.isNotEmpty &&
          password != null &&
          password.isNotEmpty;
    } catch (e) {
      print('Error checking stored credentials: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;

    return Scaffold(
      body: Container(
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
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 10.0 : 20.0,
                vertical: 24.0,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isSmallScreen ? 400 : 480,
                ),
                child: Card(
                  elevation: 12,
                  shadowColor: Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 32.0 : 48.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          Hero(
                            tag: 'logo',
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                "assets/images/logo.png",
                                width: isSmallScreen ? 100 : 120,
                                height: isSmallScreen ? 100 : 120,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.storefront_rounded,
                                    size: isSmallScreen ? 100 : 120,
                                    color: Colors.blue.shade700,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Title
                          Text(
                            "Welcome Back",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 28 : 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${AppConfig.companyName}",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Account Selection Dropdown
                          TextFormField(
                            controller: _usernameController,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(
                                Icons.person_outline_rounded,
                                color: Colors.blue.shade700,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.blue.shade700,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your username';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.blue.shade700,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.grey.shade600,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.blue.shade700,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),

                          if (_errorMessage != null)

                            Text(

                              _errorMessage!,

                              style: TextStyle(color: Colors.red),

                              textAlign: TextAlign.center,

                            ),

                          const SizedBox(height: 12),
                          // Sign In Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: Colors.blue.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                disabledBackgroundColor: Colors.grey.shade300,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Footer
                          Row(
                            children: [
                              Hero(
                                tag: 'footer_logo',
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Image.asset(
                                    "assets/images/logo.png",
                                    width: isSmallScreen ? 30 : 50,
                                    height: isSmallScreen ? 30 : 50,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.storefront_rounded,
                                        size: isSmallScreen ? 30 : 50,
                                        color: Colors.blue.shade700,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                AppConfig.copyright,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
