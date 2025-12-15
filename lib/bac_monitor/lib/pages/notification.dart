import 'package:flutter/material.dart';
import 'package:bac_monitor/additions/colors.dart';
import 'package:bac_monitor/models/notification_data.dart';

import '../widgets/notification/notification_list.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<AlertNotification> _notifications = [
    AlertNotification(
      id: '1',
      alertType: AlertType.suspiciousTransaction,
      title: 'Suspicious Transaction',
      subtitle: 'Unusually large sale of UGX 1,500,000 at 10:15 PM.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    AlertNotification(
      id: '2',
      alertType: AlertType.stockOut,
      title: 'Low Stock: Coffee Beans',
      subtitle: 'Only 5 units remaining for SKU: COF-ORG-500.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AlertNotification(
      id: '3',
      alertType: AlertType.posOffline,
      title: 'POS Terminal 2 Offline',
      subtitle: 'Terminal lost connection at checkout counter.',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: true,
    ),
    AlertNotification(
      id: '4',
      alertType: AlertType.stockOut,
      title: 'Out of Stock: Avocado Oil',
      subtitle: '0 units remaining for SKU: OIL-AVO-500.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AlertNotification(
      id: '5',
      alertType: AlertType.suspiciousTransaction,
      title: 'Multiple Voids',
      subtitle: 'Cashier "Jane Doe" voided 3 transactions in a row.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
    ),
  ];

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
    });
  }

  void _markAsRead(String id) {
    setState(() {
      final notification = _notifications.firstWhere((n) => n.id == id);
      notification.isRead = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: PrimaryColors.darkBlue,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: PrimaryColors.darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Show "Mark all read" button only if there are unread notifications
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: PrimaryColors.brightYellow),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                // Make each item tappable to mark it as read
                return GestureDetector(
                  onTap: () => _markAsRead(notification.id),
                  child: AlertListItem(notification: notification),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: PrimaryColors.lightBlue,
          ),
          const SizedBox(height: 16),
          const Text(
            'All Clear!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You have no new notifications.',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
