import 'dart:async';

import 'package:circle_nav_bar/circle_nav_bar.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../additions/colors.dart';
import '../controllers/mon_dashboard_controller.dart';
import '../controllers/mon_operator_controller.dart';
import '../controllers/mon_store_controller.dart';
import 'nav_pages/dashboard.dart';
import 'nav_pages/inventory.dart';
import 'nav_pages/more.dart';
import 'nav_pages/stores.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  final MonDashboardController controller =
      Get.isRegistered<MonDashboardController>()
      ? Get.find<MonDashboardController>()
      : Get.put(MonDashboardController());

  // Track offline status
  final RxBool isOffline = false.obs;
  StreamSubscription<InternetConnectionStatus>? _connectivitySubscription;

  final List<Widget> screens = [
    Dashboard(),
    InventoryPage(),
    Stores(),
    // Finance(),
    More(),
  ];

  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    // Register controllers for child pages
    if (!Get.isRegistered<MonOperatorController>()) {
      Get.put(MonOperatorController());
    }
    if (!Get.isRegistered<MonStoresController>()) {
      Get.put(MonStoresController());
    }
    _startConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Listen to connectivity changes
  void _startConnectivityListener() {
    _connectivitySubscription = InternetConnectionChecker.instance.onStatusChange.listen((
      status,
    ) {
      isOffline.value = status == InternetConnectionStatus.disconnected;
    });
  }

  Future<bool> _onWillPop() async {
    if (controller.tabIndex.value != 0) {
      controller.changeTabIndex(0);
      return false;
    } else {
      final now = DateTime.now();
      final didDoubleTap =
          _lastBackPressed != null &&
          now.difference(_lastBackPressed!) < const Duration(seconds: 2);

      if (didDoubleTap) {
        return true;
      } else {
        _lastBackPressed = now;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            backgroundColor: AppColors.getPrimaryColor(context),
          ),
        );
        return false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.getSurfaceColor(context),
        body: Obx(
          () => Column(
            children: [
              // Offline indicator banner
              if (isOffline.value)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.orange,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'OFFLINE MODE - Showing cached data',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              // Main content
              Expanded(
                child: IndexedStack(
                  index: controller.tabIndex.value,
                  children: screens,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Obx(
          () => CircleNavBar(
            onTap: controller.changeTabIndex,
            activeIndex: controller.tabIndex.value,
            inactiveIcons: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dashboard,
                    color: AppColors.getTextPrimary(context),
                  ),
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2,
                    color: AppColors.getTextPrimary(context),
                  ),
                  Text(
                    'Inventory',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.store, color: AppColors.getTextPrimary(context)),
                  Text(
                    'Stores',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.more_horiz,
                    color: AppColors.getTextPrimary(context),
                  ),
                  Text(
                    'More',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
            activeIcons: [
              Icon(
                Icons.dashboard_outlined,
                color: AppColors.getTextPrimary(context),
              ),
              Icon(
                Icons.inventory_2_outlined,
                color: AppColors.getTextPrimary(context),
              ),
              Icon(
                Icons.store_outlined,
                color: AppColors.getTextPrimary(context),
              ),
              Icon(Icons.more_horiz, color: AppColors.getTextPrimary(context)),
            ],
            color: AppColors.getHeaderColor(context),
            circleWidth: 50,
          ),
        ),
      ),
    );
  }
}
