
import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:convert';
import '../../additions/colors.dart';
import '../../controllers/mon_kpi_overview_controller.dart';
import '../../controllers/mon_operator_controller.dart';
import '../../controllers/mon_salestrends_controller.dart';
import '../../controllers/mon_sync_controller.dart';
import '../../widgets/more/more_data.dart';
import '../../services/api_services.dart';
import '../../widgets/more/profile_page.dart';
import '../../widgets/more/section_header.dart';

class More extends StatefulWidget {
   const More({super.key});

  @override
  State<More> createState() => _MoreState();
}

class _MoreState extends State<More> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String userName = 'User';
  String userEmail = 'user@example.com';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userDataString = await _secureStorage.read(key: 'userData');
      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        if (userData is Map<String, dynamic>) {
          setState(() {
            userName = userData['username'] ?? 'User';
            userEmail = userData['email'] ?? 'user@example.com';
            isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      // Handle error gracefully - use default values
      debugPrint('Error loading user data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(()=>MonSyncController());
    const String avatarUrl = "https://placehold.co/100x100/3498db/white?text=A";

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
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserProfileHeader(
            userName: userName,
            userEmail: userEmail,
            avatarUrl: avatarUrl,
          ),

          const SectionHeader(title: "ACCOUNT"),
          MoreListItem(
            title: "Profile & Settings",
            icon: Icons.person_outline,
            onTap: () {
              print("Tapped Profile & Settings");
            },
          ),
          MoreListItem(
            title: "Manage Stores",
            icon: Icons.store_outlined,
            onTap: () {
              print("Tapped Manage Stores");
            },
          ),
          // MODIFIED: This is the new reload button
          MoreListItem(
            title: "Reload All Data",
            icon: Icons.sync_outlined,
            onTap: () {
              _showReloadDataDialog(context);
            },
          ),
          const SectionHeader(title: "SUPPORT & LEGAL"),
          MoreListItem(
            title: "Help Center",
            icon: Icons.help_outline,
            onTap: () {
              print("Tapped Help Center");
            },
          ),
          MoreListItem(
            title: "Terms of Service",
            icon: Icons.gavel_outlined,
            onTap: () {
              print("Tapped Terms of Service");
            },
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.white12, indent: 16, endIndent: 16),
          const SizedBox(height: 8),

          MoreListItem(
            title: "Log Out",
            icon: Icons.logout,
            color: Colors.red.shade400,
            onTap: () {
              _showLogoutDialog(context);
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ADDED: Confirmation dialog for the reload action
  void _showReloadDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: PrimaryColors.lightBlue,
          title: const Text(
            'Reload All Data?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This will sync everything with the server. This can take a moment. Are you sure?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PrimaryColors.brightYellow,
                foregroundColor: PrimaryColors.darkBlue,
              ),
              child: const Text('Reload'),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the confirmation dialog
                _performFullReload(context); // Start the reload process
              },
            ),
          ],
        );
      },
    );
  }

  // ADDED: The actual logic for reloading all data
  void _performFullReload(BuildContext context) async {
    Get.dialog(
      const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: PrimaryColors.brightYellow),
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
        "Failed to reload data. Please try again.\nError: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: PrimaryColors.lightBlue,
          title: const Text(
            'Confirm Log Out',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to log out?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade400,
              ),
              child: const Text('Log Out'),
              onPressed: () async {
                final apiService = Get.find<MonitorApiService>();
                await apiService.logout();
                Get.offAll(() => const UnifiedLoginScreen());
              },
            ),
          ],
        );
      },
    );
  }
}
