import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:bac_pos/back_pos/models/expense.dart';
import 'package:bac_pos/shared/database/unified_db_helper.dart';
import 'package:bac_pos/back_pos/services/api_services.dart';

class ExpensesController extends GetxController {
  final _uuid = const Uuid();
  final _db = UnifiedDatabaseHelper.instance;
  final _apiService = Get.find<PosApiService>();

  // Reactive list of expenses
  var expenses = <Expense>[].obs;

  // Current service point ID for filtering
  var currentServicePointId = Rxn<String>();

  // Loading state
  var isLoading = false.obs;

  // Cash accounts for currency and account selection
  var cashAccounts = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    // Load expenses from database
    loadExpensesFromDatabase();
    // Load cash accounts for API calls
    loadCashAccounts();
  }

  Future<void> loadExpensesFromDatabase() async {
    isLoading.value = true;
    try {
      final dbExpenses = await _db.getExpenses();
      if (dbExpenses.isNotEmpty) {
        expenses.value = dbExpenses;
      } else {
        // If no expenses in database, load sample data and save it
        _loadSampleExpenses();
        await _saveAllExpensesToDatabase();
      }
    } catch (e) {
      // If database is not open, load sample data
      _loadSampleExpenses();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadCashAccounts() async {
    try {
      final accounts = await _apiService.fetchCashAccounts();
      cashAccounts.value = accounts;
    } catch (e) {
      // If failed to load, continue with empty list
      cashAccounts.value = [];
    }
  }

  Future<void> _saveAllExpensesToDatabase() async {
    for (final expense in expenses) {
      await _db.insertExpense(expense);
    }
  }

  void _loadSampleExpenses() {
    final now = DateTime.now();
    expenses.value = [
      Expense(
        id: _uuid.v4(),
        title: 'Office Supplies Purchase',
        description: 'Office supplies',
        amount: 50000,
        category: ExpenseCategory.supplies,
        date: now.subtract(const Duration(days: 1)),
      ),
      Expense(
        id: _uuid.v4(),
        title: 'Market Transport',
        description: 'Transport to market',
        amount: 30000,
        category: ExpenseCategory.transport,
        date: now.subtract(const Duration(days: 2)),
      ),
      Expense(
        id: _uuid.v4(),
        title: 'Electricity Bill Payment',
        description: 'Electricity bill',
        amount: 150000,
        category: ExpenseCategory.utilities,
        date: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  Map<String, dynamic> _getDefaultCashAccount() {
    if (cashAccounts.isEmpty) {
      // Return hardcoded defaults if no accounts loaded
      return {
        'id': '11111111-1111-1111-1111-111111111111',
        'currencyid': '3a0e97b4-c13a-4a49-9205-182e62039a5a',
        'currency': 'Uganda Shillings',
      };
    }
    // Use the first cash account
    final account = cashAccounts.first;
    return {
      'id': account['id'] ?? '11111111-1111-1111-1111-111111111111',
      'currencyid': account['currencyid'] ?? '3a0e97b4-c13a-4a49-9205-182e62039a5a',
      'currency': account['currency'] ?? 'Uganda Shillings',
    };
  }

  // Add a new expense
  Future<void> addExpense({
    required String title,
    required String description,
    required double amount,
    required String category,
    DateTime? date,
    String? servicePointId,
    String? subject,
    String? selectedStaffId,
  }) async {
    final expenseId = _uuid.v4();
    final expenseDate = date ?? DateTime.now();

    // Get cash account details
    final cashAccount = _getDefaultCashAccount();
    final currentSpId = servicePointId ?? currentServicePointId.value ?? '';

    // Prepare API payload
    final paymentData = {
      "adhoc": "false",
      "currencyid": cashAccount['currencyid'],
      "bpid": selectedStaffId ?? '',
      "servicepointid": currentSpId,
      "transactiontypeid": 1,
      "amount": amount.toStringAsFixed(0),
      "methodId": "1",
      "chequeno": "XXX",
      "cashaccountid": cashAccount['id'],
      "paydate": "${expenseDate.year}-${expenseDate.month.toString().padLeft(2, '0')}-${expenseDate.day.toString().padLeft(2, '0')}",
      "payref": title,
      "receipt": "false",
      "remarks": description,
      "direction": "1",
      "gLProxySubCategoryId": "55555555-5555-5555-5555-555555555555"
    };

    try {
      debugPrint("Post expense With $paymentData");

      // Call API first
      await _apiService.createAdhocPayment(paymentData);

      // Create local expense object
      final expense = Expense(
        id: expenseId,
        title: title,
        description: description,
        amount: amount,
        category: category,
        date: expenseDate,
        servicePointId: servicePointId ?? currentServicePointId.value,
        subject: subject,
      );

      expenses.insert(0, expense); // Add to beginning of list

      // Save to database
      try {
        await _db.insertExpense(expense);
      } catch (e) {
        // Database might not be open, continue without saving
      }

      Get.snackbar(
        'Success',
        'Expense added successfully',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint(e.toString());
      Get.snackbar(
        'Error',
        'Failed to add expense: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }

  // Delete an expense
  Future<void> deleteExpense(String id) async {
    expenses.removeWhere((expense) => expense.id == id);

    // Delete from database
    try {
      await _db.deleteExpense(id);
    } catch (e) {
      // Database might not be open, continue without deleting
    }

    Get.snackbar(
      'Success',
      'Expense deleted',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  // Get total expenses
  double get totalExpenses {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  // Get expenses for today
  List<Expense> get todayExpenses {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return expenses.where((expense) {
      final expenseDate = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      return expenseDate.isAtSameMomentAs(today);
    }).toList();
  }

  // Get total for today
  double get totalTodayExpenses {
    return todayExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }
}