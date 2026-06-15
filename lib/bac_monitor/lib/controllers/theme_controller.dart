import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeController extends GetxController {
  Rx<ThemeMode> themeMode = ThemeMode.light.obs;

  @override
  void onInit() {
    super.onInit();
    // Always use light mode
    themeMode.value = ThemeMode.light;
  }

  // No theme toggling methods needed as only light mode is supported
}