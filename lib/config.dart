

class AppConfig {
// authentication credentials
  static const String defaultUsername = 'admin@sdry.com';
  static const String defaultPassword = 'Admin@2025';


  static const String baseUrl = "http://52.30.142.12:8080/rest";


  // APPLICATION SETTINGS

  static const String appName = 'BAC POS';

  /// Company name displayed in the splash screen
  static const String companyName = 'Komusoft Solutions';

  /// Edition/version info
  static const String edition = 'Uganda Edition';

  /// Copyright text
  static const String copyright = '© 2024 Komusoft Solutions';


  /// Primary color theme (used in gradients and branding)
  static const int primaryColorValue = 0xFF1976D2; // Blue shade 700

  /// Secondary color theme
  static const int secondaryColorValue = 0xFF42A5F5; // Blue shade 400

  /// Accent color theme
  static const int accentColorValue = 0xFF81D4FA; // Cyan shade 300

  /// Splash screen animation duration in milliseconds
  static const int splashAnimationDuration = 1500;

  static const int navigationDelay = 800;

  /// Retry delay for failed connections (seconds)
  static const int retryDelaySeconds = 3;


  /// Enable/disable offline mode capabilities
  static const bool enableOfflineMode = true;

  /// Enable/disable automatic data synchronization on startup
  static const bool enableAutoSync = true;

  /// Enable/disable debug logging
  static const bool enableDebugLogging = true;

  /// Default currency for the application
  static const String defaultCurrency = 'UGX';

  /// Currency display name
  static const String currencyDisplayName = 'Uganda Shillings';

  /// Receipt number prefix
  static const String receiptPrefix = 'REC-';

  /// Receipt number padding length
  static const int receiptNumberPadding = 4;
}