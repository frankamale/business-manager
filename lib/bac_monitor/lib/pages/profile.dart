import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../additions/colors.dart';
import '../controllers/mon_operator_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/theme_controller.dart';
import '../services/account_manager.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final MonOperatorController operatorController;

  @override
  void initState() {
    super.initState();
    // Ensure MonOperatorController is registered before using it
    if (!Get.isRegistered<MonOperatorController>()) {
      Get.put(MonOperatorController());
    }
    operatorController = Get.find<MonOperatorController>();
  }

  @override
  Widget build(BuildContext context) {
    final ProfileController controller = Get.find();

    return Obx(() {
      if (controller.isLoading.value) {
        return Scaffold(
          backgroundColor: AppColors.getBackgroundColor(context),
          appBar: AppBar(
            backgroundColor: AppColors.getCardColor(context),
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: AppColors.getTextPrimaryColor(context),
              ),
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
            child: CircularProgressIndicator(
              color: AppColors.getAccentColor(context),
            ),
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
              icon: Icon(
                Icons.arrow_back,
                color: AppColors.getTextPrimaryColor(context),
              ),
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
                Icon(
                  Icons.error_outline,
                  color: AppColors.getErrorColor(context),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage.value,
                  style: TextStyle(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
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
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.getTextPrimaryColor(context),
            ),
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
                      controller.userName,
                      style: TextStyle(
                        color: AppColors.getTextPrimaryColor(context),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),

                    Obx(
                      () => Column(
                        children: [
                          Text(
                            operatorController.companyName.value,
                            style: TextStyle(
                              color: AppColors.getTextSecondaryColor(context),
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            operatorController.companyAddress.value,
                            style: TextStyle(
                              color: AppColors.getTextPrimaryColor(context),
                              fontWeight: FontWeight.w400,
                              fontSize: 12.0,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
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

                    const SizedBox(height: 12),

                    // Switch Account Section - only show if there are accounts to switch to
                    Obx(() {
                      final accounts = controller.getAvailableAccounts();
                      if (accounts.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
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
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.getCardColor(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: accounts.map((account) => 
                                  _buildAccountItem(context, account, controller)
                                ).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    // // Appearance Section
                    // Padding(
                    //   padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    //   child: Column(
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       Padding(
                    //         padding: EdgeInsets.only(left: 8.0, bottom: 12),
                    //         child: Text(
                    //           'Appearance',
                    //           style: TextStyle(
                    //             fontSize: 12,
                    //             fontWeight: FontWeight.w600,
                    //             letterSpacing: 0.5,
                    //           ),
                    //         ),
                    //       ),
                    //       _buildAppearanceItem(context),
                    //     ],
                    //   ),
                    // ),
                    //
                    // const SizedBox(height: 12),

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
                        color:
                            titleColor ??
                            AppColors.getTextPrimaryColor(context),
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
              Icon(
                Icons.chevron_right,
                color: AppColors.getTextHintColor(context),
              ),
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

  Widget _buildAccountItem(
    BuildContext context,
    UserAccount account,
    ProfileController controller,
  ) {
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
                  ? Border.all(
                      color: AppColors.getAccentColor(context),
                      width: 2,
                    )
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
                        'BAC Monitor',
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

  Widget _buildAppearanceItem(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Obx(() {
          final themeController = Get.find<ThemeController>();
          final isSystem = themeController.themeMode.value == ThemeMode.system;
          final isDark = themeController.themeMode.value == ThemeMode.dark;
          return Row(
            children: [
              Icon(
                Icons.palette_outlined,
                color: AppColors.getAccentColor(context),
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: TextStyle(
                        color: AppColors.getTextPrimaryColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      isSystem
                          ? 'Follow system'
                          : (isDark ? 'Dark mode' : 'Light mode'),
                      style: TextStyle(
                        color: AppColors.getTextSecondaryColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // PopupMenuButton<String>(
              //   onSelected: (value) {
              //     if (value == 'system') {
              //       themeController.setToSystem();
              //     } else if (value == 'light') {
              //       themeController.setLightMode();
              //     } else if (value == 'dark') {
              //       themeController.setDarkMode();
              //     }
              //   },
              //   itemBuilder: (context) => [
              //     // PopupMenuItem(
              //     //   value: 'system',
              //     //   child: Text(
              //     //     'Follow System',
              //     //     style: TextStyle(
              //     //       color: isSystem
              //     //           ? AppColors.getAccentColor(context)
              //     //           : AppColors.getTextPrimaryColor(context),
              //     //     ),
              //     //   ),
              //     // ),
              //     PopupMenuItem(
              //       value: 'light',
              //       child: Text(
              //         'Light Mode',
              //         style: TextStyle(
              //           color: !isSystem && !isDark
              //               ? AppColors.getAccentColor(context)
              //               : AppColors.getTextPrimaryColor(context),
              //         ),
              //       ),
              //     ),
              //     PopupMenuItem(
              //       value: 'dark',
              //       child: Text(
              //         'Dark Mode',
              //         style: TextStyle(
              //           color: !isSystem && isDark
              //               ? AppColors.getAccentColor(context)
              //               : AppColors.getTextPrimaryColor(context),
              //         ),
              //       ),
              //     ),
              //   ],
              //   child: Icon(
              //     Icons.more_vert,
              //     color: AppColors.getTextHintColor(context),
              //   ),
              // ),
            ],
          );
        }),
      ),
    );
  }
}
