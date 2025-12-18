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
      backgroundColor: PrimaryColors.darkBlue,
      appBar: AppBar(
        title: const Text(
          'More',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: PrimaryColors.darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Obx(() {
        if (_profileController.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              color: PrimaryColors.brightYellow,
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

            const SectionHeader(title: "ACCOUNT"),

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

            const Divider(color: Colors.white12, indent: 16, endIndent: 16),
            const SizedBox(height: 8),

            MoreListItem(
              title: "Log Out",
              icon: Icons.logout,
              color: Colors.red.shade400,
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
        backgroundColor: PrimaryColors.lightBlue,
        title: const Text(
          'Reload All Data?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will sync everything with the server. This can take a moment. Are you sure?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PrimaryColors.brightYellow,
              foregroundColor: PrimaryColors.darkBlue,
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
      const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(
            color: PrimaryColors.brightYellow,
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      final apiService = Get.find<MonitorApiService>();
      await apiService.fetchAndCacheAllData();

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
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        "Error",
        "Failed to reload data.\n${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }


  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PrimaryColors.lightBlue,
        title: const Text(
          'Confirm Log Out',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
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
