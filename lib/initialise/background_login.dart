import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:bac_pos/back_pos/config.dart';
import 'package:bac_pos/back_pos/controllers/auth_controller.dart';
import 'package:bac_pos/bac_monitor/lib/services/api_services.dart';
import 'package:bac_pos/shared/services/credential_helper.dart';

/// Signs in to the server in the background using the inbuilt build-time
/// credentials (--dart-define=AUTO_LOGIN_USERNAME / AUTO_LOGIN_PASSWORD) so
/// the server login screen is never shown. On success the same session keys
/// a manual login stores are written, so subsequent opens reuse the session
/// and the app lands straight on the POS login screen.
class BackgroundLogin {
  /// Returns true when a server session exists (already stored or freshly
  /// created). Never throws.
  static Future<bool> run() async {
    if (!AppConfig.hasAutoLogin) return false;

    try {
      if (await _hasSession()) return true;

      final authController = Get.find<AuthController>();
      final result = await authController.serverLogin(
        AppConfig.autoLoginUsername,
        AppConfig.autoLoginPassword,
      );
      if (result == null) return false;

      final companyId = result['companyId'] as String;
      final token = result['token'] as String;
      final userData = result['userData'] as Map<String, dynamic>;
      final username = result['username'] as String;
      final password = result['password'] as String;
      final roles = userData['roles'] as List<dynamic>?;

      await CredentialHelper.storeCredentials(username, password);

      final box = GetStorage();
      await box.write('last_company_id', companyId);
      await box.write('last_username', username);
      final role = CredentialHelper.shouldUseMonitorFromRoles(roles, username)
          ? 'admin'
          : 'staff';
      await box.write('last_user_role', role);
      await CredentialHelper.storeUserRole(role);

      // Session keys checked by SplashScreen._hasValidCredentials on open.
      final monitorApi = Get.find<MonitorApiService>();
      await monitorApi.storeToken(token);
      await monitorApi.storeCompanyId(companyId);
      await monitorApi.storeUserData({...userData, 'companyId': companyId});
      await monitorApi.saveServerCredentials(username, password);

      debugPrint(
        'BackgroundLogin: Inbuilt login completed (company: $companyId)',
      );
      return true;
    } catch (e) {
      debugPrint('BackgroundLogin: Inbuilt login failed - $e');
      return false;
    }
  }

  static Future<bool> _hasSession() async {
    final hasCredentials = await CredentialHelper.hasStoredCredentials();
    if (!hasCredentials) return false;

    final monitorApi = Get.find<MonitorApiService>();
    final token = await monitorApi.getStoredToken();
    final companyId = await monitorApi.getStoredCompanyId();
    return token != null &&
        token.isNotEmpty &&
        companyId != null &&
        companyId.isNotEmpty;
  }
}
