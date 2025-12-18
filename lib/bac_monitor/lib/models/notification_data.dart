import 'package:flutter/material.dart';
// import 'package:bac_monitor/additions/colors.dart';

import '../additions/colors.dart';

enum AlertType { stockOut, posOffline, suspiciousTransaction }

extension AlertTypeX on AlertType {
  IconData get icon {
    switch (this) {
      case AlertType.stockOut:
        return Icons.inventory_2_outlined;
      case AlertType.posOffline:
        return Icons.power_off_rounded;
      case AlertType.suspiciousTransaction:
        return Icons.report_problem_outlined;
    }
  }

  Color get color {
    switch (this) {
      case AlertType.stockOut:
        return PrimaryColors.brightYellow;
      case AlertType.posOffline:
        return Colors.orangeAccent;
      case AlertType.suspiciousTransaction:
        return Colors.red.shade400;
    }
  }
}

class AlertNotification {
  final String id;
  final AlertType alertType;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  bool isRead;

  AlertNotification({
    required this.id,
    required this.alertType,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.isRead = false,
  });
}