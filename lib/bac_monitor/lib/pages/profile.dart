import 'package:bac_pos/back_pos/config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../additions/colors.dart';
import '../controllers/profile_controller.dart';
import '../services/account_manager.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileController controller = Get.find();

    return Obx(() {
      if (controller.isLoading.value) {
        return Scaffold(
          backgroundColor: PrimaryColors.darkBlue,
          appBar: AppBar(
            backgroundColor: PrimaryColors.darkBlue,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Get.back(),
            ),
            title: const Text(
              'Profile',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      }

      if (controller.errorMessage.isNotEmpty) {
        return Scaffold(
          backgroundColor: PrimaryColors.darkBlue,
          appBar: AppBar(
            backgroundColor: PrimaryColors.darkBlue,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Get.back(),
            ),
            title: const Text(
              'Profile',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage.value,
                  style: const TextStyle(color: Colors.white),
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
        backgroundColor: PrimaryColors.darkBlue,
        appBar: AppBar(
          backgroundColor: PrimaryColors.darkBlue,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          title: const Text(
            'Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                  color: PrimaryColors.lightBlue,
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
                      backgroundColor: PrimaryColors.brightYellow,
                      child: Text(
                        controller.userInitial,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: PrimaryColors.darkBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Name
                    Text(
                      controller.userRole,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Email
                    Text(
                      controller.userEmail,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
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
                        color: PrimaryColors.lightBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Obx(() {
                        final currentSystem = controller.currentSystem.value;
                        return Row(
                          children: [
                            Expanded(
                              child: _buildSystemOption(
                                title: 'BAC Monitor',
                                subtitle: 'Business Analytics & Control',
                                isSelected: currentSystem == 'monitor',
                                onTap: () => controller.switchSystem('monitor'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSystemOption(
                                title: 'POS System',
                                subtitle: 'Point of Sale',
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

              const SizedBox(height: 24),

              // Multiple Accounts Section
              Obx(() {
                final accounts = controller.getAvailableAccounts();
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
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...accounts.map(
                          (account) => _buildAccountItem(account, controller),
                        ),
                        const SizedBox(height: 12),
                        _buildMenuItem(
                          icon: Icons.add,
                          title: 'Add Current Account',
                          subtitle: 'Save current session',
                          onTap: controller.saveCurrentUserAsAccount,
                        ),
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
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        _buildMenuItem(
                          icon: Icons.add,
                          title: 'Sign in with another account',
                          subtitle: 'Add new account',
                          onTap: controller.saveCurrentUserAsAccount,
                        ),
                      ],
                    ),
                  );
                }
              }),

              const SizedBox(height: 24),

              // Account Management Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMenuItem(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      onTap: () {
                        Get.snackbar(
                          'Info',
                          'Notification settings',
                          backgroundColor: PrimaryColors.lightBlue,
                          colorText: Colors.white,
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Sign Out Button
                    _buildMenuItem(
                      icon: Icons.logout,
                      title: 'Sign out',
                      iconColor: Colors.red,
                      titleColor: Colors.red,
                      onTap: () => _showSignOutDialog(context, controller),
                    ),

                    const SizedBox(height: 32),

                    // App Version
                    Center(
                      child: Text(
                        AppConfig.copyright,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMenuItem({
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
            color: PrimaryColors.lightBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor ?? PrimaryColors.brightYellow,
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
                        color: titleColor ?? Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemOption({
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
                ? PrimaryColors.darkBlue.withOpacity(0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? PrimaryColors.brightYellow
                  : Colors.white.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
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

  Widget _buildAccountItem(UserAccount account, ProfileController controller) {
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
              color: PrimaryColors.lightBlue,
              borderRadius: BorderRadius.circular(12),
              border: isCurrentAccount
                  ? Border.all(color: PrimaryColors.brightYellow, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: PrimaryColors.brightYellow,
                  child: Text(
                    account.username.isNotEmpty
                        ? account.username[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: PrimaryColors.darkBlue,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        account.system == 'monitor'
                            ? 'BAC Monitor'
                            : 'POS System',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrentAccount)
                  Icon(
                    Icons.check_circle,
                    color: PrimaryColors.brightYellow,
                    size: 20,
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withOpacity(0.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, ProfileController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: PrimaryColors.lightBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Are you sure you want to sign out?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                controller.signOut();
              },
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
