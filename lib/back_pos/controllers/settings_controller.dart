import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/settings_service.dart';
import '../database/db_helper.dart';

class SettingsController extends GetxController {
  final SettingsService _settingsService = SettingsService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
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
      final password = int.tryParse(passwordController.text);
      if (password == null) {
        Get.snackbar('Error', 'Invalid password format');
        return false;
      }

      // Authenticate user locally using username and pospassword
      final user = await _dbHelper.authenticateUserByUsername(
        usernameController.text,
        password,
      );

      if (user != null) {
        // Check if user has admin or supervisor role
        final userRole = user.role.toLowerCase() ?? '';
        if (userRole.contains('admin') || userRole.contains('supervisor')) {
          return true;
        } else {
          Get.snackbar('Error', 'User does not have supervisor or admin privileges');
          return false;
        }
      } else {
        Get.snackbar('Error', 'Invalid username or password');
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