import 'package:get_storage/get_storage.dart';

class SettingsService {
  static const String _autoUploadKey = 'auto_upload_sales';
  static const String _paymentAccessKey = 'payment_access_all_users';
  static const String _priceEditingKey = 'price_editing_enabled';
  final GetStorage _box = GetStorage();

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
}