import 'package:get/get.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../services/account_manager.dart';

class MonOperatorController extends GetxController {
  final dbHelper = UnifiedDatabaseHelper.instance;
  late final AccountManager _accountManager;

  var companyName = "Loading...".obs;
  var companyAddress = "".obs;

  @override
  void onInit() {
    super.onInit();
    print('MonOperatorController onInit called');

    try {
      _accountManager = Get.find<AccountManager>();
    } catch (e) {
      print('AccountManager not available yet: $e');
      return;
    }

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
    print('MonOperatorController: loadCompanyDetailsFromDb called');
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
      print('MonOperatorController: Query result length: ${result.length}');

      if (result.isNotEmpty) {
        final details = result.first;
        print('MonOperatorController: Loaded row: $details');
        print('MonOperatorController: activeBranchName=${details['activeBranchName']}, activeBranchAddress=${details['activeBranchAddress']}');

        // Prefer the real company name (activeBranch.company.name), then the
        // branch name, then a hard-coded fallback.
        final realCompanyName = details['companyName'] as String?;
        final branchName = details['activeBranchName'] as String?;
        if (realCompanyName != null && realCompanyName.trim().isNotEmpty) {
          companyName.value = realCompanyName;
        } else if (branchName != null && branchName.trim().isNotEmpty) {
          companyName.value = branchName;
        } else {
          companyName.value = 'Komusoft Solutions LTD';
        }

        final address = details['activeBranchAddress'] as String?;
        companyAddress.value =
            (address != null && address.trim().isNotEmpty) ? address : 'No Address Provided';
        print('MonOperatorController: Company name set to ${companyName.value}, address set to ${companyAddress.value}');
      } else {
        companyName.value = 'Komusoft Solutions LTD';
        companyAddress.value = '';
        print('MonOperatorController: No company details found, using fallback name');
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