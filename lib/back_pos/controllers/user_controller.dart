import 'package:get/get.dart';
import 'package:bac_pos/shared/database/unified_db_helper.dart';
import 'package:bac_pos/back_pos/models/users.dart';


class UserController extends GetxController {
  final _dbHelper = UnifiedDatabaseHelper.instance;

  // Reactive list of users
  var users = <User>[].obs;

  // Loading state
  var isLoading = false.obs;

  // Fetch users from local database
  Future<void> fetchUsers() async {
    try {
      isLoading(true);
      final data = await _dbHelper.users;
      users.assignAll(data);
    } catch (e) {
      print("Error fetching users: $e");
    } finally {
      isLoading(false);
    }
  }

  // Insert a new user
  Future<void> addUser(User user) async {
    try {
      await _dbHelper.insertUserModel(user);
      await fetchUsers(); // refresh list
    } catch (e) {
      print("Error inserting user: $e");
    }
  }

  // For clearing or refreshing manually
  void clearUsers() {
    users.clear();
  }
}
