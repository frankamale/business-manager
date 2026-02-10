import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared/services/customer_auth_service.dart';
import '../services/client_api_service.dart';

class PasswordRecoveryController extends GetxController {
  final ClientApiService _apiService = ClientApiService();
  final CustomerAuthService _customerAuthService = CustomerAuthService();

  final identifierController = TextEditingController();
  final challengeCodeController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  var isLoading = false.obs;
  var isCodeSent = false.obs;
  var isCodeVerified = false.obs;
  var errorMessage = ''.obs;

  // Current step: 0 = enter identifier, 1 = verify code, 2 = set password
  var currentStep = 0.obs;

  String _generatedCode = '';
  String _userId = '';
  String _fullName = '';
  String _email = '';

  @override
  void onClose() {
    identifierController.dispose();
    challengeCodeController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  String _generateRandomCode() {
    final random = Random();
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const digits = '0123456789';

    String letterPart =
        List.generate(3, (_) => letters[random.nextInt(letters.length)]).join();
    String numberPart =
        List.generate(6, (_) => digits[random.nextInt(digits.length)]).join();

    return '$letterPart-$numberPart';
  }

  /// Step 1: Look up the account and send challenge code
  Future<bool> lookupAndSendCode() async {
    final identifier = identifierController.text.trim();

    if (identifier.isEmpty) {
      errorMessage.value = 'Please enter your email or phone number';
      return false;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      // Check if bot credentials are configured
      if (!await _customerAuthService.hasBotCredentials()) {
        throw Exception(
          'Service not configured. Please contact administrator.',
        );
      }

      // Get bot token and fetch customers
      final botToken = await _customerAuthService.getBotToken();
      final customers = await _customerAuthService.fetchCustomers(botToken);

      // Find customer by email or phone
      final customer = _customerAuthService.findCustomerByIdentifier(
        customers,
        identifier,
      );

      if (customer == null) {
        throw Exception('No account found with this email or phone number');
      }

      // Store customer info for later use
      _userId = customer.id;
      _fullName = customer.fullnames ?? '${customer.firstname} ${customer.lastname}';
      _email = customer.email ?? '';

      // Check if we have an email to send code to
      if (_email.isEmpty) {
        throw Exception('No email associated with this account. Please contact support.');
      }

      // Generate and send challenge code
      _generatedCode = _generateRandomCode();

      // Prefill the input with the letter prefix (e.g., "ABC-")
      final prefix = _generatedCode.substring(0, 4);
      challengeCodeController.text = prefix;

      await _apiService.sendChallengeCode(
        email: _email,
        fullName: _fullName,
        code: _generatedCode,
        userId: _userId,
        subject: 'Account Verification',
      );

      isCodeSent.value = true;
      currentStep.value = 1;

      Get.snackbar(
        'Code Sent',
        'A verification code has been sent to $_email',
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

  /// Step 2: Verify the challenge code
  bool verifyChallengeCode() {
    final enteredCode = challengeCodeController.text.trim().toUpperCase();

    if (enteredCode.isEmpty) {
      errorMessage.value = 'Please enter the verification code';
      return false;
    }

    if (enteredCode != _generatedCode) {
      errorMessage.value = 'Invalid verification code';
      return false;
    }

    isCodeVerified.value = true;
    currentStep.value = 2;
    errorMessage.value = '';

    return true;
  }

  /// Step 3: Reset the password
  Future<bool> resetPassword() async {
    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;

    // Validation
    if (newPassword.isEmpty) {
      errorMessage.value = 'Please enter a new passcode';
      return false;
    }

    if (newPassword.length < 4) {
      errorMessage.value = 'Passcode must be at least 4 digits';
      return false;
    }

    if (!RegExp(r'^\d+$').hasMatch(newPassword)) {
      errorMessage.value = 'Passcode must contain only numbers';
      return false;
    }

    if (newPassword != confirmPassword) {
      errorMessage.value = 'Passcodes do not match';
      return false;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _apiService.resetPassword(
        userId: _userId,
        newPassword: newPassword,
        subject: 'password reset',
      );

      // Update cached customer password if exists
      final identifier = identifierController.text.trim();
      if (identifier.isNotEmpty) {
        await _customerAuthService.updateCachedCustomerPassword(
          identifier: identifier,
          newPassword: newPassword,
        );
      }

      Get.snackbar(
        'Success',
        'Your passcode has been reset successfully',
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

  /// Go back to previous step
  void goBack() {
    if (currentStep.value > 0) {
      currentStep.value--;
      errorMessage.value = '';
    }
  }

  /// Reset the controller state
  void resetState() {
    identifierController.clear();
    challengeCodeController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();
    _generatedCode = '';
    _userId = '';
    _fullName = '';
    _email = '';
    isCodeSent.value = false;
    isCodeVerified.value = false;
    currentStep.value = 0;
    errorMessage.value = '';
  }
}
