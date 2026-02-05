import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../services/client_api_service.dart';

class RegisterController extends GetxController {
  final ClientApiService _apiService = ClientApiService();

  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final tinController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final challengeCodeController = TextEditingController();

  var isLoading = false.obs;
  var isCodeSent = false.obs;
  var selectedGender = 'Male'.obs;
  var showAdvanced = false.obs;

  String _generatedCode = '';
  String _userId = '';

  @override
  void onClose() {
    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    emailController.dispose();
    tinController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    challengeCodeController.dispose();
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

  /// Validate fields before sending challenge code
  String? validateForChallengeCode() {
    if (nameController.text.trim().isEmpty) {
      return 'Please enter your full name';
    }
    if (emailController.text.trim().isEmpty) {
      return 'Please enter your email';
    }
     if (phoneController.text.trim().isEmpty) {
      return 'Please enter your phone number';
    }

    return null;
  }

  /// Generate and send challenge code to email
  Future<bool> generateChallengeCode() async {
    final validationError = validateForChallengeCode();
    if (validationError != null) {
      Get.snackbar('Validation Error', validationError,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    isLoading.value = true;

    try {
      _generatedCode = _generateRandomCode();
      _userId = const Uuid().v4();

      // Prefill the input with the letter prefix (e.g., "ABC-")
      final prefix = _generatedCode.substring(0, 4);
      challengeCodeController.text = prefix;

      await _apiService.sendChallengeCode(
        email: emailController.text.trim(),
        fullName: nameController.text.trim(),
        code: _generatedCode,
        userId: _userId,
      );

      isCodeSent.value = true;
      Get.snackbar('Success', 'Challenge code sent to your email',
          snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to send code: $e',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Verify the entered challenge code
  bool verifyChallengeCode() {
    final enteredCode = challengeCodeController.text.trim().toUpperCase();
    return enteredCode == _generatedCode;
  }

  /// Register the customer account
  Future<bool> registerAccount() async {
    if (!isCodeSent.value) {
      Get.snackbar('Error', 'Please get a challenge code first',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    if (!verifyChallengeCode()) {
      Get.snackbar('Error', 'Invalid challenge code',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    isLoading.value = true;

    try {
      // Split full name into first and last name
      final nameParts = nameController.text.trim().split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      await _apiService.createCustomer(
        id: _userId,
        firstName: firstName,
        lastName: lastName,
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        password: passwordController.text,
        gender: selectedGender.value,
      );

      Get.snackbar('Success', 'Account created successfully!',
          snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to create account: $e',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Clear all form fields
  void clearForm() {
    nameController.clear();
    addressController.clear();
    phoneController.clear();
    emailController.clear();
    tinController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    challengeCodeController.clear();
    _generatedCode = '';
    _userId = '';
    isCodeSent.value = false;
  }
}
