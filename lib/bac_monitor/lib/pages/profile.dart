import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../additions/colors.dart';
import '../controllers/mon_operator_controller.dart';
import '../controllers/profile_controller.dart';
import '../services/account_manager.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final ProfileController controller = Get.find();
    final operatorController = Get.find<MonOperatorController>();

    return Obx(() {
      if (controller.isLoading.value) {
        return Scaffold(
          backgroundColor: AppColors.getBackgroundColor(context),
          appBar: AppBar(
            backgroundColor: AppColors.getCardColor(context),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimaryColor(context)),
              onPressed: () => Get.back(),
            ),
            title: Text(
              'Profile',
              style: TextStyle(
                color: AppColors.getTextPrimaryColor(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: Center(
            child: CircularProgressIndicator(color: AppColors.getAccentColor(context)),
          ),
        );
      }

      if (controller.errorMessage.isNotEmpty) {
        return Scaffold(
          backgroundColor: AppColors.getBackgroundColor(context),
          appBar: AppBar(
            backgroundColor: AppColors.getCardColor(context),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimaryColor(context)),
              onPressed: () => Get.back(),
            ),
            title: Text(
              'Profile',
              style: TextStyle(
                color: AppColors.getTextPrimaryColor(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: AppColors.getErrorColor(context), size: 64),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage.value,
                  style: TextStyle(color: AppColors.getTextPrimaryColor(context)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.loadProfileData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: AppColors.getCardColor(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimaryColor(context)),
            onPressed: () => Get.back(),
          ),
          title: Text(
            'Profile',
            style: TextStyle(color: AppColors.getTextPrimaryColor(context), fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Current User Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: AppColors.getCardColor(context),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // Profile Avatar
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.getAccentColor(context),
                      child: Text(
                        controller.userInitial,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Name
                    Text(
                      operatorController.companyName.value,
                      style: TextStyle(
                        color: AppColors.getTextPrimaryColor(context),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Email
                    Text(
                      controller.userEmail,
                      style: TextStyle(
                        color: AppColors.getTextSecondaryColor(context),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Company & Role
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // System Switcher Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.getCardColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Obx(() {
                        final currentSystem = controller.currentSystem.value;
                        return Row(
                          children: [
                            Expanded(
                              child: _buildSystemOption(
                                context,
                                title: 'POS System',
                                subtitle: 'Tap to switch to pos interface',
                                isSelected: currentSystem == 'pos',
                                onTap: () => controller.switchSystem('pos'),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),

              if (appFlavor != "bac") const SizedBox(height: 6),

              // Multiple Accounts Section
              if (appFlavor == "bac")
                Obx(() {
                  final accounts = controller.getAvailableAccounts();
                  print("accounts $accounts");
                  if (accounts.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0, bottom: 12),
                            child: Text(
                              'Switch Account',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ...accounts
                              .map(
                                (account) =>
                                    _buildAccountItem(context, account, controller),
                              )
                              .toList(),
                        ],
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0, bottom: 12),
                            child: Text(
                              'Accounts',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          _buildMenuItem(
                            context,
                            icon: Icons.add,
                            title: 'Sign in with another account',
                            subtitle: 'Add new account',
                            onTap: controller.signOut,
                          ),
                        ],
                      ),
                    );
                  }
                }),

              const SizedBox(height: 24),

              // Data Management Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 8.0, bottom: 12),
                      child: Text(
                        'Data Management',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    // _buildMenuItem(
                    //   icon: Icons.cloud_download,
                    //   title: 'Reload All Data',
                    //   subtitle: 'Re-sync all sales from 2023',
                    //   onTap: () => _showReloadConfirmDialog(controller),
                    // ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      context,
                      icon: Icons.logout,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      iconColor: AppColors.getErrorColor(context),
                      titleColor: AppColors.getErrorColor(context),
                      onTap: controller.signOut,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getCardColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor ?? AppColors.getAccentColor(context),
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? AppColors.getTextPrimaryColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.getTextSecondaryColor(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.getTextHintColor(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.getSurfaceColor(context)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.getAccentColor(context)
                  : AppColors.getBorderColor(context),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.getTextPrimaryColor(context),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.getTextSecondaryColor(context),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountItem(BuildContext context, UserAccount account, ProfileController controller) {
    final isCurrentAccount =
        controller.accountManager.currentAccount.value?.id == account.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.switchToAccount(account),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: isCurrentAccount
                  ? Border.all(color: AppColors.getAccentColor(context), width: 2)
                  : null,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.getAccentColor(context),
                  child: Text(
                    account.username.isNotEmpty
                        ? account.username[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.username,
                        style: TextStyle(
                          color: AppColors.getTextPrimaryColor(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        account.system == 'monitor'
                            ? 'BAC Monitor'
                            : 'POS System',
                        style: TextStyle(
                          color: AppColors.getTextSecondaryColor(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrentAccount)
                  Icon(
                    Icons.check_circle,
                    color: AppColors.getAccentColor(context),
                    size: 20,
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.getTextHintColor(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
