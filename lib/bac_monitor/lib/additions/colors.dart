import 'package:flutter/material.dart';

/// Primary brand colors - Light Mode (White Theme)
class LightColors {
  // Background colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFF4F6F8);
  static const Color card = Color(0xFFFFFFFF);

  // Text colors (IMPROVED)
  static const Color textPrimary = Color(
    0xFF0F172A,
  ); // deep slate (better than pure black)
  static const Color textSecondary = Color(0xFF475569); // medium contrast
  static const Color textHint = Color(0xFF94A3B8); // soft hint
  static const Color textDisabled = Color(0xFFCBD5E1); // lighter disabled

  // Brand colors
  static const Color primary = Color(0xFF0F172A);
  static const Color primaryLight = Color(0xFF334155);
  static const Color primaryDark = Color(0xFF020617);

  static const Color secondary = Color(0xFF14B8A6); // modern teal
  static const Color accent = Color(0xFFF59E0B); // softer amber

  // Borders
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Shadows
  static const Color shadow = Color(0x14000000);
  static const Color shadowLight = Color(0x0A000000);
}

/// Primary brand colors - Dark Mode
class DarkColors {
  // Background colors (LESS harsh than pure black)
  static const Color background = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF12171D);
  static const Color card = Color(0xFF1A2128);

  // Text colors (BIG IMPROVEMENT)
  static const Color textPrimary = Color(0xFFF1F5F9); // soft white
  static const Color textSecondary = Color(0xFFCBD5E1); // readable gray
  static const Color textHint = Color(0xFF94A3B8); // subtle hint
  static const Color textDisabled = Color(0xFF64748B); // dim but visible

  // Brand colors
  static const Color primary = Color(0xFFF1F5F9);
  static const Color primaryLight = Color(0xFFE2E8F0);
  static const Color primaryDark = Color(0xFF020617);

  static const Color secondary = Color(
    0xFF2DD4BF,
  ); // brighter teal (pops on dark)
  static const Color accent = Color(0xFFFBBF24); // warm gold

  // Borders
  static const Color border = Color(0xFF2A3441);
  static const Color borderLight = Color(0xFF1E293B);

  // Status
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFF87171);
  static const Color info = Color(0xFF60A5FA);

  // Shadows
  static const Color shadow = Color(0x66000000);
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

  static Color getTextDisabledColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.textDisabled
        : LightColors.textDisabled;
  }

  static Color getTextHintColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.textHint
        : LightColors.textHint;
  }

  static Color getShadowColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.shadow
        : LightColors.shadow;
  }

  static Color getShadowLightColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.shadowLight
        : LightColors.shadowLight;
  }

  static Color getBorderLightColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.borderLight
        : LightColors.borderLight;
  }

  static Color getPrimaryLightColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.primaryLight
        : LightColors.primaryLight;
  }

  static Color getPrimaryDarkColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkColors.primaryDark
        : LightColors.primaryDark;
  }
}
