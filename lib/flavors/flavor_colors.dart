import 'package:flutter/material.dart';
import 'flavor_config.dart';

/// Color palette for a flavor theme
class FlavorColorPalette {
  final Color primary;
  final Color primaryDark;
  final Color secondary;
  final Color tertiary;
  final Color light;
  final Color surface;
  final Color icon;
  final Color onPrimary;
  final Color background;

  const FlavorColorPalette({
    required this.primary,
    required this.primaryDark,
    required this.secondary,
    required this.tertiary,
    required this.light,
    required this.surface,
    required this.icon,
    required this.onPrimary,
    required this.background,
  });

  /// Gradient for full-page backgrounds (top to bottom)
  List<Color> get backgroundGradient => [primary, tertiary, light];

  /// Gradient for cards (top-left to bottom-right)
  List<Color> get cardGradient => [secondary, primaryDark];

  /// Shadow color with opacity
  Color get shadowColor => primary.withValues(alpha: 0.3);
}

/// Flavor color definitions
class FlavorColors {
  FlavorColors._();

  /// Komusoft flavor - Blue theme (default)
  static const komusoft = FlavorColorPalette(
    primary: Color(0xFF1976D2),      // Colors.blue.shade700
    primaryDark: Color(0xFF1565C0),  // Colors.blue.shade800
    secondary: Color(0xFF1E88E5),    // Colors.blue.shade600
    tertiary: Color(0xFF42A5F5),     // Colors.blue.shade400
    light: Color(0xFF64B5F6),        // Colors.blue.shade300
    surface: Color(0xFFE3F2FD),      // Colors.blue.shade50
    icon: Color(0xFF0D47A1),         // Colors.blue.shade900
    onPrimary: Colors.white,
    background: Color(0xFFF5F5F5),   // Colors.grey.shade100
  );

  /// Sassy flavor - Add your colors here
  /// Example with purple theme:
  // static const sassy = FlavorColorPalette(
  //   primary: Color(0xFF7B1FA2),      // Colors.purple.shade700
  //   primaryDark: Color(0xFF6A1B9A),  // Colors.purple.shade800
  //   secondary: Color(0xFF8E24AA),    // Colors.purple.shade600
  //   tertiary: Color(0xFFAB47BC),     // Colors.purple.shade400
  //   light: Color(0xFFBA68C8),        // Colors.purple.shade300
  //   surface: Color(0xFFF3E5F5),      // Colors.purple.shade50
  //   icon: Color(0xFF4A148C),         // Colors.purple.shade900
  //   onPrimary: Colors.white,
  //   background: Color(0xFFF5F5F5),   // Colors.grey.shade100
  // );

  /// Get the color palette for the current flavor
  static FlavorColorPalette get current {
    switch (FlavorConfig.flavorName) {
      case 'komusoft':
        return komusoft;
      // case 'sassy':
      //   return sassy;
      default:
        return komusoft;
    }
  }

  /// Get color palette by flavor name
  static FlavorColorPalette getByName(String flavorName) {
    switch (flavorName) {
      case 'komusoft':
        return komusoft;
      // case 'sassy':
      //   re
    //   turn sassy;
      default:
        return komusoft;
    }
  }
}
