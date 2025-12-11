import 'package:get/get.dart';
import '../services/settings_service.dart';

class SettingsController extends GetxController {
  final SettingsService _settingsService = SettingsService();
  RxBool autoUploadEnabled = false.obs;

  @override
  void onInit() {
    super.onInit();
    autoUploadEnabled.value = _settingsService.getAutoUploadEnabled();
  }

  void toggleAutoUpload(bool value) {
    autoUploadEnabled.value = value;
    _settingsService.setAutoUploadEnabled(value);
    Get.snackbar('Settings', 'Auto upload ${value ? 'enabled' : 'disabled'}');
  }
}