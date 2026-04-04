import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UIHelper {
  /// Show offline mode snackbar
  static void showOfflineSnackbar() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (Get.context != null) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_off, color: Colors.white),
                const SizedBox(width: 12),
                const Text('You are offline. Showing cached data.'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }
}
