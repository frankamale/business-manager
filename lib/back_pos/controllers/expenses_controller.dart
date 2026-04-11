import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:bac_pos/back_pos/models/expense.dart';
import 'package:bac_pos/shared/database/unified_db_helper.dart';
import 'package:bac_pos/back_pos/services/api_services.dart';
import 'package:bac_pos/back_pos/utils/network_helper.dart';

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
    // Try to sync pending expenses on init
    _syncPendingIfOnline();
  }

  Future<void> _syncPendingIfOnline() async {
    try {
      final isOnline = await NetworkHelper.hasConnection();
      if (isOnline && pendingExpenses.isNotEmpty) {
        await syncPendingExpenses();
      }
    } catch (e) {
      debugPrint('Background sync check failed: $e');
    }
  }

  Future<void> loadExpensesFromDatabase() async {
    isLoading.value = true;
    try {
      final dbExpenses = await _db.getExpenses();

        expenses.value = dbExpenses;

      isLoading.value = false;
    }
    catch(e){
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
      "adhoc": "true",
      "currencyid": cashAccount['currencyid'],
      "bpid": selectedStaffId ?? '',
      "servicepointid": currentSpId,
      "transactiontypeid": 1,
      "amount": amount.toStringAsFixed(0),
      "methodId": "1",
      "chequeno": "",
      "cashaccountid": cashAccount['id'],
      "paydate": "${expenseDate.year}-${expenseDate.month.toString().padLeft(2, '0')}-${expenseDate.day.toString().padLeft(2, '0')}",
      "payref": category,
      "receipt": "false",
      "remarks": description,
      "direction": "1",
      "gLProxySubCategoryId": "55555555-5555-5555-5555-555555555555"
    };

    try {
      debugPrint("Post expense With $paymentData");

      // Create local expense object first with 'pending' status
      final expense = Expense(
        id: expenseId,
        title: title,
        description: description,
        amount: amount,
        category: category,
        date: expenseDate,
        servicePointId: servicePointId ?? currentServicePointId.value,
        subject: subject,
        uploadStatus: 'pending',
      );

      // Save to database immediately with 'pending' status
      try {
        await _db.insertExpense(expense);
      } catch (e) {
        debugPrint('Failed to save expense locally: $e');
      }

      expenses.insert(0, expense); // Add to beginning of list

      // Try to sync with API
      try {
        await _apiService.createAdhocPayment(paymentData);
        
        // Update to 'uploaded' status on success
        final index = expenses.indexWhere((e) => e.id == expenseId);
        if (index != -1) {
          final updatedExpense = Expense(
            id: expense.id,
            title: expense.title,
            description: expense.description,
            amount: expense.amount,
            category: expense.category,
            date: expense.date,
            servicePointId: expense.servicePointId,
            subject: expense.subject,
            uploadStatus: 'uploaded',
          );
          expenses[index] = updatedExpense;
          await _db.insertExpense(updatedExpense);
        }
        
        Get.snackbar(
          'Success',
          'Expense added and synced',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      } catch (e) {
        // API call failed, expense saved locally with 'pending' status
        debugPrint('API sync failed, expense saved locally: $e');
        Get.snackbar(
          'Saved Offline',
          'Expense saved locally, will sync when online',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      }
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

  // Get pending expenses (not uploaded yet)
  List<Expense> get pendingExpenses {
    return expenses.where((e) => e.uploadStatus == 'pending').toList();
  }

  // Sync all pending expenses
  Future<void> syncPendingExpenses() async {
    final pending = pendingExpenses;
    if (pending.isEmpty) return;

    debugPrint('Syncing ${pending.length} pending expenses...');
    
    for (final expense in pending) {
      try {
        final cashAccount = _getDefaultCashAccount();
        final paymentData = {
          "adhoc": "true",
          "currencyid": cashAccount['currencyid'],
          "bpid": expense.subject ?? '',
          "servicepointid": expense.servicePointId ?? '',
          "transactiontypeid": 1,
          "amount": expense.amount.toStringAsFixed(0),
          "methodId": "1",
          "chequeno": "",
          "cashaccountid": cashAccount['id'],
          "paydate": "${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}-${expense.date.day.toString().padLeft(2, '0')}",
          "payref": expense.category,
          "receipt": "false",
          "remarks": expense.description,
          "direction": "1",
          "gLProxySubCategoryId": "55555555-5555-5555-5555-555555555555"
        };

        await _apiService.createAdhocPayment(paymentData);
        
        // Update status to uploaded
        final index = expenses.indexWhere((e) => e.id == expense.id);
        if (index != -1) {
          final updated = Expense(
            id: expense.id,
            title: expense.title,
            description: expense.description,
            amount: expense.amount,
            category: expense.category,
            date: expense.date,
            servicePointId: expense.servicePointId,
            subject: expense.subject,
            uploadStatus: 'uploaded',
          );
          expenses[index] = updated;
          await _db.insertExpense(updated);
        }
      } catch (e) {
        debugPrint('Failed to sync expense ${expense.id}: $e');
      }
    }
    
    debugPrint('Pending expenses sync complete');
  }
}