import 'package:get/get.dart';
import '../db/db_helper.dart';

class OperatorController extends GetxController {
  final dbHelper = DatabaseHelper();

  var companyName = "Loading...".obs;
  var companyAddress = "".obs;

  @override
  void onInit() {
    super.onInit();
    loadCompanyDetailsFromDb();
  }

  /// Fetches the company details from the local database.
  Future<void> loadCompanyDetailsFromDb() async {
    try {
      final db = await dbHelper.database;

      final result = await db.query('company_details', limit: 1);

      if (result.isNotEmpty) {
        final details = result.first;
        companyName.value =
            details['activeBranchName'] as String? ?? 'Main branch';

        companyAddress.value =
            details['activeBranchAddress'] as String? ?? 'No Address Provided';
      } else {
        companyName.value = 'Welcome';
        companyAddress.value = '';
      }
    } catch (e) {
      print("Error loading company details from DB: $e");
      companyName.value = 'Error Loading Details';
      companyAddress.value = '';
    }
  }

  Future <void> intitialiselabels() async {

  }
}
