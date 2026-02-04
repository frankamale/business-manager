class FlavorConfig {
  static const String flavorName = String.fromEnvironment('FLAVOR', defaultValue: 'default');
  static const String appName = String.fromEnvironment('APP_NAME', defaultValue: 'Business Manager');
  static const String companyName = String.fromEnvironment('COMPANY_NAME', defaultValue: 'Default Company');
  static const String botUsername = String.fromEnvironment('BOT_USERNAME');
  static const String botPassword = String.fromEnvironment('BOT_PASSWORD');

  static String get logoPath => 'assets/flavors/$flavorName/logo.png';
  static const String fallbackLogoPath = 'assets/images/logo.png';
}
