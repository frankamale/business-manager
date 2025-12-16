import 'package:get/get.dart';
import 'package:bac_pos/back_pos/database/db_helper.dart';
import 'package:bac_pos/back_pos/services/api_services.dart';
import 'package:bac_pos/back_pos/models/users.dart';
import 'package:bac_pos/back_pos/utils/network_helper.dart';
import '../../bac_monitor/lib/services/account_manager.dart';

class AuthController extends GetxController {
   final _dbHelper = DatabaseHelper();
   final _apiService = PosApiService();
   final AccountManager _accountManager = Get.find();

  // Reactive list of user roles
  var userRoles = <String>[].obs;

  // Current logged in user
  var currentUser = Rxn<User>();

  // Loading state
  var isLoadingRoles = false.obs;
  var isSyncingUsers = false.obs;
  var isLoggingIn = false.obs;

  @override
  void onInit() {
    super.onInit();
  }

  // Load all user roles from database (including duplicates)
  Future<void> loadUserRoles() async {
    try {
      isLoadingRoles.value = true;
      final roles = await _dbHelper.getAllRoles();
      userRoles.value = roles;
      isLoadingRoles.value = false;
      print(userRoles);
    } catch (e) {
      isLoadingRoles.value = false;
    }
  }

  // Get users by role
  Future<void> getUsersByRole(String role) async {
    try {
      final users = await _dbHelper.getUsersByRole(role);
    } catch (e) {
      // Handle error silently
    }
  }

  // Get all users
  Future<void> getAllUsers() async {
    try {
      final users = await _dbHelper.users;
    } catch (e) {
      // Handle error silently
    }
  }

  // Load users from cache without API call
  Future<void> loadUsersFromCache() async {
    try {
      final cachedUsers = await _dbHelper.users;
      await loadUserRoles();
    } catch (e) {
      // Handle error silently
    }
  }

  // Sync users from API to local database
  Future<void> syncUsersFromAPI({bool showMessage = false}) async {
    try {
      isSyncingUsers.value = true;

      // Fetch users from API
      final users = await _apiService.fetchUsers();

      await _dbHelper.insertUsers(users);

      // Update sync metadata
      await _dbHelper.updateSyncMetadata('users', 'success', users.length);

      // Reload roles after sync
      await loadUserRoles();

      isSyncingUsers.value = false;

      if (showMessage) {
        Get.snackbar(
          'Success', "Operation successful",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      isSyncingUsers.value = false;
      await _dbHelper.updateSyncMetadata('users', 'failed', 0, e.toString());

      if (showMessage) {
        Get.snackbar(
          'Error',
          'Failed to refresh users',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  // Refresh users (pull-to-refresh)
  Future<void> refreshUsers() async {
    final hasNetwork = await NetworkHelper.hasConnection();
    if (!hasNetwork) {
      Get.snackbar(
        'Offline',
        'Cannot refresh without internet connection',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    await syncUsersFromAPI(showMessage: true);
  }

  // Login user with username and password
  Future<bool> login(String username, String password) async {
    try {
      isLoggingIn.value = true;

      // Convert password to integer
      final int? passwordInt = int.tryParse(password);
      if (passwordInt == null) {
        Get.snackbar(
          'Invalid Password',
          'Password must be a number',
          snackPosition: SnackPosition.BOTTOM,
        );
        isLoggingIn.value = false;
        return false;
      }

      // Authenticate user by username and password
      final user = await _dbHelper.authenticateUserByUsername(username, passwordInt);

      if (user == null) {
        Get.snackbar(
          'Login Failed',
          'Invalid username or password',
          snackPosition: SnackPosition.BOTTOM,
        );
        isLoggingIn.value = false;
        return false;
      }

      // Set current user
      currentUser.value = user;

      isLoggingIn.value = false;
      return true;
    } catch (e) {
      Get.snackbar(
        'Login Error',
        'An error occurred during login',
        snackPosition: SnackPosition.BOTTOM,
      );
      isLoggingIn.value = false;
      return false;
    }
  }

  // Get salespeople (users with salespersonid)
  Future<List<User>> getSalespeople() async {
    try {
      final users = await _dbHelper.getUsersWithSalespersonId();
      return users;
    } catch (e) {
      return [];
    }
  }

  Future<void> logout() async {
    currentUser.value = null;
  }

 Future<bool> serverLogin(String username, String password, {bool closeDatabase = true}) async {
    try {
      String usernameLower = username.toLowerCase();
      isLoggingIn.value = true;
      
      // Only close the database if explicitly requested (for new authentication)
      if (closeDatabase) {
        await DatabaseHelper.instance.close();
      }

      // Authenticate with server
      await _apiService.adminSignIn(usernameLower, password);

      // Store server credentials
      await _apiService.saveServerCredentials(usernameLower, password);

      // Fetch and store company info
      await _apiService.fetchAndStoreCompanyInfo();

      // Get company info
      final companyInfo = await _apiService.getCompanyInfo();
      final companyId = companyInfo['companyId']!;

      // Save the current account in AccountManager
      final token = await _apiService.getAccessToken();
      final userData = await _apiService.getStoredUserData() ?? {};
      final credentials = await _apiService.getServerCredentials();

      final account = UserAccount(
        id: companyId,
        username: usernameLower,
        system: 'pos',
        userData: {
          ...userData,
          'token': token,
          'credentials': {
            'username': credentials['username'],
            'password': credentials['password'],
          },
        },
        lastLogin: DateTime.now(),
      );

      await _accountManager.addAccount(account);
      await _accountManager.setCurrentAccount(account);

      // Open database for company
      await _dbHelper.openForCompany(companyId);

      isLoggingIn.value = false;
      return true;
    } catch (e) {
      Get.snackbar(
        'Server Login Failed',
        'Invalid server credentials',
        snackPosition: SnackPosition.BOTTOM,
      );
      isLoggingIn.value = false;
      return false;
    }
  }
}