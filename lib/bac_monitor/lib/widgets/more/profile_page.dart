import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

import '../../additions/colors.dart';
import '../../pages/profile.dart';

class UserProfileHeader extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? companyName;
  final String? avatarInitial;

  const UserProfileHeader({
    super.key,
    required this.userName,
    required this.userEmail,
    this.companyName,
    this.avatarInitial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.getSurfaceColor(context),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          // Modern Avatar with gradient border
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.getAccentColor(context),
                  Colors.amber.shade300,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: AppColors.getPrimaryColor(context),
              child: Text(
                avatarInitial ?? (userName.isNotEmpty ? userName[0].toUpperCase() : 'U'),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User name with modern styling
                Text(
                  userName,
                  style: TextStyle(
                    color: AppColors.getTextPrimaryColor(context),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Email with subtle styling
                Text(
                  userEmail,
                  style: TextStyle(
                    color: AppColors.getTextSecondaryColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (companyName != null && companyName!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  // Company name with badge-like styling
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.getBorderColor(context),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      companyName!,
                      style: TextStyle(
                        color: AppColors.getTextPrimaryColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Settings button for quick access

        ],
      ),
    );
  }
}
