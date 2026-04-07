import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared utility for credential storage and validation.
/// Consolidates duplicate credential logic from splashscreen, splash_page, and unified_login_screen.
class CredentialHelper {
  static const String _usernameKey = 'login_username';
  static const String _passwordKey = 'login_password';

  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
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
