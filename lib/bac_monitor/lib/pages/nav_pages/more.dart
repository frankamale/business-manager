import 'dart:io';

import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../additions/colors.dart';
import '../../controllers/mon_kpi_overview_controller.dart';
import '../../controllers/mon_operator_controller.dart';
import '../../controllers/mon_salestrends_controller.dart';
import '../../controllers/mon_sync_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../../../shared/utils/connectivity_helper.dart';
import '../../services/api_services.dart';
import '../../services/kpi_sync_service.dart';
import '../../../../shared/database/unified_db_helper.dart';
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
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getHeaderColor(context),
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

            SectionHeader(
              title: "ACCOUNT",
              textColor: AppColors.getTextSecondaryColor(context),
            ),

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

            Divider(
              color: AppColors.getBorderColor(context),
              indent: 16,
              endIndent: 16,
            ),
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
            child: const  Text('Reload')

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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: AppColors.getCardColor(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.getAccentColor(context),
                ),
                const SizedBox(height: 20),
                Text(
                  'Fetching Data',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),

                const SizedBox(height: 16),

                // Optional subtle progress hint (fake or real)
                LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(10),
                  backgroundColor: AppColors.getTextSecondaryColor(
                    context,
                  ).withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(
                    AppColors.getAccentColor(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      final apiService = Get.find<MonitorApiService>();
      final dbHelper = UnifiedDatabaseHelper.instance;

      // Close and delete the database
      await dbHelper.close();

      // Delete the database file
      final dbPath = await getDatabasesPath();
      final companyId = await apiService.getStoredCompanyId();
      if (companyId != null && companyId.isNotEmpty) {
        final dbFile = '$dbPath/unified_db_company_$companyId.db';
        final file = File(dbFile);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Reopen the database
      if (companyId != null && companyId.isNotEmpty) {
        await dbHelper.openForCompany(companyId);
      }

      // Fetch baseline data (service points, inventory, company details)
      final kpiSyncService = Get.find<KpiSyncService>();
      final baselineResult = await kpiSyncService.fetchBaselineDatasets();

      // Store baseline data
      if (baselineResult.servicePoints.isNotEmpty) {
        final servicePoints = baselineResult.servicePoints
            .map((e) {
              final sp = Map<String, dynamic>.from(e as Map);
              return {
                'id': sp['id'],
                'name': sp['name'],
                'code': sp['code'],
                'fullName': sp['fullName'] ?? sp['name'] ?? '',
                'servicepointtype': sp['servicepointtype'] ?? '',
                'facilityName': sp['facilityName'] ?? '',
                'sales': (sp['sales'] == true || sp['sales'] == 1) ? 1 : 0,
                'stores': (sp['stores'] == true || sp['stores'] == 1) ? 1 : 0,
                'production': (sp['production'] == true || sp['production'] == 1) ? 1 : 0,
                'booking': (sp['booking'] == true || sp['booking'] == 1) ? 1 : 0,
              };
            })
            .toList();
        await dbHelper.insertServicePoints(servicePoints);
      }
      if (baselineResult.companyDetails.isNotEmpty) {
        await dbHelper.insertCompanyDetails(baselineResult.companyDetails);
      }
      if (baselineResult.inventory.isNotEmpty) {
        final inventory = baselineResult.inventory
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        await dbHelper.insertMonInventoryItems(inventory);
      }

      // Clear ALL existing KPI data before full reload (user explicitly requested this)
      await dbHelper.deleteAllKpiSales();
      debugPrint("More: Cleared all existing KPI data for fresh sync");

      // Fetch 3 years of KPI data
      final now = DateTime.now();
      final threeYearsAgo = DateTime(now.year - 3, now.month, now.day);
      await apiService.syncAllKpiData(threeYearsAgo, now);

      // Refresh all controllers with the new data from DB
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
        "All data has been reloaded from the server (3 years).",
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
