import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../db/db_helper.dart';
import '../pages/bottom_nav.dart';
import '../services/api_services.dart';

class LoginController extends GetxController {
  final ApiService _apiService = Get.find();
  final DatabaseHelper _dbHelper = DatabaseHelper();
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
        final companyId = await _apiService.fetchCompanyId();
        debugPrint("LoginController: Successfully fetched and stored company ID: $companyId");

        // Switch to the new company's database
        await _dbHelper.switchCompany(companyId);
        debugPrint("LoginController: Successfully switched to company database: $companyId");
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
