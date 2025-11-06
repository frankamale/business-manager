import 'package:get/get.dart';
import '../database/db_helper.dart';
import '../services/api_services.dart';

class AuthController extends GetxController {
  final _dbHelper = DatabaseHelper();
  final _apiService = ApiService();

  // Reactive list of user roles
  var userRoles = <String>[].obs;

  // Loading state
  var isLoadingRoles = false.obs;
  var isSyncingUsers = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadUserRoles();
  }

  // Load unique user roles from database
  Future<void> loadUserRoles() async {
    try {
      print('📋 Loading user roles from database...');
      isLoadingRoles.value = true;
      final roles = await _dbHelper.getUniqueRoles();
      userRoles.value = roles;
      isLoadingRoles.value = false;

      print('Successfully loaded ${roles.length} unique roles from database:');
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
}