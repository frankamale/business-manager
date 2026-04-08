import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../shared/services/customer_auth_service.dart';
import '../auth/login.dart';
import '../controllers/auth_controller.dart';
import '../controllers/service_point_controller.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/customer_controller.dart';
import '../controllers/settings_controller.dart';
import '../services/api_services.dart';
import '../services/settings_service.dart';
import '../utils/network_helper.dart';
import '../../shared/database/unified_db_helper.dart';
import '../../flavors/flavor_colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final SettingsController settingsController = Get.put(SettingsController());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: FlavorColors.current.primary,
        iconTheme: IconThemeData(color: Colors.white),

        title: const Text('Settings', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile section
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(
                      () => Text(
                        authController.currentUser.value?.name ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Obx(
                      () => Text(
                        authController.currentUser.value?.username ?? 'Unknown',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Settings list
          Expanded(
            child: ListView(
              children: [
                // Conditionally render Monitor App link for admin users only
                Obx(() {
                  final user = authController.currentUser.value;
                  final isAdmin = user != null &&
                                user.role.toLowerCase().contains('admin');

                  if (isAdmin) {
                    return ListTile(
                      leading: const Icon(Icons.monitor),
                      title: const Text('Monitor App'),
                      subtitle: const Text('View analytics and monitoring dashboard'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        SettingsService().navigateToMonitorApp();
                      },
                    );
                  } else {
                    return Container();
                  }
                }),
                 ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text('Auto Upload Sales'),
                  subtitle: const Text('Automatically sync sales data to server'),
                  trailing: Obx(() => Switch(
                    value: settingsController.autoUploadEnabled.value,
                    onChanged: (value) => settingsController.toggleAutoUpload(value),
                  )),
                ),
                ListTile(
                  leading: const Icon(Icons.payment),
                  title: const Text('Allow Access to Payment'),
                  subtitle: const Text('Enable payment access for all user roles (cashiers, waiters, etc.)'),
                  trailing: Obx(() => Switch(
                    value: settingsController.paymentAccessForAllUsers.value,
                    onChanged: (value) => settingsController.togglePaymentAccessForAllUsers(value),
                  )),
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Allow Price Editing'),
                  subtitle: const Text('Enable editing of item prices in POS screen'),
                  trailing: Obx(() => Switch(
                    value: settingsController.priceEditingEnabled.value,
                    onChanged: (value) => settingsController.togglePriceEditing(value),
                  )),
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Reload POS Data'),
                  subtitle: const Text('Refresh all app data'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showReloadDataDialog(context),
                ),
                // ListTile(
                //   leading: const Icon(Icons.lock_outline),
                //   title: const Text('Change Password'),
                //   subtitle: const Text('Update your login password'),
                //   trailing: const Icon(Icons.arrow_forward_ios),
                //   onTap: () => _showChangePasswordDialog(context, authController),
                // ),
                const ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text('Notifications'),
                  trailing: Icon(Icons.arrow_forward_ios),
                ),
                // const ListTile(
                //   leading: Icon(Icons.palette),
                //   title: Text('Theme'),
                //   trailing: Icon(Icons.arrow_forward_ios),
                // ),
                // const ListTile(
                //   leading: Icon(Icons.language),
                //   title: Text('Language'),
                //   trailing: Icon(Icons.arrow_forward_ios),
                // ),
                // const ListTile(
                //   leading: Icon(Icons.help),
                //   title: Text('Help & Support'),
                //   trailing: Icon(Icons.arrow_forward_ios),
                // ),
                //
                             ],
            ),
          ),
          // Logout button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Confirm Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [

                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await authController.logout();
                            Get.offAll(() => const Login());
                          },
                          child: const Text('Logout'),
                        ),
                      ],
                    );
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }

  void _showReloadDataDialog(BuildContext context) {
    final isLoading = ValueNotifier<bool>(false);
    final progressMessage = ValueNotifier<String>('Preparing to reload data...');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reload POS Data'),
          content: ValueListenableBuilder<String>(
            valueListenable: progressMessage,
            builder: (context, message, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: isLoading,
                    builder: (context, loading, child) {
                      if (loading) {
                        return Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(message, textAlign: TextAlign.center),
                          ],
                        );
                      }
                      return Text(
                        'This will take a while. Continue?',
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isLoading,
              builder: (context, loading, child) {
                return ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          isLoading.value = true;

                          try {
                            // Check network connectivity
                            final hasNetwork = await NetworkHelper.hasConnection();
                            if (!hasNetwork) {
                              Get.snackbar(
                                'No Internet',
                                'Please connect to the internet to reload data',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.orange.shade100,
                              );
                              Navigator.of(dialogContext).pop();
                              return;
                            }

                            // Get controllers
                            final authController = Get.find<AuthController>();
                            final servicePointController = Get.find<ServicePointController>();
                            final inventoryController = Get.find<InventoryController>();
                            final customerController = Get.find<CustomerController>();
                            final apiService = Get.find<PosApiService>();

                            // Reload data in sequence with progress updates
                            progressMessage.value = 'Reloading users...';
                            await authController.syncUsersFromAPI();

                            progressMessage.value = 'Reloading service points...';
                            await servicePointController.syncServicePointsFromAPI();

                            progressMessage.value = 'Reloading inventory...';
                            await inventoryController.syncInventoryFromAPI();

                            progressMessage.value = 'Reloading customers...';
                            await customerController.syncCustomersFromAPI();

                            progressMessage.value = 'Reloading cash accounts...';
                            try {
                              final cashAccounts = await apiService.fetchCashAccounts();
                              await Get.find<UnifiedDatabaseHelper>().insertCashAccounts(cashAccounts);
                            } catch (e) {
                              // Cash accounts are not critical, continue
                            }

                            progressMessage.value = 'Data reload complete!';

                            // Close dialog and show success
                            Navigator.of(dialogContext).pop();

                            Get.snackbar(
                              'Success',
                              'All POS data has been reloaded successfully',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.green.shade100,
                            );

                          } catch (e) {
                            Navigator.of(dialogContext).pop();
                            Get.snackbar(
                              'Error',
                              'Failed to reload data: ${e.toString()}',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.red.shade100,
                            );
                          } finally {
                            isLoading.value = false;
                          }
                        },
                  child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Reload'),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

void _showChangePasswordDialog(BuildContext context, AuthController authController) {
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final isLoading = ValueNotifier<bool>(false);
  final obscureOld = ValueNotifier<bool>(true);
  final obscureNew = ValueNotifier<bool>(true);
  final obscureConfirm = ValueNotifier<bool>(true);
  final errorMessage = ValueNotifier<String>('');

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: errorMessage,
                  builder: (context, error, child) {
                    if (error.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: obscureOld,
                  builder: (context, obscure, child) {
                    return TextFormField(
                      controller: oldPasswordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Current POS Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => obscureOld.value = !obscureOld.value,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your old password';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: obscureNew,
                  builder: (context, obscure, child) {
                    return TextFormField(
                      controller: newPasswordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => obscureNew.value = !obscureNew.value,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (value.length < 4) {
                          return 'Password must be at least 4 characters';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: obscureConfirm,
                  builder: (context, obscure, child) {
                    return TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => obscureConfirm.value = !obscureConfirm.value,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value != newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              oldPasswordController.dispose();
              newPasswordController.dispose();
              confirmPasswordController.dispose();
            },
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: isLoading,
            builder: (context, loading, child) {
              return ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        errorMessage.value = '';
                        isLoading.value = true;

                        try {
                          // Get current user
                          final currentUser = authController.currentUser.value;
                          if (currentUser == null) {
                            throw Exception('User not logged in');
                          }

                          // Verify old password against pospassword
                          final enteredPassword = int.tryParse(oldPasswordController.text);
                          if (enteredPassword == null || enteredPassword != currentUser.pospassword) {
                            throw Exception('Incorrect old password');
                          }

                          // Check network connectivity for API call
                          final hasNetwork = await NetworkHelper.hasConnection();
                          if (!hasNetwork) {
                            throw Exception('No internet connection. Please connect to the network and try again.');
                          }

                          // Call API to change password
                          final apiService = Get.find<PosApiService>();
                          await apiService.changePassword(
                            userId: currentUser.id,
                            newPassword: newPasswordController.text,
                          );

                          // Update cached staff credentials
                          final customerAuthService = CustomerAuthService();
                          await customerAuthService.updateCachedStaffPassword(
                            username: currentUser.username,
                            newPassword: newPasswordController.text,
                          );

                          // Update stored server credentials
                          final credentials = await apiService.getServerCredentials();
                          if (credentials['username'] != null) {
                            await apiService.saveServerCredentials(
                              credentials['username']!,
                              newPasswordController.text,
                            );
                          }

                          // Close dialog and show success
                          Navigator.of(dialogContext).pop();
                          oldPasswordController.dispose();
                          newPasswordController.dispose();
                          confirmPasswordController.dispose();

                          Get.snackbar(
                            'Success',
                            'Your password has been changed successfully',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.green.shade100,
                          );
                        } catch (e) {
                          errorMessage.value = e.toString().replaceFirst('Exception: ', '');
                        } finally {
                          isLoading.value = false;
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Change Password'),
              );
            },
          ),
        ],
      );
    },
  );
}
