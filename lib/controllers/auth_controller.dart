import 'package:get/get.dart';
import '../database/db_helper.dart';
import '../services/api_services.dart';
import '../models/users.dart';

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
    loadUserRoles();
  }

  // Load all user roles from database (including duplicates)
  Future<void> loadUserRoles() async {
    try {
      print('📋 Loading user roles from database...');
      isLoadingRoles.value = true;
      final roles = await _dbHelper.getAllRoles();
      userRoles.value = roles;
      isLoadingRoles.value = false;

      print('Successfully loaded ${roles.length} roles from database:');
      for (var i = 0; i < roles.length; i++) {
        print('   ${i + 1}. ${roles[i]}');
      }
    } catch (e) {
      isLoadingRoles.value = false;
      print('Error loading roles from database: $e');
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
      print('Fetching users with role: $role');
      final users = await _dbHelper.getUsersByRole(role);
      for (var user in users) {
        print('   - ${user.name} (${user.username})');
      }
    } catch (e) {
      print(' Error fetching users by role: $e');
    }
  }

  // Get all users
  Future<void> getAllUsers() async {
    try {
      final users = await _dbHelper.users;
      for (var user in users) {
      }
    } catch (e) {
      print('Error fetching all users: $e');
    }
  }

  // Sync users from API to local database
  Future<void> syncUsersFromAPI() async {
    try {
      isSyncingUsers.value = true;

      // Fetch users from API
      final users = await _apiService.fetchUsers();

      // Save users to database
      print('Saving ${users.length} users to local database...');
      await _dbHelper.insertUsers(users);

      print('Successfully synced ${users.length} users to database');

      // Reload roles after sync
      await loadUserRoles();

      isSyncingUsers.value = false;


    } catch (e) {
      isSyncingUsers.value = false;
      print('Error syncing users from API: $e');

    }
  }

  // Login user with username and password
  Future<bool> login(String username, String password) async {
    try {
      print(' Attempting login with username: $username');
      isLoggingIn.value = true;

      // Convert password to integer
      final int? passwordInt = int.tryParse(password);
      if (passwordInt == null) {
        print('Invalid password format. Password must be a number');
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
        print('Login failed - Invalid username or password');
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
      print('Login successful! Welcome ${user.name}');
      print('   Role: ${user.role}');
      print('   Username: ${user.username}');
      print('   Branch: ${user.branchname}');
      print('   Company: ${user.companyName}');

      Get.snackbar(
        'Login Successful',
        'Welcome ${user.name}!',
        snackPosition: SnackPosition.BOTTOM,
      );

      isLoggingIn.value = false;
      return true;
    } catch (e) {
      print('Login error: $e');
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
      print('Found ${users.length} salespeople');
      return users;
    } catch (e) {
      print('Error fetching salespeople: $e');
      return [];
    }
  }

  // Logout user
  void logout() {
    currentUser.value = null;
    print('User logged out');
  }
}