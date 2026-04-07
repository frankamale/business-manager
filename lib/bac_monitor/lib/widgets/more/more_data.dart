import 'package:flutter/material.dart';
import '../../additions/colors.dart';

class MoreListItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const MoreListItem({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? AppColors.getTextSecondaryColor(context), size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? AppColors.getTextPrimaryColor(context),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: color == null
          ? Icon(Icons.arrow_forward_ios, color: AppColors.getTextHintColor(context), size: 16)
          : null,
    );
  }
}
