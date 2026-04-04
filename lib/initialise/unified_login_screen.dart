import 'package:bac_pos/back_pos/services/api_services.dart';
import 'package:bac_pos/bac_monitor/lib/services/api_services.dart';
import 'package:bac_pos/bac_monitor/lib/services/account_manager.dart';
import 'package:bac_pos/flavors/flavor_config.dart';
import 'package:bac_pos/shared/database/unified_db_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bac_pos/back_pos/controllers/auth_controller.dart';
import 'package:bac_pos/back_pos/config.dart';
import 'package:get_storage/get_storage.dart';

import '../bac_monitor/lib/additions/colors.dart';
import '../bac_monitor/lib/controllers/mon_dashboard_controller.dart';
import '../bac_monitor/lib/controllers/mon_operator_controller.dart';
import '../bac_monitor/lib/controllers/mon_store_controller.dart';
import '../back_pos/controllers/inventory_controller.dart';
import '../client/auth/password_recovery.dart';
import '../client/auth/account_pending_screen.dart';
import '../client/auth/register.dart';
import '../flavors/flavor_colors.dart';
import '../shared/services/customer_auth_service.dart';
import '../shared/services/credential_helper.dart';
import '../shared/widgets/app_logo.dart';
import 'app_roots.dart';

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  PosApiService _apiService = Get.find<PosApiService>();
  final MonitorApiService _monitorApiService = Get.find<MonitorApiService>();
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

  Future<void> _loadStoredCredentials() async {
    try {
      final credentials = await _getStoredCredentials();
      if (credentials['username'] != null &&
          credentials['username']!.isNotEmpty) {
        _usernameController.text = credentials['username']!;
      }
    } catch (e) {
      // Ignore
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRoles() async {
    try {
      await _authController.loadUserRoles();
    } catch (e) {
      // Expected on fresh login
    }
  }

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
          await _handleCustomerLogin();
        } else {
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

  Future<void> _handleCustomerLogin() async {
    final identifier = _usernameController.text.trim();
    final pin = _passwordController.text;

    final cachedCustomer = await _customerAuthService
        .validateCachedCustomerLogin(identifier: identifier, pin: pin);

    if (cachedCustomer != null) {
      await _completeCustomerLogin(cachedCustomer, identifier, pin);
      return;
    }

    await _handleServerCustomerLogin(identifier, pin);
  }

  Future<void> _handleServerCustomerLogin(String identifier, String pin) async {
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

    if (customer.statusid != "00000000-0000-0000-0000-000000000000") {
      Get.to(() => AccountPendingScreen(email: customer.email));
      return;
    }

    if (!_customerAuthService.validateCustomerPin(customer, pin)) {
      throw Exception('Invalid PIN. Please try again.');
    }

    await _customerAuthService.cacheCustomerAccount(customer);
    await _completeCustomerLogin(customer, identifier, pin);
  }

  Future<void> _completeCustomerLogin(
    dynamic customer,
    String identifier,
    String pin,
  ) async {
    final box = GetStorage();
    await box.remove('pending_registration');
    await box.write('logged_in_customer', customer.toMap());
    await box.write('is_customer_logged_in', true);
    await box.write(
      'customer_login_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );

    await _storeCredentialsSecurely(identifier, pin);

    Get.offAll(() => const ClientAppRoot());
  }

  Future<void> _handleStaffLogin() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    final cachedAccount = await _customerAuthService.validateCachedStaffLogin(
      username: username,
      password: password,
    );

    if (cachedAccount != null) {
      await _handleCachedStaffLogin(cachedAccount, username, password);
      return;
    }

    await _handleServerStaffLogin(username, password);
  }

  Future<void> _handleCachedStaffLogin(
    Map<String, dynamic> cachedAccount,
    String username,
    String password,
  ) async {
    final companyId = cachedAccount['companyId'] as String;
    final roles = cachedAccount['roles'] as List<dynamic>?;
    final userData = cachedAccount['userData'] as Map<String, dynamic>? ?? {};

    await UnifiedDatabaseHelper.instance.openForCompany(companyId);

    try {
      final box = GetStorage();
      await box.write('last_company_id', companyId);
      await box.write('last_username', username);

      final isAdmin = CredentialHelper.isAdminFromRoles(roles);
      final userRole = isAdmin ? 'admin' : 'staff';
      await box.write('last_user_role', userRole);

      debugPrint(
        'UnifiedLoginScreen: Offline credentials stored in GetStorage (company: $companyId, role: $userRole, user: $username)',
      );
    } catch (e) {
      debugPrint(
        'UnifiedLoginScreen: Error storing credentials in GetStorage: $e',
      );
    }

    final isAdmin = CredentialHelper.isAdminFromRoles(roles);
    final targetSystem = isAdmin ? 'monitor' : 'pos';

    final account = UserAccount(
      id: companyId,
      username: username.toLowerCase(),
      system: targetSystem,
      userData: {...userData, 'companyId': companyId},
      lastLogin: DateTime.now(),
    );
    await _accountManager.setCurrentAccount(account);
    await _accountManager.addAccount(account);

    await _storeCredentialsSecurely(username, password);

    if (isAdmin) {
      try {
        final loginResult = await _authController.serverLogin(
          username,
          password,
        );
        if (loginResult != null) {
          final token = loginResult['token'] as String;
          await _syncToMonitorServiceAsync(
            token,
            companyId,
            userData,
            username,
            password,
          );
        }
      } catch (e) {
        debugPrint(
          'UnifiedLoginScreen: Server sync failed, but company ID stored for offline mode',
        );
      }
    }

    _navigateToHome(isAdmin);
  }

  Future<void> _handleServerStaffLogin(String username, String password) async {
    final loginResult = await _authController.serverLogin(username, password);

    if (loginResult != null) {
      final companyId = loginResult['companyId'] as String;
      final token = loginResult['token'] as String;
      final userData = loginResult['userData'] as Map<String, dynamic>;
      final roles = userData['roles'] as List<dynamic>?;

      if (appFlavor != "bac") {
        final botCompanyId = await _customerAuthService.getBotCompanyId();
        if (botCompanyId != null && botCompanyId.isNotEmpty) {
          if (companyId != botCompanyId) {
            throw Exception('Wrong Username or Password');
          }
        }
      }

      await _customerAuthService.cacheStaffAccount(
        username: username,
        password: password,
        companyId: companyId,
        roles: roles ?? [],
        userData: userData,
      );

      try {
        final box = GetStorage();
        await box.write('last_company_id', companyId);
        await box.write('last_username', username);

        final isAdmin = CredentialHelper.isAdminFromRoles(roles);
        final userRole = isAdmin ? 'admin' : 'staff';
        await box.write('last_user_role', userRole);

        debugPrint(
          'UnifiedLoginScreen: Offline credentials stored in GetStorage (company: $companyId, role: $userRole, user: $username)',
        );
      } catch (e) {
        debugPrint(
          'UnifiedLoginScreen: Error storing credentials in GetStorage: $e',
        );
      }

      final isAdmin = CredentialHelper.isAdminFromRoles(roles);
      final targetSystem = isAdmin ? 'monitor' : 'pos';

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

      await _storeCredentialsSecurely(username, password);

      if (isAdmin) {
        await _syncToMonitorServiceAsync(
          token,
          companyId,
          userData,
          username,
          password,
        );
      }

      _navigateToHome(isAdmin);
    }
  }

  void _navigateToHome(bool isAdmin) {
    if (isAdmin) {
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

  Future<void> _storeCredentialsSecurely(String username, String password) async {
    await CredentialHelper.storeCredentials(username, password);
  }

  Future<Map<String, String?>> _getStoredCredentials() async {
    return CredentialHelper.getStoredCredentials();
  }

  Future<void> _clearStoredCredentials() async {
    await CredentialHelper.clearCredentials();
  }

  Future<bool> _hasStoredCredentials() async {
    return CredentialHelper.hasStoredCredentials();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final Color inputFillColor = isDark
        ? const Color(0xFF2A2A3C)
        : Colors.grey.shade50;
    final Color inputTextColor = isDark ? Colors.white : Colors.black87;
    final Color labelColor = isDark ? Colors.white70 : Colors.black;
    final Color iconColor = isDark ? Colors.white70 : Colors.black87;
    final Color borderColor = isDark ? Colors.white24 : Colors.grey.shade500;
    final Color footerTextColor = isDark
        ? Colors.white54
        : Colors.grey.shade600;
    final Color welcomeTextColor = isDark
        ? Colors.white70
        : FlavorColors.current.primaryDark;
    final Color titleTextColor = isDark
        ? Colors.white
        : (FlavorColors.current.primaryPlus ?? const Color(0xFF222222));
    final Color linkColor = isDark
        ? Colors.blue.shade300
        : Colors.blue.shade700;
    final Color disabledBgColor = isDark
        ? Colors.grey.shade700
        : Colors.grey.shade300;
    final Color errorTextColor = isDark ? Colors.red.shade300 : Colors.red;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: AppColors.getBackgroundColor(context)),
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
                  color: cardColor,
                  elevation: 12,
                  // shadowColor: Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  borderOnForeground: true,
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 32.0 : 48.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Hero(
                            tag: 'logo',
                            child: AppLogoCircle(
                              size: isSmallScreen ? 100 : 120,
                            ),
                          ),
                          const SizedBox(height: 15),

                          Text(
                            "${AppConfig.companyName}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 25 : 29,
                              fontWeight: FontWeight.bold,
                              color: titleTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppConfig.description,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              color: welcomeTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 40),

                          TextFormField(
                            controller: _usernameController,
                            style: TextStyle(
                              color: inputTextColor,
                              fontSize: 16,
                            ),
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: TextStyle(color: labelColor),
                              prefixIcon: Icon(
                                Icons.person_outline_rounded,
                                color: iconColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: FlavorColors.current.primaryDark,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: inputFillColor,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your username';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _passwordController,
                            style: TextStyle(
                              color: inputTextColor,
                              fontSize: 16,
                            ),
                            obscureText: _obscurePassword,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(color: labelColor),
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                color: FlavorColors.current.primaryDark,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: FlavorColors.current.primaryDark,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: inputFillColor,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),

                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: errorTextColor),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          if (appFlavor == "bac") const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (appFlavor != "bac")
                                TextButton(
                                  onPressed: () =>
                                      Get.to(() => PasswordRecovery()),
                                  child: Text(
                                    "Forgot Password?",
                                    style: TextStyle(color: linkColor),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade800,
                                foregroundColor: FlavorColors.current.onPrimary,
                                elevation: 4,
                                shadowColor: FlavorColors.current.primaryDark
                                    .withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                disabledBackgroundColor: disabledBgColor,
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

                          if (appFlavor != "bac")
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _hasPendingRegistration
                                    ? null
                                    : () => Get.to(Register()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      FlavorColors.current.primaryDark,
                                  foregroundColor:
                                      FlavorColors.current.onPrimary,
                                  elevation: 4,
                                  shadowColor: FlavorColors.current.primaryDark
                                      .withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  disabledBackgroundColor: disabledBgColor,
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
                                  color: footerTextColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          const SizedBox(height: 24),

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
                                  color: footerTextColor,
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
