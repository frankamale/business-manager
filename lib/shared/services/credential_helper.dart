import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bac_pos/back_pos/config.dart';

/// Shared utility for credential storage and validation.
/// Consolidates duplicate credential logic from splashscreen, splash_page, and unified_login_screen.
class CredentialHelper {
  static const String _usernameKey = 'login_username';
  static const String _passwordKey = 'login_password';

  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Retrieve stored credentials from FlutterSecureStorage
  static Future<Map<String, String?>> getStoredCredentials() async {
    try {
      final results = await Future.wait([
        _secureStorage.read(key: _usernameKey),
        _secureStorage.read(key: _passwordKey),
      ]);
      return {'username': results[0], 'password': results[1]};
    } catch (e) {
      debugPrint('CredentialHelper: Error retrieving stored credentials - $e');
      return {'username': null, 'password': null};
    }
  }

  /// Store credentials securely
  static Future<void> storeCredentials(String username, String password) async {
    await Future.wait([
      _secureStorage.write(key: _usernameKey, value: username),
      _secureStorage.write(key: _passwordKey, value: password),
    ]);
  }

  /// Clear stored credentials
  static Future<void> clearCredentials() async {
    await Future.wait([
      _secureStorage.delete(key: _usernameKey),
      _secureStorage.delete(key: _passwordKey),
    ]);
  }

  /// Check if stored credentials exist
  static Future<bool> hasStoredCredentials() async {
    try {
      final credentials = await getStoredCredentials();
      return credentials['username'] != null &&
          credentials['username']!.isNotEmpty &&
          credentials['password'] != null &&
          credentials['password']!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if a role string indicates admin access
  static bool isAdminRole(String? role) {
    if (role == null || role.isEmpty) return false;
    return role.toLowerCase().contains('admin');
  }

  /// Check if any role in a list indicates admin access
  static bool isAdminFromRoles(List<dynamic>? roles) {
    if (roles == null || roles.isEmpty) return false;
    return roles.any((role) => role.toString().toLowerCase().contains('admin'));
  }

  /// Check if a username should be forced into the POS regardless of roles.
  /// Controlled by [AppConfig.enableUsernamePosFiltering] and matched against
  /// [AppConfig.posUsernameKeywords] (e.g. 'cashier', 'br').
  static bool isPosUsername(String? username) {
    if (!AppConfig.enableUsernamePosFiltering) return false;
    if (username == null || username.isEmpty) return false;
    final lower = username.toLowerCase();
    return AppConfig.posUsernameKeywords
        .any((keyword) => lower.contains(keyword.toLowerCase()));
  }

  /// Decide whether a user with the given [roles] and [username] should land on
  /// the Monitor. Username-based POS filtering (when enabled) overrides admin
  /// roles, so a cashier/branch account always goes to the POS.
  static bool shouldUseMonitorFromRoles(List<dynamic>? roles, String? username) {
    if (isPosUsername(username)) return false;
    return isAdminFromRoles(roles);
  }

  /// Same as [shouldUseMonitorFromRoles] but for a single stored role string
  /// (used by the auto-login / splash flow).
  static bool shouldUseMonitorFromRole(String? role, String? username) {
    if (isPosUsername(username)) return false;
    return isAdminRole(role);
  }

  /// Get user role from secure storage
  static Future<String?> getUserRole() async {
    try {
      return await _secureStorage.read(key: 'user_role');
    } catch (e) {
      debugPrint('CredentialHelper: Error reading user role - $e');
      return null;
    }
  }

  /// Store user role in secure storage
  static Future<void> storeUserRole(String role) async {
    await _secureStorage.write(key: 'user_role', value: role);
  }
}
