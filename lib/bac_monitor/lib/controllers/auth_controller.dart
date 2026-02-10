import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/database/unified_db_helper.dart';
import '../pages/bottom_nav.dart';
import '../services/api_services.dart';
import '../services/account_manager.dart';

class LoginController extends GetxController {
  final MonitorApiService _apiService = Get.find();
  final _dbHelper = UnifiedDatabaseHelper.instance;
  final AccountManager _accountManager = Get.find();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var isPasswordVisible = false.obs;

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  Future<void> performLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      errorMessage.value = 'Please enter both email and password.';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      // First, perform the login
      await _apiService.login(emailController.text, passwordController.text);

      // After successful login, fetch and store the company ID
      try {
        final companyId = await _apiService.cachedCompanyId;
        debugPrint("LoginController: Successfully fetched and stored company ID: $companyId");

        // Switch to the new company's database
        await _dbHelper.switchCompany(companyId!);
        debugPrint("LoginController: Successfully switched to company database: $companyId");

        // Save the current account in AccountManager
        final token = await _apiService.getStoredToken();
        final userData = await _apiService.getStoredUserData() ?? {};

        if (userData.containsKey('roles') && userData['roles'] is List && userData['roles'].isNotEmpty) {
          final userRole = userData['roles'].first.toString();
          await _apiService.secureStorage.write(key: 'user_role', value: userRole);
          debugPrint("LoginController: Successfully stored user role: $userRole");
        }

        final account = UserAccount(
          id: companyId,
          username: emailController.text,
          system: 'monitor',
          userData: {
            ...userData,
            'token': token,
            'credentials': {
              'username': emailController.text,
              'password': passwordController.text,
            },
          },
          lastLogin: DateTime.now(),
        );

        await _accountManager.addAccount(account);
        await _accountManager.setCurrentAccount(account);
        debugPrint("LoginController: Successfully saved account for company: $companyId");

      } catch (e) {
        debugPrint("LoginController: Failed to fetch company ID after login: $e");
        // Don't fail the entire login process if company ID fetch fails
      }

      emailController.dispose();
      passwordController.dispose();
      Get.offAll(() => const BottomNav());

    } catch (e) {
      errorMessage.value =
          'Login Failed: Invalid credentials or network error.';
      debugPrint("Login error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    super.onClose();
  }
}
