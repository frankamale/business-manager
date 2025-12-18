import 'package:flutter/material.dart';

import '../../additions/colors.dart';

class CustomAuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool isPassword;

  const CustomAuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      cursorColor: PrimaryColors.brightYellow,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(vertical: 20.0),
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 20, right: 12),
          child: Icon(icon, color: Colors.white70, size: 24),
        ),
        filled: true,
        fillColor: PrimaryColors.lightBlue,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
