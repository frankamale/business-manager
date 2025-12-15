import 'package:flutter/material.dart';
import '../../additions/colors.dart';
import '../../models/notification_data.dart';

class AlertListItem extends StatelessWidget {
  final AlertNotification notification;

  const AlertListItem({super.key, required this.notification});

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dim read notifications for better visual hierarchy.
    return Opacity(
      opacity: notification.isRead ? 0.6 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          decoration: BoxDecoration(
            color: PrimaryColors.lightBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with colored background
              CircleAvatar(
                radius: 22,
                backgroundColor: notification.alertType.color.withOpacity(0.15),
                child: Icon(
                  notification.alertType.icon,
                  color: notification.alertType.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Title, Subtitle, and Timestamp
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Timestamp on the right
              Text(
                _formatTimestamp(notification.timestamp),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}