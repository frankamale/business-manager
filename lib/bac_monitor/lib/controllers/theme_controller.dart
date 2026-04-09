import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  final _box = GetStorage();
  final _key = 'isDarkMode';

  Rx<ThemeMode> themeMode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    // Load saved theme preference, default to system if none
    bool? isDark = _box.read(_key);
    if (isDark != null) {
      themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  void toggleTheme() {
    if (themeMode.value == ThemeMode.light) {
      themeMode.value = ThemeMode.dark;
      _box.write(_key, true);
    } else if (themeMode.value == ThemeMode.dark) {
      themeMode.value = ThemeMode.light;
      _box.write(_key, false);
    } else {
      // If system, toggle to dark for manual control
      themeMode.value = ThemeMode.dark;
      _box.write(_key, true);
    }
  }

  void setToSystem() {
    themeMode.value = ThemeMode.system;
    _box.remove(_key); // Remove manual preference
  }

  void setLightMode() {
    themeMode.value = ThemeMode.light;
    _box.write(_key, false);
  }

  void setDarkMode() {
    themeMode.value = ThemeMode.dark;
    _box.write(_key, true);
  }
}