import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/settings_service.dart';
import '../../services/api_services.dart';

class SettingsController extends GetxController {
  final SettingsService _settingsService = SettingsService();
  final ApiService _apiService = Get.find<ApiService>();
  RxBool autoUploadEnabled = false.obs;
  RxBool paymentAccessForAllUsers = false.obs;
  RxBool priceEditingEnabled = false.obs;

  // Text controllers for authentication
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    autoUploadEnabled.value = _settingsService.getAutoUploadEnabled();
    paymentAccessForAllUsers.value = _settingsService.getPaymentAccessForAllUsers();
    priceEditingEnabled.value = _settingsService.getPriceEditingEnabled();
  }

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<bool> authenticate() async {
    try {
      final authResponse = await _apiService.adminSignIn(
        usernameController.text,
        passwordController.text,
      );
      if (authResponse.roles.contains('ADMIN')) {
        return true;
      } else {
        Get.snackbar('Error', 'Not an admin user');
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Authentication failed: $e');
      return false;
    }
  }

  Future<bool> showAuthDialog() async {
    return await Get.dialog<bool>(
      AlertDialog(
        title: Text('Admin Authentication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              bool success = await authenticate();
              if (success) {
                Get.back(result: true);
              }
            },
            child: Text('Authenticate'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> toggleAutoUpload(bool value) async {
    bool authenticated = await showAuthDialog();
    if (authenticated) {
      autoUploadEnabled.value = value;
      _settingsService.setAutoUploadEnabled(value);
      Get.snackbar('Settings', 'Auto upload ${value ? 'enabled' : 'disabled'}');
    }
  }

  Future<void> togglePaymentAccessForAllUsers(bool value) async {
    bool authenticated = await showAuthDialog();
    if (authenticated) {
      paymentAccessForAllUsers.value = value;
      _settingsService.setPaymentAccessForAllUsers(value);
      Get.snackbar('Settings', 'Payment access for all users ${value ? 'enabled' : 'disabled'}');
    }
  }

  Future<void> togglePriceEditing(bool value) async {
    bool authenticated = await showAuthDialog();
    if (authenticated) {
      priceEditingEnabled.value = value;
      _settingsService.setPriceEditingEnabled(value);
      Get.snackbar('Settings', 'Price editing ${value ? 'enabled' : 'disabled'}');
    }
  }
}