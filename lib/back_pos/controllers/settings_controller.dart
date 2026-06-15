import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../flavors/flavor_colors.dart';
import '../services/settings_service.dart';
import '../../shared/database/unified_db_helper.dart';

class SettingsController extends GetxController {
  final SettingsService _settingsService = SettingsService();
  final _dbHelper = UnifiedDatabaseHelper.instance;
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
    paymentAccessForAllUsers.value = _settingsService
        .getPaymentAccessForAllUsers();
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
          Get.snackbar(
            'Error',
            'User does not have supervisor or admin privileges',
          );
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
    usernameController.clear();
    passwordController.clear();

    final obscurePassword = ValueNotifier<bool>(true);
    final isLoading = ValueNotifier<bool>(false);
    final errorMessage = ValueNotifier<String>('');
    final primary = FlavorColors.current.primary;

    return await Get.dialog<bool>(
          Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  color: primary,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Colors.white.withOpacity(0.85),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Admin Authentication',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Error banner
                      ValueListenableBuilder<String>(
                        valueListenable: errorMessage,
                        builder: (context, error, _) {
                          if (error.isEmpty) return const SizedBox.shrink();
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              error,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),

                      // Username
                      const Text(
                        'Username',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF444444),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: usernameController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter username',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F8FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: primary, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF444444),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ValueListenableBuilder<bool>(
                        valueListenable: obscurePassword,
                        builder: (context, obscure, _) {
                          return TextField(
                            controller: passwordController,
                            obscureText: obscure,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Enter password',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF7F8FA),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 19,
                                  color: Colors.grey[500],
                                ),
                                onPressed: () => obscurePassword.value =
                                    !obscurePassword.value,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

                // Actions
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Get.back(result: false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: isLoading,
                          builder: (context, loading, _) {
                            return ElevatedButton(
                              onPressed: loading
                                  ? null
                                  : () async {
                                      errorMessage.value = '';
                                      isLoading.value = true;
                                      try {
                                        bool success = await authenticate();
                                        if (success) {
                                          Get.back(result: true);
                                        } else {
                                          errorMessage.value =
                                              'Invalid username or password.';
                                        }
                                      } catch (e) {
                                        errorMessage.value =
                                            'Authentication failed. Try again.';
                                      } finally {
                                        isLoading.value = false;
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: loading
                                    ? Colors.grey.shade300
                                    : primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: loading
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Authenticate',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
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
      Get.snackbar(
        'Settings',
        'Payment access for all users ${value ? 'enabled' : 'disabled'}',
      );
    }
  }

  Future<void> togglePriceEditing(bool value) async {
    bool authenticated = await showAuthDialog();
    if (authenticated) {
      priceEditingEnabled.value = value;
      _settingsService.setPriceEditingEnabled(value);
      Get.snackbar(
        'Settings',
        'Price editing ${value ? 'enabled' : 'disabled'}',
      );
    }
  }
}
