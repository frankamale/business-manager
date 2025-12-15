import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../back_pos/utils/network_helper.dart';
import '../../additions/colors.dart';
import '../../controllers/operator_controller.dart';
import '../../controllers/sync_controller.dart';
import '../../services/api_services.dart';
import '../bottom_nav.dart';
import 'Login.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.wait([
      _performAuthAndNavigation(),
      Future.delayed(const Duration(seconds: 2)),
    ]);
  }

  Future<void> _performAuthAndNavigation() async {
    final apiService = Get.find<ApiService>();

    if (Get.isRegistered<OperatorController>()) {
      await Get.find<OperatorController>().loadCompanyDetailsFromDb();
    } else {
      Get.put(OperatorController());
    }

    final token = apiService.getStoredToken();
    if (token == null) {
      Get.offAll(() => const LoginPage());
      return;
    }

    if (!Get.isRegistered<SyncController>()) {
      Get.put(SyncController());
      debugPrint("SplashPage: SyncController has been initialized.");
    }

    try {
      final isOnline = await NetworkHelper.hasConnection();
      if (isOnline) {
        debugPrint("SplashPage: Device is online. Syncing recent sales...");
        await apiService.syncRecentSales();
      } else {
        debugPrint(
          "SplashPage: Device is offline. Proceeding with local data.",
        );
      }
    } catch (e) {
      debugPrint(
        "SplashPage: Error during initial sync. Proceeding with local data. Error: $e",
      );
    }

    Get.offAll(() => const BottomNav());
  }

  // Future<bool> _checkConnectivity() async {
  //   try {
  //     final connectivityResult = await Connectivity().checkConnectivity();
  //     return connectivityResult != ConnectivityResult.none;
  //   } catch (e) {
  //     return false;
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final operatorController = Get.find<OperatorController>();

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        toolbarHeight: 0,
        backgroundColor: PrimaryColors.darkBlue,
      ),
      backgroundColor: PrimaryColors.darkBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.storefront,
              color: PrimaryColors.brightYellow,
              size: 100,
            ),
            const SizedBox(height: 24),
            Obx(() {
              final companyName = operatorController.companyName.value;
              return Text(
                companyName.isNotEmpty && companyName != 'Loading...'
                    ? companyName
                    : 'Welcome',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              );
            }),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                PrimaryColors.brightYellow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


