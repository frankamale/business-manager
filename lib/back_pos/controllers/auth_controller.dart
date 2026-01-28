import 'package:get/get.dart';
import 'package:bac_pos/shared/database/unified_db_helper.dart';
import 'package:bac_pos/back_pos/services/api_services.dart';
import 'package:bac_pos/back_pos/models/users.dart';
import 'package:bac_pos/back_pos/models/auth_response.dart';
import 'package:bac_pos/back_pos/utils/network_helper.dart';
import '../../bac_monitor/lib/services/account_manager.dart';

class AuthController extends GetxController {
   final _dbHelper = UnifiedDatabaseHelper.instance;
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

 /// Server login that handles database switching for company-specific data
  /// Returns login result with user data, or null on failure
  /// closeDatabase: if true, closes any existing database before opening the new company's database
  Future<Map<String, dynamic>?> serverLogin(String username, String password, {bool closeDatabase = true}) async {
    try {
      String usernameLower = username.toLowerCase();
      isLoggingIn.value = true;
      print('DEBUG: AuthController.serverLogin() - Starting login for: $usernameLower');

      // Close the existing database before new authentication (non-blocking if possible)
      if (closeDatabase) {
        print('DEBUG: AuthController.serverLogin() - Closing existing database');
        UnifiedDatabaseHelper.instance.close(); // Don't await - can run in background
      }

      // Authenticate with server
      print('DEBUG: AuthController.serverLogin() - Authenticating with server');
      final authResponse = await _apiService.adminSignIn(usernameLower, password);

      // Save credentials in background (fire-and-forget)
      _apiService.saveServerCredentials(usernameLower, password);

      // Fetch company info (we need this)
      print('DEBUG: AuthController.serverLogin() - Fetching company info');
      await _apiService.fetchAndStoreCompanyInfo();

      // Get company info
      final companyInfo = await _apiService.getCompanyInfo();
      final companyId = companyInfo['companyId']!;
      print('DEBUG: AuthController.serverLogin() - Got company ID: $companyId');

      // Open database for the new company
      print('DEBUG: AuthController.serverLogin() - Opening database for company: $companyId');
      await _dbHelper.openForCompany(companyId);

      // Build user data from auth response (no need to re-read from storage)
      final userData = {
        'userId': authResponse.id,
        'username': authResponse.username,
        'roles': authResponse.roles,
        'accessToken': authResponse.accessToken,
      };

      final account = UserAccount(
        id: companyId,
        username: usernameLower,
        system: 'pos',
        userData: {
          ...userData,
          'companyId': companyId,
          'token': authResponse.accessToken,
          'credentials': {
            'username': usernameLower,
            'password': password,
          },
        },
        lastLogin: DateTime.now(),
      );

      // Set current account in background (fire-and-forget for navigation speed)
      _accountManager.setCurrentAccount(account);

      print('DEBUG: AuthController.serverLogin() - Login successful for company: $companyId');
      isLoggingIn.value = false;

      // Return all data needed by caller so they don't need to re-read
      return {
        'companyId': companyId,
        'token': authResponse.accessToken,
        'userData': userData,
        'username': usernameLower,
        'password': password,
      };
    } catch (e) {
      print('ERROR: AuthController.serverLogin() - Login failed: $e');
      final errorString = e.toString();
      // Check if error is due to invalid credentials (401)
      if (errorString.contains('401')) {
        Get.snackbar(
          'Server Login Failed',
          'Invalid server credentials',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        // Network error or server unreachable
        Get.snackbar(
          'Connection Error',
          'Please connect to mobile network',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      isLoggingIn.value = false;
      return null;
    }
  }
}