import 'package:get/get.dart';
import '../../../back_pos/services/api_services.dart';
import '../services/api_services.dart';

class ProfileController extends GetxController {
  final MonitorApiService _monitorApiService = Get.find();
  final PosApiService _posApiService = Get.find();

  var isLoading = false.obs;
  var userData = <String, dynamic>{}.obs;
  var companyData = <String, dynamic>{}.obs;
  var errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
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

      // Navigate to login
      Get.offAllNamed('/login');
    } catch (e) {
      errorMessage.value = 'Failed to sign out: $e';
      print('ProfileController: Error signing out: $e');
    } finally {
      isLoading.value = false;
    }
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