import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'package:get/get.dart';
import '../../../back_pos/services/api_services.dart';
import '../../../initialise/app_roots.dart';
import '../services/api_services.dart';
import '../services/account_manager.dart';
import '../../../shared/database/unified_db_helper.dart';

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
    // Try to load profile data if database is ready
    _tryLoadProfileData();

    // Listen to account changes and refresh data accordingly
    ever(_accountManager.currentAccount, (UserAccount? account) {
      if (account != null) {
        currentSystem.value = account.system;
        refreshUserDataFromAccount(account);
      }
    });
  }

  /// Try to load profile data if database is ready
  Future<void> _tryLoadProfileData() async {
    final dbHelper = UnifiedDatabaseHelper.instance;
    if (dbHelper.isDatabaseOpen) {
      await loadProfileData();
    } else {
      // Still load user data - prioritize current account's userData
      try {
        final currentAccount = _accountManager.currentAccount.value;
        if (currentAccount != null && currentAccount.userData.isNotEmpty) {
          userData.value = currentAccount.userData;
          print('ProfileController: Loaded user data from current account (db not open)');
        } else {
          final user = await _posApiService.getStoredUserData();
          if (user != null) {
            userData.value = user;
            print('ProfileController: Loaded user data from storage (db not open)');
          }
        }
      } catch (e) {
        print('ProfileController: Error loading user data: $e');
      }
      print('ProfileController: Database not open yet, skipping company data load');
    }
  }

  Future<void> loadProfileData() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // PRIORITY: Use current account's userData if available (most reliable source)
      final currentAccount = _accountManager.currentAccount.value;
      if (currentAccount != null && currentAccount.userData.isNotEmpty) {
        userData.value = currentAccount.userData;
        print('ProfileController: Loaded user data from current account: ${currentAccount.username}');
      } else {
        // Fallback: Load user data from storage
        final user = await _posApiService.getStoredUserData();
        if (user != null) {
          userData.value = user;
          print('ProfileController: Loaded user data from storage');
        }
      }

      // Load company data from database (needs database)
      final dbHelper = UnifiedDatabaseHelper.instance;
      if (dbHelper.isDatabaseOpen) {
        final company = await dbHelper.getCompanyDetails();
        if (company != null) {
          companyData.value = company;
          print('ProfileController: Loaded company data from database');
        }
      } else {
        print('ProfileController: Database not open, skipping company data');
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

      // ALWAYS use the account's userData - this is the source of truth
      if (account.userData.isNotEmpty) {
        userData.value = account.userData;
        print('ProfileController: refreshUserDataFromAccount - Using account userData for: ${account.username}');
      } else {
        // Only fallback to storage if account userData is truly empty
        print('ProfileController: refreshUserDataFromAccount - Account userData is empty, falling back to storage');
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

      // Load company data from database (only if database is open)
      final dbHelper = UnifiedDatabaseHelper.instance;
      if (dbHelper.isDatabaseOpen) {
        final company = await dbHelper.getCompanyDetails();
        if (company != null) {
          companyData.value = company;
          print('ProfileController: refreshUserDataFromAccount - Loaded company data from database');
        }
      } else {
        print('ProfileController: refreshUserDataFromAccount - Database not open, skipping company data');
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
      print('DEBUG: ProfileController.signOut() - Starting sign out');

      // Clear current account first
      final currentAccount = _accountManager.currentAccount.value;
      if (currentAccount != null) {
        await _accountManager.setCurrentAccount(null);
      }

      // Clear auth data from POS service (doesn't close database)
      await _posApiService.clearAuthData();
      print('DEBUG: ProfileController.signOut() - POS auth data cleared');

      // Monitor logout closes database and clears all state
      await _monitorApiService.logout();
      print('DEBUG: ProfileController.signOut() - Monitor logout completed (database closed)');

      // Navigate to login
      Get.offAll(() => const UnifiedLoginScreen());
    } catch (e) {
      errorMessage.value = 'Failed to sign out: $e';
      print('ERROR: ProfileController.signOut() - Error signing out: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> switchSystem(String system) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      print('DEBUG: ProfileController.switchSystem() - Switching to system: $system');

      currentSystem.value = system;

      // Get admin accounts for the target system
      final systemAccounts = _accountManager.getAdminAccountsForSwitch(system: system);

      if (systemAccounts.isNotEmpty) {
        // Switch to the most recently used account for this system
        print('DEBUG: ProfileController.switchSystem() - Found existing account, using switchToAccount');
        await switchToAccount(systemAccounts.first);
      } else {
        // No accounts for this system - ensure database is open before navigation
        print('DEBUG: ProfileController.switchSystem() - No existing account, opening database manually');

        final dbHelper = UnifiedDatabaseHelper.instance;
        String? companyId;

        // Try to find companyId from various sources
        final currentAccount = _accountManager.currentAccount.value;
        if (currentAccount != null && currentAccount.userData.containsKey('companyId')) {
          companyId = currentAccount.userData['companyId']?.toString();
        }

        if (companyId == null || companyId.isEmpty) {
          companyId = await _monitorApiService.getStoredCompanyId();
        }

        if (companyId == null || companyId.isEmpty) {
          final companyInfo = await _posApiService.getCompanyInfo();
          companyId = companyInfo['companyId'];
        }

        // Ensure database is open
        if (companyId != null && companyId.isNotEmpty) {
          print('DEBUG: ProfileController.switchSystem() - Opening database for company: $companyId');
          await dbHelper.openForCompany(companyId);

          // Store companyId for the target system
          if (system == 'pos') {
            await _posApiService.saveCompanyInfo({'company': companyId, 'branch': '', 'sellingPointId': ''});
          } else {
            await _monitorApiService.storeCompanyId(companyId);
          }
        } else {
          print('WARNING: ProfileController.switchSystem() - No companyId found!');
        }

        // Navigate to the appropriate app
        if (system == 'pos') {
          Get.offAll(() => const PosAppRoot());
        } else {
          Get.offAll(() => const MonitorAppRoot());
        }
      }
    } catch (e) {
      errorMessage.value = 'Failed to switch system: $e';
      print('ERROR: ProfileController.switchSystem() - Error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> switchToAccount(UserAccount account) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      print('DEBUG: ProfileController.switchToAccount() - Switching to account: ${account.username} (${account.system})');

      final currentAccount = _accountManager.currentAccount.value;
      final dbHelper = UnifiedDatabaseHelper.instance;

      // Get companyId from the account we're switching to
      String? targetCompanyId = account.userData['companyId']?.toString();

      // If not in account userData, try other sources
      if (targetCompanyId == null || targetCompanyId.isEmpty) {
        targetCompanyId = await _monitorApiService.getStoredCompanyId();
        print('DEBUG: ProfileController.switchToAccount() - Got companyId from storage: $targetCompanyId');
      }

      if (targetCompanyId == null || targetCompanyId.isEmpty) {
        final companyInfo = await _posApiService.getCompanyInfo();
        targetCompanyId = companyInfo['companyId'];
        print('DEBUG: ProfileController.switchToAccount() - Got companyId from POS service: $targetCompanyId');
      }

      // If switching to a different account, handle logout first
      if (currentAccount != null && currentAccount.id != account.id) {
        print('DEBUG: ProfileController.switchToAccount() - Switching from different account, clearing old data');
        await _posApiService.clearAuthData();
        // Close database but don't clear all monitor state yet
        await dbHelper.close();
      }

      // Validate token and handle re-authentication if needed
      bool tokenValid = false;
      bool hasInternet = true;

      try {
        if (account.system == 'monitor') {
          await _monitorApiService.getWithAuth('/company/details');
        } else {
          await _posApiService.validateToken();
        }
        tokenValid = true;
      } catch (e) {
        if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
          tokenValid = false;
        } else {
          hasInternet = false;
          print('DEBUG: ProfileController.switchToAccount() - Offline mode detected');
        }
      }

      // Re-authenticate if needed and online
      if (!tokenValid && hasInternet) {
        print('DEBUG: ProfileController.switchToAccount() - Token invalid, re-authenticating');
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
            print('DEBUG: ProfileController.switchToAccount() - Re-authentication successful');
          }
        } catch (e) {
          print('DEBUG: ProfileController.switchToAccount() - Re-auth failed, continuing offline: $e');
        }
      }

      // CRITICAL: Ensure database is open for the target company
      if (targetCompanyId != null && targetCompanyId.isNotEmpty) {
        print('DEBUG: ProfileController.switchToAccount() - Opening database for company: $targetCompanyId');
        await dbHelper.openForCompany(targetCompanyId);

        // Update the account userData to include companyId
        if (!account.userData.containsKey('companyId')) {
          account = UserAccount(
            id: account.id,
            username: account.username,
            system: account.system,
            userData: {...account.userData, 'companyId': targetCompanyId},
            lastLogin: account.lastLogin,
          );
        }
      } else {
        print('WARNING: ProfileController.switchToAccount() - No companyId found!');
      }

      // IMPORTANT: Store the account's data in the appropriate service BEFORE setting current account
      // This ensures the ever() listeners have access to the correct data
      if (account.system == 'monitor') {
        await _monitorApiService.storeUserData(account.userData);
        if (account.userData['accessToken'] != null) {
          await _monitorApiService.storeToken(account.userData['accessToken']);
        }
        if (account.userData.containsKey('roles') && account.userData['roles'] is List && (account.userData['roles'] as List).isNotEmpty) {
          await _monitorApiService.storeUserRole((account.userData['roles'] as List).first.toString());
        }
        if (targetCompanyId != null && targetCompanyId.isNotEmpty) {
          await _monitorApiService.storeCompanyId(targetCompanyId);
        }
      } else {
        await _posApiService.saveAuthDataFromMap(account.userData);
        if (targetCompanyId != null && targetCompanyId.isNotEmpty) {
          await _posApiService.saveCompanyInfo({'company': targetCompanyId, 'branch': '', 'sellingPointId': ''});
        }
      }

      // Now set the account as current (this triggers ever() listeners)
      await _accountManager.switchToAccount(account);
      currentSystem.value = account.system;

      // Update local state directly from account data (don't rely on storage)
      userData.value = account.userData;

      // Load company data from the now-open database
      final company = await dbHelper.getCompanyDetails();
      if (company != null) {
        companyData.value = company;
      }

      print('DEBUG: ProfileController.switchToAccount() - Switch complete, navigating to ${account.system}');

      // Navigate to the appropriate app
      if (account.system == 'monitor') {
        Get.offAll(() => const MonitorAppRoot());
      } else {
        Get.offAll(() => const PosAppRoot());
      }
    } catch (e) {
      errorMessage.value = 'Failed to switch account: $e';
      print('ERROR: ProfileController.switchToAccount() - Error switching account: $e');
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