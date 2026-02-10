import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../shared/services/customer_auth_service.dart';
import '../services/client_api_service.dart';

class ResetPasscodeController extends GetxController {
  final ClientApiService _apiService = ClientApiService();
  final CustomerAuthService _customerAuthService = CustomerAuthService();

  final oldPasscodeController = TextEditingController();
  final newPasscodeController = TextEditingController();
  final confirmPasscodeController = TextEditingController();

  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var obscureOld = true.obs;
  var obscureNew = true.obs;
  var obscureConfirm = true.obs;

  @override
  void onClose() {
    oldPasscodeController.dispose();
    newPasscodeController.dispose();
    confirmPasscodeController.dispose();
    super.onClose();
  }

  Future<bool> resetPasscode() async {
    final oldPasscode = oldPasscodeController.text;
    final newPasscode = newPasscodeController.text;
    final confirmPasscode = confirmPasscodeController.text;

    // Validation
    if (oldPasscode.isEmpty) {
      errorMessage.value = 'Please enter your current passcode';
      return false;
    }

    if (newPasscode.isEmpty) {
      errorMessage.value = 'Please enter a new passcode';
      return false;
    }

    if (newPasscode.length < 4) {
      errorMessage.value = 'New passcode must be at least 4 digits';
      return false;
    }

    if (!RegExp(r'^\d+$').hasMatch(newPasscode)) {
      errorMessage.value = 'Passcode must contain only numbers';
      return false;
    }

    if (newPasscode != confirmPasscode) {
      errorMessage.value = 'New passcodes do not match';
      return false;
    }

    if (oldPasscode == newPasscode) {
      errorMessage.value = 'New passcode must be different from current passcode';
      return false;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      // Get logged in customer data
      final box = GetStorage();
      final customerData = box.read('logged_in_customer');

      if (customerData == null) {
        throw Exception('Not logged in');
      }

      final customerId = customerData['id'];
      final storedHash = customerData['pospassword'];

      // Verify old passcode using bcrypt
      if (storedHash == null || storedHash.isEmpty) {
        throw Exception('Unable to verify current passcode');
      }

      if (!BCrypt.checkpw(oldPasscode, storedHash)) {
        errorMessage.value = 'Current passcode is incorrect';
        isLoading.value = false;
        return false;
      }

      // Call API to reset password
      await _apiService.resetPassword(
        userId: customerId,
        newPassword: newPasscode,
        subject: 'password reset',
      );

      // Update local storage with new password hash
      final newHash = BCrypt.hashpw(newPasscode, BCrypt.gensalt());
      customerData['pospassword'] = newHash;
      await box.write('logged_in_customer', customerData);

      // Update cached customer account
      final identifier = customerData['email'] ??
          customerData['phone1'] ??
          customerData['posusername'] ??
          '';
      if (identifier.isNotEmpty) {
        await _customerAuthService.updateCachedCustomerPassword(
          identifier: identifier,
          newPassword: newPasscode,
        );
      }

      // Clear fields
      oldPasscodeController.clear();
      newPasscodeController.clear();
      confirmPasscodeController.clear();

      Get.snackbar(
        'Success',
        'Your passcode has been updated successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
      );

      return true;
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
