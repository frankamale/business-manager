import 'package:get/get.dart';
import '../database/db_helper.dart';
import '../services/api_services.dart';
import '../models/users.dart';
import '../utils/network_helper.dart';

class AuthController extends GetxController {
  final _dbHelper = DatabaseHelper();
  final _apiService = ApiService();

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
    // Don't load on init - will be handled by splash screen
  }

  // Load all user roles from database (including duplicates)
  Future<void> loadUserRoles() async {
    try {
      isLoadingRoles.value = true;
      final roles = await _dbHelper.getAllRoles();
      userRoles.value = roles;
      isLoadingRoles.value = false;
    } catch (e) {
      isLoadingRoles.value = false;
      Get.snackbar(
        'Info',
        'Failed to initialise, please restart the app',
        snackPosition: SnackPosition.BOTTOM,
      );
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

      // Save users to database
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

  /// Logout closes the current company's database and clears the user session.
  /// This prevents access to the previous company's data and prepares for a new login.
  Future<void> logout() async {
    await DatabaseHelper.instance.close();
    currentUser.value = null;
  }

  /// Server login authenticates with the server, fetches company info, and opens the per-company database.
  /// This sets the database context for the logged-in company, ensuring all operations use the correct isolated database.
  /// Example: After successful server authentication, the company's database is opened, preventing data leakage between companies.
  Future<bool> serverLogin(String username, String password) async {
    try {
      isLoggingIn.value = true;

      // Authenticate with server
      await _apiService.adminSignIn(username, password);

      // Store server credentials
      await _apiService.saveServerCredentials(username, password);

      // Fetch and store company info
      await _apiService.fetchAndStoreCompanyInfo();

      // Get company info
      final companyInfo = await _apiService.getCompanyInfo();
      final companyId = companyInfo['companyId']!;

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