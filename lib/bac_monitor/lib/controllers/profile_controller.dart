import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'package:get/get.dart';
import '../../../back_pos/services/api_services.dart';
import '../../../initialise/app_roots.dart';
import '../services/api_services.dart';
import '../services/account_manager.dart';
import '../db/db_helper.dart';

class ProfileController extends GetxController {
  final MonitorApiService _monitorApiService = Get.find();
  final PosApiService _posApiService = Get.find();
  final AccountManager _accountManager = Get.find();

  AccountManager get accountManager => _accountManager;

  var isLoading = false.obs;
  var userData = <String, dynamic>{}.obs;
  var companyData = <String, dynamic>{}.obs;
  var errorMessage = ''.obs;
  var currentSystem = 'monitor'.obs;

  @override
  void onInit() {
    super.onInit();
    final currentAccount = _accountManager.currentAccount.value;
    if (currentAccount != null) {
      currentSystem.value = currentAccount.system;
    }
    loadProfileData();
    
    // Listen to account changes and refresh data accordingly
    ever(_accountManager.currentAccount, (UserAccount? account) {
      if (account != null) {
        currentSystem.value = account.system;
        refreshUserDataFromAccount(account);
      }
    });
  }

  Future<void> loadProfileData() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Load user data
      final user = await _posApiService.getStoredUserData();
      if (user != null) {
        userData.value = user;
      }

      final dbHelper = DatabaseHelper();
      final company = await dbHelper.getCompanyDetails();
      if (company != null) {
        companyData.value = company;
      }

    } catch (e) {
      errorMessage.value = 'Failed to load profile data: $e';
      print('ProfileController: Error loading profile data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshUserDataFromAccount(UserAccount account) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Update user data from the account's userData
      if (account.userData.isNotEmpty) {
        userData.value = account.userData;
      } else {
        // If account doesn't have userData, try to load it from the appropriate service
        if (account.system == 'monitor') {
          final user = await _monitorApiService.getStoredUserData();
          if (user != null) {
            userData.value = user;
          }
        } else {
          final user = await _posApiService.getStoredUserData();
          if (user != null) {
            userData.value = user;
          }
        }
      }

      // Load company data based on the current system
      final dbHelper = DatabaseHelper();
      final company = await dbHelper.getCompanyDetails();
      if (company != null) {
        companyData.value = company;
      }

    } catch (e) {
      errorMessage.value = 'Failed to refresh user data: $e';
      print('ProfileController: Error refreshing user data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Clear auth data from both services
      await _posApiService.clearAuthData();
      await _monitorApiService.logout();

      final currentAccount = _accountManager.currentAccount.value;
      if (currentAccount != null) {
        await _accountManager.setCurrentAccount(null);
      }

      // Navigate to login
      Get.off(()=>UnifiedLoginScreen());
    } catch (e) {
      errorMessage.value = 'Failed to sign out: $e';
      print('ProfileController: Error signing out: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> switchSystem(String system) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      currentSystem.value = system;

      // Get admin accounts for the target system
      final systemAccounts = _accountManager.getAdminAccountsForSwitch(system: system);

      if (systemAccounts.isNotEmpty) {
        // Switch to the most recently used account for this system
        await switchToAccount(systemAccounts.first);
      } else {
        // No accounts for this system - ensure database is open before navigation
        if (system == 'pos') {
          // Open POS database before navigating
          // Try multiple sources for companyId since we might be switching from monitor
          String? companyId;

          // 1. Try current account userData (when switching from monitor to POS)
          final currentAccount = _accountManager.currentAccount.value;
          if (currentAccount != null && currentAccount.userData.containsKey('companyId')) {
            companyId = currentAccount.userData['companyId']?.toString();
          }

          // 2. Try monitor service's stored company ID
          if (companyId == null || companyId.isEmpty) {
            companyId = await _monitorApiService.getStoredCompanyId();
          }

          // 3. Finally try POS service's stored company info
          if (companyId == null || companyId.isEmpty) {
            final companyInfo = await _posApiService.getCompanyInfo();
            companyId = companyInfo['companyId'];
          }

          if (companyId != null && companyId.isNotEmpty) {
            await _posApiService.openDatabaseForCompany(companyId);
            print('ProfileController: POS database opened for company $companyId (switchSystem)');
          }
          Get.offAll(() => const PosAppRoot());
        } else {
          Get.offAll(() => const MonitorAppRoot());
        }
      }
    } catch (e) {
      errorMessage.value = 'Failed to switch system: $e';
      print('ProfileController: Error switching system: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> switchToAccount(UserAccount account) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // First, logout from current account
      final currentAccount = _accountManager.currentAccount.value;
      if (currentAccount != null && currentAccount.id != account.id) {
        // Clear auth data from both services
        await _posApiService.clearAuthData();
        await _monitorApiService.logout();
      }

      // Validate token and handle re-authentication if needed
      bool hasInternet = false;
      bool tokenValid = false;
      try {
        if (account.system == 'monitor') {
          await _monitorApiService.getWithAuth('/company/details');
        } else {
          await _posApiService.validateToken();
        }
        tokenValid = true;
        hasInternet = true;
      } catch (e) {
        if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
          tokenValid = false;
          hasInternet = true;
        } else {
          hasInternet = false;
        }
      }

      if (!tokenValid && hasInternet) {
        // Re-authenticate using stored credentials
        try {
          final creds = account.system == 'monitor'
              ? await _monitorApiService.getServerCredentials()
              : await _posApiService.getServerCredentials();
          if (creds['username'] != null && creds['password'] != null) {
            if (account.system == 'monitor') {
              await _monitorApiService.login(creds['username']!, creds['password']!);
            } else {
              await _posApiService.signIn(creds['username']!, creds['password']!);
            }
            // Update account with new userData
            final newUserData = account.system == 'monitor'
                ? await _monitorApiService.getStoredUserData()
                : await _posApiService.getStoredUserData();
            if (newUserData != null) {
              account = UserAccount(
                id: account.id,
                username: account.username,
                system: account.system,
                userData: newUserData,
                lastLogin: account.lastLogin,
              );
              await _accountManager.addAccount(account);
            }
          }
        } catch (e) {
          // Re-auth failed, proceed to offline mode
        }
      }

      // ALWAYS ensure database is open before navigation (not just offline)
      // This fixes the "Database not opened" error when switching modes
      if (account.system == 'monitor') {
        if (account.userData.containsKey('companyId')) {
          await _monitorApiService.switchCompany(account.userData['companyId']);
        }
      } else {
        // For POS: Always open the database before navigation
        // Try multiple sources for companyId since we might be switching from monitor
        String? companyId;

        // 1. Try account userData first (the account we're switching to)
        if (account.userData.containsKey('companyId')) {
          companyId = account.userData['companyId']?.toString();
        }

        // 2. Try current account userData (when switching from monitor to POS)
        if ((companyId == null || companyId.isEmpty) &&
            currentAccount != null &&
            currentAccount.userData.containsKey('companyId')) {
          companyId = currentAccount.userData['companyId']?.toString();
        }

        // 3. Try monitor service's stored company ID
        if (companyId == null || companyId.isEmpty) {
          companyId = await _monitorApiService.getStoredCompanyId();
        }

        // 4. Finally try POS service's stored company info
        if (companyId == null || companyId.isEmpty) {
          final companyInfo = await _posApiService.getCompanyInfo();
          companyId = companyInfo['companyId'];
        }

        if (companyId != null && companyId.isNotEmpty) {
          await _posApiService.openDatabaseForCompany(companyId);
          print('ProfileController: POS database opened for company $companyId');
        } else {
          print('ProfileController: Warning - No companyId found for POS database');
        }
      }

      // Set the account as current
      await _accountManager.switchToAccount(account);

      // Update current system
      currentSystem.value = account.system;

      // Load the account's data into the appropriate service
      if (account.system == 'monitor') {
        // Store monitor user data
        await _monitorApiService.storeUserData(account.userData);
        await _monitorApiService.storeToken(account.userData['accessToken'] ?? '');
        
        // Ensure user role is stored separately
        if (account.userData.containsKey('roles') && account.userData['roles'] is List && account.userData['roles'].isNotEmpty) {
          final userRole = account.userData['roles'].first.toString();
          await _monitorApiService.storeUserRole(userRole);
        }

        // Switch to monitor database
        if (account.userData.containsKey('companyId')) {
          await _monitorApiService.switchCompany(account.userData['companyId']);
        }

        // Refresh user data in controller
        await refreshUserDataFromAccount(account);

        // Navigate to monitor app
        Get.offAll(() => const MonitorAppRoot());
      } else {
        // Store POS user data
        await _posApiService.saveAuthDataFromMap(account.userData);

        // Refresh user data in controller
        await refreshUserDataFromAccount(account);

        // Navigate to POS app
        Get.offAll(() => const PosAppRoot());
      }
    } catch (e) {
      errorMessage.value = 'Failed to switch account: $e';
      print('ProfileController: Error switching account: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveCurrentUserAsAccount() async {
    try {
      final currentAccount = _accountManager.currentAccount.value;
      final userData = await _getCurrentUserData();

      if (userData != null) {
        final username = userData['username'] ?? 'Unknown';
        final system = currentSystem.value;

        // Check if an account with the same username and system already exists
        final existingAccount = _accountManager.accounts.firstWhereOrNull(
          (account) => account.username == username && account.system == system
        );

        final account = UserAccount(
          id: existingAccount?.id ?? currentAccount?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          username: username,
          system: system,
          userData: userData,
          lastLogin: DateTime.now(),
        );

        await _accountManager.addAccount(account);
        await _accountManager.setCurrentAccount(account);
      }
    } catch (e) {
      print('Error saving current user as account: $e');
    }
  }

  Future<Map<String, dynamic>?> _getCurrentUserData() async {
    if (currentSystem.value == 'monitor') {
      return await _monitorApiService.getStoredUserData();
    } else {
      return await _posApiService.getStoredUserData();
    }
  }

  List<UserAccount> getAvailableAccounts() {
    return _accountManager.getAdminAccountsForSwitch(system: currentSystem.value);
  }

  String get userName => userData['username'] ?? 'Unknown User';
  String get userEmail => userData['username'] ?? ''; // Using username as email for now
  String get userRole => _getUserRole();
  String get companyName => companyData['activeBranchName'] ?? companyData['company'] ?? 'Unknown Company';
  String get companyAddress => companyData['activeBranchAddress'] ?? '';
  String get companyEmail => companyData['activeBranchPrimaryEmail'] ?? '';
  String get companyCode => companyData['activeBranchCode'] ?? '';
  String get userInitial => userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

  String _getUserRole() {
    final roles = userData['roles'] as List<dynamic>?;
    if (roles != null && roles.isNotEmpty) {
      return roles.first.toString();
    }
    return 'User';
  }
}