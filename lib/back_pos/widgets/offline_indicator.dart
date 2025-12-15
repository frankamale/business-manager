import 'package:flutter/material.dart';
import '../utils/network_helper.dart';


class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: NetworkHelper.hasConnection(),
      builder: (context, snapshot) {
        // If still loading or has connection, don't show anything
        final hasConnection = snapshot.data ?? true;
        if (hasConnection) {
          return const SizedBox.shrink();
        }

        // Show offline indicator
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.offline_bolt, size: 16, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'Offline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
