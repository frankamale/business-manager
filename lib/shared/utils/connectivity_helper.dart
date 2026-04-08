import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../back_pos/utils/network_helper.dart';

/// Utility class for handling offline notifications and connectivity checks
class ConnectivityHelper {
  /// Checks if device is online and shows appropriate feedback if offline
  /// Returns true if online, false if offline (and shows notification)
  static Future<bool> checkConnectivityAndNotify() async {
    final isOnline = await NetworkHelper.hasConnection();

    if (!isOnline) {
      Get.snackbar(
        'No Internet Connection',
        'This action requires an internet connection. Please check your network and try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        duration: const Duration(seconds: 4),
        icon: Icon(
          Icons.wifi_off,
          color: Colors.red.shade800,
        ),
      );
      return false;
    }

    return true;
  }

  /// Shows a banner notification when offline for critical operations
  static void showOfflineBanner(String action) {
    Get.snackbar(
      'Offline Mode',
      'Cannot $action without internet connection',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange.shade100,
      colorText: Colors.orange.shade800,
      duration: const Duration(seconds: 3),
      icon: Icon(
        Icons.cloud_off,
        color: Colors.orange.shade800,
      ),
    );
  }

  /// Wrapper for async operations that require network
  /// Shows loading indicator and handles offline state
  static Future<T?> executeWithConnectivityCheck<T>(
    BuildContext context,
    Future<T> Function() operation,
    String actionDescription,
  ) async {
    // Check connectivity first
    final isOnline = await checkConnectivityAndNotify();
    if (!isOnline) {
      return null;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Connecting...'),
            ],
          ),
        );
      },
    );

    try {
      final result = await operation();
      // Dismiss loading dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return result;
    } catch (e) {
      // Dismiss loading dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      Get.snackbar(
        'Connection Error',
        'Failed to $actionDescription. Please check your internet connection.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        duration: const Duration(seconds: 4),
      );
      return null;
    }
  }
}