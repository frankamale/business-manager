import 'package:flutter/material.dart';

/// Primary brand colors - Light Mode
class LightColors {
  // Background colors
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color card = Color(0xFFFFFFFF);
  
  // Text colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFD1D5DB);
  
  // Brand colors
  static const Color primary = Color(0xFF001B38);
  static const Color primaryLight = Color(0xFF00274D);
  static const Color primaryDark = Color(0xFF000F1F);
  static const Color secondary = Color(0xFF26a69a);
  static const Color accent = Color(0xFFffc107);
  
  // Border colors
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  
  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  
  // Shadow colors
  static const Color shadow = Color(0x1A000000);
  static const Color shadowLight = Color(0x0D000000);
}

/// Primary brand colors - Dark Mode
class DarkColors {
  // Background colors
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color card = Color(0xFF242424);
  
  // Text colors
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textHint = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF4B5563);
  
  // Brand colors (adjusted for dark mode)
  static const Color primary = Color(0xFF3A5A88);
  static const Color primaryLight = Color(0xFF4A6A98);
  static const Color primaryDark = Color(0xFF2A4A78);
  static const Color secondary = Color(0xFF40C4B4);
  static const Color accent = Color(0xFFFFD54F);
  
  // Border colors
  static const Color border = Color(0xFF374151);
  static const Color borderLight = Color(0xFF2D3748);
  
  // Status colors (adjusted for dark mode)
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFF87171);
  static const Color info = Color(0xFF60A5FA);
  
  // Shadow colors
  static const Color shadow = Color(0x4D000000);
  static const Color shadowLight = Color(0x33000000);
}

/// Legacy color support - deprecated, use LightColors or DarkColors instead
class PrimaryColors {
  static const Color darkBlue = Color(0xFF001B38);
  static const Color lightBlue = Color(0xFF00274D);
  static const Color light = Color(0xFF3a5a88);
  static const Color brightYellow = Color(0xFFffc107);
  static const Color greenBlue = Color(0xFF26a69a);
}

/// Helper class to get colors based on theme brightness
class AppColors {
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.background
        : LightColors.background;
  }
  
  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.surface
        : LightColors.surface;
  }
  
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.card
        : LightColors.card;
  }
  
  static Color getTextPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.textPrimary
        : LightColors.textPrimary;
  }
  
  static Color getTextSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.textSecondary
        : LightColors.textSecondary;
  }
  
  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.primary
        : LightColors.primary;
  }
  
  static Color getSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.secondary
        : LightColors.secondary;
  }
  
  static Color getAccentColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.accent
        : LightColors.accent;
  }
  
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.border
        : LightColors.border;
  }
  
  static Color getSuccessColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.success
        : LightColors.success;
  }
  
  static Color getWarningColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.warning
        : LightColors.warning;
  }
  
  static Color getErrorColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.error
        : LightColors.error;
  }
  
  static Color getInfoColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.info
        : LightColors.info;
  }
}
