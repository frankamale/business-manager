
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../additions/colors.dart';
import '../controllers/mon_dashboard_controller.dart';
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
  final MonDashboardController controller = Get.isRegistered<MonDashboardController>()
      ? Get.find<MonDashboardController>()
      : Get.put(MonDashboardController());
  
  // Track offline status
  final RxBool isOffline = false.obs;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

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
    _startConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Listen to connectivity changes
  void _startConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final result = results.first;
      isOffline.value = result == ConnectivityResult.none;
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
        backgroundColor: AppColors.getBackgroundColor(context),
        body: Obx(
          () => Column(
            children: [
              // Offline indicator banner
              if (isOffline.value)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.orange,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.white, size: 18),
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
                child: IndexedStack(index: controller.tabIndex.value, children: screens),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: Obx(
            () => BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppColors.getCardColor(context),
              onTap: controller.changeTabIndex,
              currentIndex: controller.tabIndex.value,
              selectedItemColor: AppColors.getPrimaryColor(context),
              unselectedItemColor: AppColors.getTextSecondaryColor(context),
              selectedFontSize: 13.0,
              unselectedFontSize: 12.0,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
              ),
              elevation: 10,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_outlined),
                  activeIcon: Icon(Icons.inventory_2),
                  label: 'Inventory',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.store_outlined),
                  activeIcon: Icon(Icons.store),
                  label: 'Sales',
                ),
                // BottomNavigationBarItem(
                //   icon: Icon(Icons.monetization_on_outlined),
                //   activeIcon: Icon(Icons.monetization_on),
                //   label: 'Finance',
                // ),
                //
                BottomNavigationBarItem(
                  icon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
