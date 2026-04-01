import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../additions/colors.dart';
import '../../controllers/mon_kpi_overview_controller.dart';
import '../../controllers/mon_operator_controller.dart';
import '../../controllers/mon_salestrends_controller.dart';
import '../../controllers/mon_sync_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../services/api_services.dart';
import '../../widgets/more/more_data.dart';
import '../../widgets/more/profile_page.dart';
import '../../widgets/more/section_header.dart';
import '../../pages/profile.dart';

class More extends StatefulWidget {
  const More({super.key});

  @override
  State<More> createState() => _MoreState();
}

class _MoreState extends State<More> {
  final ProfileController _profileController = Get.put(ProfileController());

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => MonSyncController());

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'More',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
        backgroundColor: AppColors.getCardColor(context),
        foregroundColor: AppColors.getTextPrimaryColor(context),
        elevation: 0,
      ),
      body: Obx(() {
        if (_profileController.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.getAccentColor(context),
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            UserProfileHeader(
              userName: _profileController.userName,
              userEmail: _profileController.userEmail,
              companyName: _profileController.companyName,
              avatarInitial: _profileController.userInitial,
            ),
 
            SectionHeader(title: "ACCOUNT", textColor: AppColors.getTextSecondaryColor(context)),

            MoreListItem(
              title: "Profile & Settings",
              icon: Icons.person_outline,
              onTap: () => Get.to(() => const ProfilePage()),
            ),

            MoreListItem(
              title: "Manage Stores",
              icon: Icons.store_outlined,
              onTap: () {
                debugPrint("Tapped Manage Stores");
              },
            ),

            MoreListItem(
              title: "Reload All Data",
              icon: Icons.sync_outlined,
              onTap: () => _showReloadDataDialog(context),
            ),

            Divider(color: AppColors.getBorderColor(context), indent: 16, endIndent: 16),
            const SizedBox(height: 8),

            MoreListItem(
              title: "Log Out",
              icon: Icons.logout,
              color: AppColors.getErrorColor(context),
              onTap: () => _showLogoutDialog(context),
            ),

            const SizedBox(height: 40),
          ], 
        );
      }),
    );
  }

  // -------------------- RELOAD DATA --------------------

  void _showReloadDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text(
          'Reload All Data?',
          style: TextStyle(color: AppColors.getTextPrimaryColor(context)),
        ),
        content: Text(
          'This will sync everything with the server. This can take a moment. Are you sure?',
          style: TextStyle(color: AppColors.getTextSecondaryColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.getTextSecondaryColor(context)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.getAccentColor(context),
              foregroundColor: AppColors.getTextPrimaryColor(context),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _performFullReload(context);
            },
            child: const Text('Reload'),
          ),
        ],
      ),
    );
  }

  Future<void> _performFullReload(BuildContext context) async {
    Get.dialog(
      PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.getAccentColor(context),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      final apiService = Get.find<MonitorApiService>();
      await apiService.fetchAndCacheAllData(force: true);

      if (Get.isRegistered<MonKpiOverviewController>()) {
        await Get.find<MonKpiOverviewController>().fetchKpiData();
      }
      if (Get.isRegistered<MonSalesTrendsController>()) {
        await Get.find<MonSalesTrendsController>().fetchAllData();
      }
      if (Get.isRegistered<MonOperatorController>()) {
        await Get.find<MonOperatorController>().loadCompanyDetailsFromDb();
      }

      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        "Success",
        "All data has been reloaded from the server.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.getSuccessColor(context),
        colorText: LightColors.card,
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        "Error",
        "Failed to reload data.\n${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.getErrorColor(context),
        colorText: LightColors.card,
      );
    }
  }


  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        title: Text(
          'Confirm Log Out',
          style: TextStyle(color: AppColors.getTextPrimaryColor(context)),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppColors.getTextSecondaryColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.getTextSecondaryColor(context)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.getErrorColor(context),
            ),
            onPressed: () async {
              final apiService = Get.find<MonitorApiService>();
              await apiService.logout();
              Get.offAll(() => const UnifiedLoginScreen());
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
