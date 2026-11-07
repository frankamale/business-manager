import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';
import 'package:bac_pos/initialise/app_roots.dart';
import 'package:bac_pos/initialise/splashscreen.dart' show kLastCompanyIdKey;
import 'package:bac_pos/bac_monitor/lib/services/api_services.dart';
import 'package:bac_pos/shared/services/credential_helper.dart';

class SettingsService {
  static const String _autoUploadKey = 'auto_upload_sales';
  static const String _paymentAccessKey = 'payment_access_all_users';
  static const String _priceEditingKey = 'price_editing_enabled';
  static const String _posCashAccountKey = 'pos_cash_account_id';
  final GetStorage _box = GetStorage();

  /// The cash account chosen for POS payments, or null to use the default
  /// (the Kitchen account).
  String? getPosCashAccountId() {
    return _box.read(_posCashAccountKey) as String?;
  }

  void setPosCashAccountId(String? id) {
    if (id == null) {
      _box.remove(_posCashAccountKey);
    } else {
      _box.write(_posCashAccountKey, id);
    }
  }

  bool getAutoUploadEnabled() {
    return _box.read(_autoUploadKey) ?? true;
  }

  void setAutoUploadEnabled(bool enabled) {
    _box.write(_autoUploadKey, enabled);
  }

  bool getPaymentAccessForAllUsers() {
    return _box.read(_paymentAccessKey) ?? false;
  }

  void setPaymentAccessForAllUsers(bool enabled) {
    _box.write(_paymentAccessKey, enabled);
  }

  bool getPriceEditingEnabled() {
    return _box.read(_priceEditingKey) ?? false;
  }

  void setPriceEditingEnabled(bool enabled) {
    _box.write(_priceEditingKey, enabled);
  }

  /// Jump straight to the Monitor, regardless of the logged-in user's role.
  /// If no monitor session exists yet, the app signs in silently with the
  /// stored server credentials before navigating.
  Future<void> navigateToMonitorApp() async {
    try {
      final monitorApi = Get.find<MonitorApiService>();
      final token = await monitorApi.getStoredToken();
      if (token == null || token.isEmpty) {
        final credentials = await CredentialHelper.getStoredCredentials();
        final username = credentials['username'];
        final password = credentials['password'];
        if (username != null &&
            username.isNotEmpty &&
            password != null &&
            password.isNotEmpty) {
          await monitorApi.login(username, password);
        }
        final companyId = await monitorApi.getStoredCompanyId() ??
            _box.read(kLastCompanyIdKey) as String?;
        if (companyId != null && companyId.isNotEmpty) {
          await monitorApi.storeCompanyId(companyId);
        }
      }
    } catch (e) {
      // Fall through - the monitor splash shows its own login if the silent
      // sign-in could not establish a session.
      debugPrint('SettingsService: Silent monitor sign-in failed - $e');
    }
    Get.offAll(() => const MonitorAppRoot());
  }
}