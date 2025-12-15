import 'package:flutter/material.dart';
import 'package:bac_monitor/additions/colors.dart';

class UserProfileHeader extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? avatarUrl;

  const UserProfileHeader({
    super.key,
    required this.userName,
    required this.userEmail,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PrimaryColors.lightBlue,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: PrimaryColors.brightYellow,
            backgroundImage: avatarUrl != null
                ? AssetImage("assets/images/profile.png")
                : AssetImage("assets/images/profile.png"),
            child: avatarUrl == "assets/images/profile.png"
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
