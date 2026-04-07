import 'package:flutter/material.dart';
import '../../additions/colors.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Color? textColor;

  const SectionHeader({super.key, required this.title, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: textColor ?? AppColors.getTextSecondaryColor(context),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
