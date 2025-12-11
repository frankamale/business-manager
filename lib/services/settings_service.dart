import 'package:get_storage/get_storage.dart';

class SettingsService {
  static const String _autoUploadKey = 'auto_upload_sales';
  final GetStorage _box = GetStorage();
  
  bool getAutoUploadEnabled() {
    return _box.read(_autoUploadKey) ?? true; 
  }
  
  void setAutoUploadEnabled(bool enabled) {
    _box.write(_autoUploadKey, enabled);
  }
}