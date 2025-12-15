
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../additions/colors.dart';
import '../controllers/dashboard_controller.dart';
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
  final DashboardController controller = Get.put(DashboardController());

  final List<Widget> screens = [
    Dashboard(),
    InventoryPage(),
    Stores(),
    // Finance(),
    More(),
  ];

  DateTime? _lastBackPressed;

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
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            backgroundColor: PrimaryColors.lightBlue,
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
        backgroundColor: PrimaryColors.darkBlue,
        body: Obx(
          () =>
              IndexedStack(index: controller.tabIndex.value, children: screens),
        ),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: Obx(
            () => BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: PrimaryColors.darkBlue,
              onTap: controller.changeTabIndex,
              currentIndex: controller.tabIndex.value,
              selectedItemColor: PrimaryColors.brightYellow,
              unselectedItemColor: Colors.white.withOpacity(0.6),
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
