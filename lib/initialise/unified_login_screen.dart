import 'package:bac_pos/back_pos/services/api_services.dart';
import 'package:bac_pos/bac_monitor/lib/services/api_services.dart';
import 'package:bac_pos/bac_monitor/lib/services/account_manager.dart';
import 'package:bac_pos/flavors/flavor_config.dart';
import 'package:bac_pos/shared/database/unified_db_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bac_pos/back_pos/controllers/auth_controller.dart';
import 'package:bac_pos/back_pos/config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';

import '../bac_monitor/lib/controllers/mon_dashboard_controller.dart';
import '../bac_monitor/lib/controllers/mon_operator_controller.dart';
import '../bac_monitor/lib/controllers/mon_store_controller.dart';
import '../back_pos/controllers/inventory_controller.dart';
import '../client/auth/password_recovery.dart';
import '../client/auth/account_pending_screen.dart';
import '../client/auth/register.dart';
import '../flavors/flavor_colors.dart';
import '../shared/services/customer_auth_service.dart';
import '../shared/widgets/app_logo.dart';
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
  final CustomerAuthService _customerAuthService = CustomerAuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _hasPendingRegistration = false;
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
    _checkPendingRegistration();
  }

  void _checkPendingRegistration() {
    final box = GetStorage();
    final pending = box.read('pending_registration');
    if (pending != null) {
      setState(() {
        _hasPendingRegistration = true;
      });
    }
  }

  // Load stored credentials if they exist (for auto-fill or remember me functionality)
  Future<void> _loadStoredCredentials() async {
    try {
      final credentials = await _getStoredCredentials();
      if (credentials['username'] != null &&
          credentials['username']!.isNotEmpty) {
        _usernameController.text = credentials['username']!;
      }
    } catch (e) {
      // Ignore - not critical for login
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
      // Expected on fresh login - ignore
    }
  }

  /// Check if password is purely numeric (customer PIN)
  bool _isNumericPassword(String password) {
    return password.isNotEmpty && RegExp(r'^\d+$').hasMatch(password);
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final password = _passwordController.text;

        if (_isNumericPassword(password)) {
          // Customer authentication flow (numeric PIN)
          await _handleCustomerLogin();
        } else {
          // Existing staff/admin authentication flow
          await _handleStaffLogin();
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Handle customer authentication with numeric PIN
  Future<void> _handleCustomerLogin() async {
    final identifier = _usernameController.text.trim();
    final pin = _passwordController.text;

    // Try cached login first (valid for 24 hours)
    final cachedCustomer = await _customerAuthService
        .validateCachedCustomerLogin(identifier: identifier, pin: pin);

    if (cachedCustomer != null) {
      // Cached login successful - use cached data
      await _completeCustomerLogin(cachedCustomer, identifier, pin);
      return;
    }

    // No valid cache - authenticate via bot/server
    await _handleServerCustomerLogin(identifier, pin);
  }

  /// Handle customer login via server (bot authentication)
  Future<void> _handleServerCustomerLogin(String identifier, String pin) async {
    // Check if bot credentials are configured
    if (!await _customerAuthService.hasBotCredentials()) {
      throw Exception(
        'Customer login not configured. Please contact administrator.',
      );
    }

    final botToken = await _customerAuthService.getBotToken();
    final customers = await _customerAuthService.fetchCustomers(botToken);

    final customer = _customerAuthService.findCustomerByIdentifier(
      customers,
      identifier,
    );

    if (customer == null) {
      throw Exception('Wrong Username or Password. Please try again...');
    }

    // Check if customer account is enabled
    if (customer.posenabled != true) {
      Get.to(() => AccountPendingScreen(email: customer.email));
      return;
    }

    // Validate PIN using bcrypt
    if (!_customerAuthService.validateCustomerPin(customer, pin)) {
      throw Exception('Invalid PIN. Please try again.');
    }

    // Cache the customer account for future logins (valid for 24 hours)
    await _customerAuthService.cacheCustomerAccount(customer);

    // Complete the login
    await _completeCustomerLogin(customer, identifier, pin);
  }

  /// Complete customer login (shared by cached and server login)
  Future<void> _completeCustomerLogin(
    dynamic customer,
    String identifier,
    String pin,
  ) async {
    // Store customer data in GetStorage for offline usage
    final box = GetStorage();
    // Account is approved, clear pending registration flag
    await box.remove('pending_registration');
    await box.write('logged_in_customer', customer.toMap());
    await box.write('is_customer_logged_in', true);
    await box.write(
      'customer_login_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );

    // Store credentials for auto-fill (fire-and-forget)
    _storeCredentialsSecurely(identifier, pin);

    Get.offAll(() => const ClientAppRoot());
  }

  /// Handle staff/admin authentication (existing flow)
  Future<void> _handleStaffLogin() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    // Try cached login first (valid for 24 hours)
    final cachedAccount = await _customerAuthService.validateCachedStaffLogin(
      username: username,
      password: password,
    );

    if (cachedAccount != null) {
      // Cached login successful - use cached data
      await _handleCachedStaffLogin(cachedAccount, username, password);
      return;
    }

    // No valid cache - authenticate with server
    await _handleServerStaffLogin(username, password);
  }

  /// Handle login using cached account data
  Future<void> _handleCachedStaffLogin(
    Map<String, dynamic> cachedAccount,
    String username,
    String password,
  ) async {
    final companyId = cachedAccount['companyId'] as String;
    final roles = cachedAccount['roles'] as List<dynamic>?;
    final userData = cachedAccount['userData'] as Map<String, dynamic>? ?? {};

    // Open database for the company
    await UnifiedDatabaseHelper.instance.openForCompany(companyId);

    // Determine if user is admin (monitor) or regular POS user
    final isAdmin =
        roles != null &&
        roles.any((role) => role.toString().toLowerCase().contains("admin"));
    final targetSystem = isAdmin ? 'monitor' : 'pos';

    // Set up account manager
    final account = UserAccount(
      id: companyId,
      username: username.toLowerCase(),
      system: targetSystem,
      userData: {...userData, 'companyId': companyId},
      lastLogin: DateTime.now(),
    );
    await _accountManager.setCurrentAccount(account);

    // Store credentials for auto-fill
    _storeCredentialsSecurely(username, password);

    // Navigate to appropriate screen
    _navigateToHome(isAdmin);
  }

  /// Handle login via server authentication
  Future<void> _handleServerStaffLogin(String username, String password) async {
    // Authenticate user - returns all needed data so we don't re-read
    final loginResult = await _authController.serverLogin(username, password);

    if (loginResult != null) {
      // Extract data from login result (no storage reads needed)
      final companyId = loginResult['companyId'] as String;
      final token = loginResult['token'] as String;
      final userData = loginResult['userData'] as Map<String, dynamic>;
      final roles = userData['roles'] as List<dynamic>?;

      // Validate company ID against bot's company (for flavored apps)
      final botCompanyId = await _customerAuthService.getBotCompanyId();
      if (botCompanyId != null && botCompanyId.isNotEmpty) {
        if (companyId != botCompanyId) {
          throw Exception('Wrong Username or Password');
        }
      }

      // Cache the account for future logins (valid for 24 hours)
      await _customerAuthService.cacheStaffAccount(
        username: username,
        password: password,
        companyId: companyId,
        roles: roles ?? [],
        userData: userData,
      );

      // Determine if user is admin (monitor) or regular POS user
      final isAdmin =
          roles != null &&
          roles.any((role) => role.toString().toLowerCase().contains("admin"));
      final targetSystem = isAdmin ? 'monitor' : 'pos';

      // Update account with correct system if needed
      final currentAccount = _accountManager.currentAccount.value;
      if (currentAccount != null && currentAccount.system != targetSystem) {
        final updatedAccount = UserAccount(
          id: currentAccount.id,
          username: currentAccount.username,
          system: targetSystem,
          userData: {...currentAccount.userData, 'companyId': companyId},
          lastLogin: DateTime.now(),
        );
        await _accountManager.setCurrentAccount(updatedAccount);
      }

      // Fire-and-forget: Store credentials for auto-fill (non-blocking)
      _storeCredentialsSecurely(username, password);

      // Sync to monitor service if admin - MUST await for account switching to work
      if (isAdmin) {
        await _syncToMonitorServiceAsync(
          token,
          companyId,
          userData,
          username,
          password,
        );
      }

      // Navigate to appropriate screen
      _navigateToHome(isAdmin);
    }
  }

  /// Navigate to the appropriate home screen based on user role
  void _navigateToHome(bool isAdmin) {
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

  /// Sync to monitor service
  Future<void> _syncToMonitorServiceAsync(
    String token,
    String companyId,
    Map<String, dynamic> userData,
    String username,
    String password,
  ) async {
    await Future.wait([
      _monitorApiService.storeToken(token),
      _monitorApiService.storeCompanyId(companyId),
      _monitorApiService.storeUserData({...userData, 'companyId': companyId}),
      _monitorApiService.saveServerCredentials(username, password),
    ]);
  }

  // Store credentials securely using FlutterSecureStorage (fire-and-forget)
  void _storeCredentialsSecurely(String username, String password) {
    Future.wait([
      _secureStorage.write(key: _usernameKey, value: username),
      _secureStorage.write(key: _passwordKey, value: password),
    ]);
  }

  Future<Map<String, String?>> _getStoredCredentials() async {
    try {
      final results = await Future.wait([
        _secureStorage.read(key: _usernameKey),
        _secureStorage.read(key: _passwordKey),
      ]);
      return {'username': results[0], 'password': results[1]};
    } catch (e) {
      return {'username': null, 'password': null};
    }
  }

  // Clear stored credentials (for logout or security purposes)
  Future<void> _clearStoredCredentials() async {
    await Future.wait([
      _secureStorage.delete(key: _usernameKey),
      _secureStorage.delete(key: _passwordKey),
    ]);
  }

  // Check if credentials are stored securely
  Future<bool> _hasStoredCredentials() async {
    try {
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
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FlavorColors.current.primaryDark,
              FlavorColors.current.secondary,
              FlavorColors.current.primaryDark,
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
                            child: AppLogoCircle(
                              size: isSmallScreen ? 100 : 120,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Title
                          Text(
                            "${AppConfig.companyName}",
                            textAlign: TextAlign.center,
                            style: TextStyle(

                              fontSize: isSmallScreen ? 28 : 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppConfig.description,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              color: FlavorColors.current.primaryDark,
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
                                color: FlavorColors.current.primaryDark,
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
                                  color: FlavorColors.current.primaryDark,
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
                                color: FlavorColors.current.primaryDark,
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
                                  color: FlavorColors.current.primaryDark,
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    Get.to(() => PasswordRecovery()),
                                child: Text("Forgot Password?"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          // Sign In Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FlavorColors.current.primary,
                                foregroundColor: FlavorColors.current.onPrimary,
                                elevation: 4,
                                shadowColor: FlavorColors.current.primaryDark.withOpacity(0.5),
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

                          SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _hasPendingRegistration
                                  ? null
                                  : () => Get.to(Register()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FlavorColors.current.primaryDark,
                                foregroundColor: FlavorColors.current.onPrimary,
                                elevation: 4,
                                shadowColor: FlavorColors.current.primaryDark.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                disabledBackgroundColor: Colors.grey.shade300,
                              ),
                              child: const Text(
                                'Register Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          if (_hasPendingRegistration)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'A registration is pending approval on this device.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Footer
                          Row(
                            children: [
                              Hero(
                                tag: 'footer_logo',
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: isSmallScreen ? 30 : 50,
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
