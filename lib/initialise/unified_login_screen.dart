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
    _initializeCompanyId();
  }

  // Load stored credentials if they exist (for auto-fill or remember me functionality)
  Future<void> _loadStoredCredentials() async {
    try {
      final credentials = await _getStoredCredentials();
      if (credentials['username'] != null &&
          credentials['username']!.isNotEmpty) {
        // Auto-fill username if credentials are stored
        _usernameController.text = credentials['username']!;
        // Note: For security, we don't auto-fill password, but we could indicate
        // that credentials are remembered
        print('Loaded stored username: ${credentials['username']}');
      }
    } catch (e) {
      print('Error loading stored credentials: $e');
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRoles() async {
    await _authController.loadUserRoles();
  }

  Future<void> _initializeCompanyId() async {
    try {
      print('Initializing company ID during app startup');
      await _monitorApiService.initializeCompanyId();
      print('Company ID initialized successfully during startup');
    } catch (e) {
      print('Warning: Failed to initialize company ID during startup: $e');
      // Don't fail the app startup if company ID initialization fails
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Authenticate user
        final success = await _authController.serverLogin(
          _usernameController.text,
          _passwordController.text,
        );

        if (success) {
          // Store credentials securely after successful authentication
          await _storeCredentialsSecurely(
            _usernameController.text,
            _passwordController.text,
          );

          // Initialize company ID for Monitor API service
          try {
            await _monitorApiService.initializeCompanyId();
            print('Company ID initialized successfully');
          } catch (e) {
            print('Warning: Failed to initialize company ID: $e');
          }

          final Map<String, dynamic>? data = await _apiService
              .getStoredUserData();
          final List<dynamic>? roles = data?['roles'];
          print(roles);

          // Save account for current system
          final system =
              (roles != null &&
                  roles.any(
                    (role) => role.toString().toLowerCase().contains("admin"),
                  ))
              ? 'monitor'
              : 'pos';

          if (data != null) {
            final account = UserAccount(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              username: data['username'] ?? _usernameController.text,
              system: system,
              userData: data,
              lastLogin: DateTime.now(),
            );
            await _accountManager.addAccount(account);
            await _accountManager.setCurrentAccount(account);
          }

          if (roles != null &&
              roles.any(
                (role) => role.toString().toLowerCase().contains("admin"),
              )) {
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
            // Redirect to Monitor app splash screen
            Get.offAll(() => const MonitorAppRoot());
          } else {
            Get.offAll(() => const PosAppRoot());
          }
        }
      } catch (e) {
        // Handle login error
        print('Login error: $e');
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

  // Store credentials securely using FlutterSecureStorage
  Future<void> _storeCredentialsSecurely(
    String username,
    String password,
  ) async {
    try {
      // Store username and password securely
      await _secureStorage.write(key: _usernameKey, value: username);
      await _secureStorage.write(key: _passwordKey, value: password);

      // Verify that credentials were stored successfully
      final storedUsername = await _secureStorage.read(key: _usernameKey);
      final storedPassword = await _secureStorage.read(key: _passwordKey);

      if (storedUsername == username && storedPassword == password) {
        print('Credentials stored securely successfully');
      } else {
        print('Warning: Credential storage verification failed');
      }
    } catch (e) {
      print('Error storing credentials securely: $e');
    }
  }

  Future<Map<String, String?>> _getStoredCredentials() async {
    try {
      final username = await _secureStorage.read(key: _usernameKey);
      final password = await _secureStorage.read(key: _passwordKey);
      return {'username': username, 'password': password};
    } catch (e) {
      print('Error retrieving stored credentials: $e');
      return {'username': null, 'password': null};
    }
  }

  // Clear stored credentials (for logout or security purposes)
  Future<void> _clearStoredCredentials() async {
    try {
      await _secureStorage.delete(key: _usernameKey);
      await _secureStorage.delete(key: _passwordKey);
      print('Stored credentials cleared successfully');
    } catch (e) {
      print('Error clearing stored credentials: $e');
    }
  }

  // Check if credentials are stored securely
  Future<bool> _hasStoredCredentials() async {
    try {
      final username = await _secureStorage.read(key: _usernameKey);
      final password = await _secureStorage.read(key: _passwordKey);
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
