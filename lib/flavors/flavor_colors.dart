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
  final Color? primaryPlus;

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
    this.primaryPlus,
  });

  /// Gradient for full-page backgrounds (top to bottom)
  List<Color> get backgroundGradient => [primary, tertiary, light];

  /// Gradient for cards (top-left to bottom-right)
  List<Color> get cardGradient => [secondary, primaryDark];

  /// Shadow color with opacity
  Color get shadowColor => primary.withValues(alpha: 0.3);
}

class Palettes {
  Palettes._();

  static const blue = FlavorColorPalette(
    primary: Color(0xFF1565C0),
    primaryDark: Color(0xFF0D47A1),
    secondary: Color(0xFF1E88E5),
    tertiary: Color(0xFF42A5F5),
    light: Color(0xFF90CAF9),
    surface: Color(0xFFE3F2FD),
    icon: Color(0xFF0D47A1),
    onPrimary: Colors.white,
    background: Color(0xFFF9FAFB),
    primaryPlus: Color(0xFF222222),
  );

  static const darkBlue = FlavorColorPalette(
    primary: Color(0xFF0D47A1),
    primaryDark: Color(0xFF002171),
    secondary: Color(0xFF1565C0),
    tertiary: Color(0xFF1976D2),
    light: Color(0xFF64B5F6),
    surface: Color(0xFFE3F2FD),
    icon: Color(0xFF002171),
    onPrimary: Colors.white,
    background: Color(0xFFF5F7FA),
    primaryPlus: Color(0xFF222222),
  );

  static const green = FlavorColorPalette(
    primary: Color(0xFF2E7D32),
    primaryDark: Color(0xFF1B5E20),
    secondary: Color(0xFF43A047),
    tertiary: Color(0xFF66BB6A),
    light: Color(0xFFA5D6A7),
    surface: Color(0xFFE8F5E9),
    icon: Color(0xFF1B5E20),
    onPrimary: Colors.white,
    background: Color(0xFFF9FAFB), 
    primaryPlus: Color(0xFFBC0000),
  );

  static const darkGreen = FlavorColorPalette(
    primary: Color(0xFF1B5E20),
    primaryDark: Color(0xFF003300),
    secondary: Color(0xFF2E7D32),
    tertiary: Color(0xFF388E3C),
    light: Color(0xFF81C784),
    surface: Color(0xFFE8F5E9),
    icon: Color(0xFF003300),
    onPrimary: Colors.white,
    background: Color(0xFFF5F7F5),
    primaryPlus: Color(0xFF222222),
  );

  static const red = FlavorColorPalette(
    primary: Color(0xFFC62828),
    primaryDark: Color(0xFFB71C1C),
    secondary: Color(0xFFE53935),
    tertiary: Color(0xFFEF5350),
    light: Color(0xFFEF9A9A),
    surface: Color(0xFFFFEBEE),
    icon: Color(0xFFB71C1C),
    onPrimary: Colors.white,
    background: Color(0xFFFAF9F9),
    primaryPlus: Color(0xFF222222),
  );

  static const yellow = FlavorColorPalette(
    primary: Color(0xFFF9A825),
    primaryDark: Color(0xFFF57F17),
    secondary: Color(0xFFFBC02D),
    tertiary: Color(0xFFFFCA28),
    light: Color(0xFFFFF176),
    surface: Color(0xFFFFFDE7),
    icon: Color(0xFFF57F17),
    onPrimary: Color(0xFF212121),
    background: Color(0xFFFFFDF5),
    primaryPlus: Color(0xFF222222),
  );

  static const orange = FlavorColorPalette(
    primary: Color(0xFFEF6C00),
    primaryDark: Color(0xFFE65100),
    secondary: Color(0xFFF57C00),
    tertiary: Color(0xFFFB8C00),
    light: Color(0xFFFFCC80),
    surface: Color(0xFFFFF3E0),
    icon: Color(0xFFE65100),
    onPrimary: Colors.white,
    background: Color(0xFFFFFAF5),
    primaryPlus: Color(0xFF222222),
  );

  static const purple = FlavorColorPalette(
    primary: Color(0xFF7B1FA2),
    primaryDark: Color(0xFF6A1B9A),
    secondary: Color(0xFF8E24AA),
    tertiary: Color(0xFFAB47BC),
    light: Color(0xFFBA68C8),
    surface: Color(0xFFF3E5F5),
    icon: Color(0xFF4A148C),
    onPrimary: Colors.white,
    background: Color(0xFFF5F5F5),
    primaryPlus: Color(0xFF222222),
  );

  static const grey = FlavorColorPalette(
    primary: Color(0xFF455A64),
    primaryDark: Color(0xFF37474F),
    secondary: Color(0xFF546E7A),
    tertiary: Color(0xFF78909C),
    light: Color(0xFFB0BEC5),
    surface: Color(0xFFECEFF1),
    icon: Color(0xFF263238),
    onPrimary: Colors.white,
    background: Color(0xFFFAFAFA),
    primaryPlus: Color(0xFF222222),
  );

  static const black = FlavorColorPalette(
    primary: Color(0xFF212121),
    primaryDark: Color(0xFF000000),
    secondary: Color(0xFF424242),
    tertiary: Color(0xFF616161),
    light: Color(0xFF9E9E9E),
    surface: Color(0xFFF5F5F5),
    icon: Color(0xFF000000),
    onPrimary: Colors.white,
    background: Color(0xFFFAFAFA),
    primaryPlus: Color(0xFF222222),
  );

  static const teal = FlavorColorPalette(
    primary: Color(0xFF00796B),
    primaryDark: Color(0xFF004D40),
    secondary: Color(0xFF00897B),
    tertiary: Color(0xFF26A69A),
    light: Color(0xFF80CBC4),
    surface: Color(0xFFE0F2F1),
    icon: Color(0xFF004D40),
    onPrimary: Colors.white,
    background: Color(0xFFF5FAFA),
    primaryPlus: Color(0xFF222222),
  );

  static const pink = FlavorColorPalette(
    primary: Color(0xFFC2185B),
    primaryDark: Color(0xFF880E4F),
    secondary: Color(0xFFD81B60),
    tertiary: Color(0xFFEC407A),
    light: Color(0xFFF48FB1),
    surface: Color(0xFFFCE4EC),
    icon: Color(0xFF880E4F),
    onPrimary: Colors.white,
    background: Color(0xFFFFF5F7),
    primaryPlus: Color(0xFF222222),
  );
  static const white = FlavorColorPalette(
    primary: Color(0xFFFFFFFF),
    // Pure white
    primaryDark: Color(0xFFF5F5F5),
    // Slight grey for contrast
    secondary: Color(0xFFE0E0E0),
    // Light grey accents
    tertiary: Color(0xFFBDBDBD),
    // Medium grey for depth
    light: Color(0xFFFFFFFF),

    // Still white
    surface: Color(0xFFF9F9F9),
    // Soft surface white
    icon: Color(0xFF212121),

    // Dark icons for visibility
    onPrimary: Color(0xFF212121),
    // Dark text on white
    background: Color(0xFFFFFFFF),
    // Full white background
    primaryPlus: Color(0xFF222222),
  );

  /// All available palettes by name
  static const Map<String, FlavorColorPalette> all = {
    'blue': blue,
    'darkBlue': darkBlue,
    'green': green,
    'darkGreen': darkGreen,
    'red': red,
    'yellow': yellow,
    'orange': orange,
    'purple': purple,
    'grey': grey,
    'black': black,
    'teal': teal,
    'pink': pink,
  };

  /// Get a palette by name, defaults to blue
  static FlavorColorPalette getByName(String name) {
    return all[name] ?? blue;
  }
}

class FlavorColors {
  FlavorColors._();

  /// Map company/flavor names to their palette
  static const Map<String, FlavorColorPalette> _companyPalettes = {
    'komusoft': Palettes.blue,
    'sassy': Palettes.purple,
    'top_grade': Palettes.orange,
    'mega': Palettes.green,
  };

  /// Get the color palette for the current flavor/company
  static FlavorColorPalette get current {
    return _companyPalettes[FlavorConfig.flavorName] ?? Palettes.blue;
  }

  /// Get color palette by company/flavor name
  static FlavorColorPalette getByName(String flavorName) {
    return _companyPalettes[flavorName] ?? Palettes.blue;
  }

  /// Assign a palette to a company at runtime
  static final Map<String, FlavorColorPalette> _runtimePalettes = {};

  static void assignPalette(String companyName, FlavorColorPalette palette) {
    _runtimePalettes[companyName] = palette;
  }

  /// Get palette with runtime overrides taking priority
  static FlavorColorPalette getForCompany(String companyName) {
    return _runtimePalettes[companyName] ??
        _companyPalettes[companyName] ??
        Palettes.blue;
  }
}
