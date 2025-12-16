import 'package:get/get.dart';
import '../../../back_pos/services/api_services.dart';
import '../../../initialise/app_roots.dart';
import '../services/api_services.dart';
import '../services/account_manager.dart';

class ProfileController extends GetxController {
  final MonitorApiService _monitorApiService = Get.find();
  final PosApiService _posApiService = Get.find();
  final AccountManager _accountManager = Get.find();

  // Make accountManager accessible for the UI
  AccountManager get accountManager => _accountManager;

  var isLoading = false.obs;
  var userData = <String, dynamic>{}.obs;
  var companyData = <String, dynamic>{}.obs;
  var errorMessage = ''.obs;
  var currentSystem = 'monitor'.obs; // 'monitor' or 'pos'

  @override
  void onInit() {
    super.onInit();
    // Determine current system based on current account
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

      // Load company data
      final company = await _posApiService.fetchAndStoreCompanyInfo();
      companyData.value = company;

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

      // Remove current account from account manager
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
        final account = UserAccount(
          id: currentAccount?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          username: userData['username'] ?? 'Unknown',
          system: currentSystem.value,
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
  String get companyName => companyData['companyName'] ?? companyData['company'] ?? 'Unknown Company';
  String get userInitial => userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

  String _getUserRole() {
    final roles = userData['roles'] as List<dynamic>?;
    if (roles != null && roles.isNotEmpty) {
      return roles.first.toString();
    }
    return 'User';
  }
}