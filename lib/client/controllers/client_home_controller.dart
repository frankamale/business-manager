import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../services/otp_generator.dart';

class ClientHomeController extends GetxController {
  final box = GetStorage();

  var otp = ''.obs;
  var isGenerating = false.obs;

  Map<String, dynamic> get customerData =>
      box.read('logged_in_customer') ?? {};

  String get fullName => customerData['fullnames'] ?? 'Customer';
  String get email => customerData['email'] ?? '';
  String get phone => customerData['phone1'] ?? '';
  String get odoo_id => customerData['odoo_id'] ?? '';
  double get bonusPoints =>
      double.tryParse(customerData['bonus_points']?.toString() ?? '0') ?? 0.0;
  String get status => customerData['status'] ?? 'Active';

  @override
  void onInit() {
    super.onInit();
    generateOtp();
  }

  /// Generate OTP
  void generateOtp() {
    isGenerating.value = true;

    final userId = odoo_id.isNotEmpty ? odoo_id : fullName;

    // Generate OTP using TOTP algorithm
    final otpNumber = generateTOTP(uuid: userId);

    otp.value = '${otpNumber.substring(0, 3)} ${otpNumber.substring(3)}';

    isGenerating.value = false;
  }

}
