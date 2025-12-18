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
      Get.offAllNamed('/login');
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

      // Get accounts for the target system
      final systemAccounts = _accountManager.getAccountsForSystem(system);

      if (systemAccounts.isNotEmpty) {
        // Switch to the most recently used account for this system
        await switchToAccount(systemAccounts.first);
      } else {
        // No accounts for this system, navigate to login for that system
        if (system == 'pos') {
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

      // If no internet, open DB using stored company ID
      if (!hasInternet) {
        if (account.system == 'monitor') {
          if (account.userData.containsKey('companyId')) {
            await _monitorApiService.switchCompany(account.userData['companyId']);
          }
        } else {
          final companyInfo = await _posApiService.getCompanyInfo();
          if (companyInfo['companyId']!.isNotEmpty) {
            await _posApiService.openDatabaseForCompany(companyInfo['companyId']!);
          }
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

        // Switch to monitor database
        if (account.userData.containsKey('companyId')) {
          await _monitorApiService.switchCompany(account.userData['companyId']);
        }

        // Navigate to monitor app
        Get.offAll(() => const MonitorAppRoot());
      } else {
        // Store POS user data
        await _posApiService.saveAuthDataFromMap(account.userData);

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
    return _accountManager.getAccountsForSystem(currentSystem.value);
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