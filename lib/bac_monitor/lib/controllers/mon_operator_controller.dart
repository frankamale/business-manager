import 'package:get/get.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../services/account_manager.dart';

class MonOperatorController extends GetxController {
  final dbHelper = UnifiedDatabaseHelper.instance;
  final AccountManager _accountManager = Get.find();

  var companyName = "Loading...".obs;
  var companyAddress = "".obs;

  @override
  void onInit() {
    super.onInit();

    _tryLoadCompanyDetails();

    // Listen to account changes and refresh company data
    ever(_accountManager.currentAccount, (UserAccount? account) {
      if (account != null) {
        loadCompanyDetailsFromDb();
      }
    });
  }

  /// Try to load company details if database is ready
  Future<void> _tryLoadCompanyDetails() async {
    if (dbHelper.isDatabaseOpen) {
      await loadCompanyDetailsFromDb();
    } else {
      print('MonOperatorController: Database not open yet, skipping initial load');
    }
  }

  /// Fetches the company details from the local database.
  Future<void> loadCompanyDetailsFromDb() async {
    // Check if database is open before accessing
    if (!dbHelper.isDatabaseOpen) {
      print('MonOperatorController: Database not open, cannot load company details');
      companyName.value = 'Loading...';
      companyAddress.value = '';
      return;
    }

    try {
      final db = dbHelper.database;

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