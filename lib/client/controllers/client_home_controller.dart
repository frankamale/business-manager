import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

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

  /// Generate OTP based on timestamp and user ID
  void generateOtp() {
    isGenerating.value = true;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final userId = odoo_id.isNotEmpty ? odoo_id : fullName;

    // Create a hash-like value from timestamp and userId
    int hash = 0;
    final combined = '$timestamp$userId';
    for (int i = 0; i < combined.length; i++) {
      hash = ((hash << 5) - hash + combined.codeUnitAt(i)) & 0xFFFFFFFF;
    }

    // Convert to 6-digit OTP
    final otpNumber = (hash.abs() % 1000000).toString().padLeft(6, '0');

    // Format as "XXX XXX"
    otp.value = '${otpNumber.substring(0, 3)} ${otpNumber.substring(3)}';

    isGenerating.value = false;
  }
}
