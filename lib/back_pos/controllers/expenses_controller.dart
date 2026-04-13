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

  // Current expense type being viewed: 'stock' or 'non-stock'
  var currentExpenseType = 'non-stock'.obs;

  // Reactive list of expenses
  var expenses = <Expense>[].obs;

  // Current service point ID for filtering
  var currentServicePointId = Rxn<String>();

  // Filter state
  var selectedDateFilter = 'Today'.obs;
  var customStartDate = Rxn<DateTime>();
  var customEndDate = Rxn<DateTime>();
  var searchText = ''.obs;
  var selectedCategoryFilter = Rxn<String>();

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
    String? staffId,
    String expenseType = 'non-stock',
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
      "bpid": staffId ?? '',
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
        staffId: staffId,
        uploadStatus: 'pending',
        expenseType: expenseType,
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
              staffId: expense.staffId,
              uploadStatus: 'uploaded',
              expenseType: expense.expenseType,
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

  DateTime? get _filterStartDate {
    final now = DateTime.now();
    final filter = selectedDateFilter.value;
    
    switch (filter) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'Yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTime(yesterday.year, yesterday.month, yesterday.day);
      case 'This Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(weekStart.year, weekStart.month, weekStart.day);
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      case 'This Year':
        return DateTime(now.year, 1, 1);
      case 'Custom':
        return customStartDate.value;
      default:
        return DateTime(now.year, now.month, now.day);
    }
  }

  DateTime? get _filterEndDate {
    final now = DateTime.now();
    final filter = selectedDateFilter.value;
    
    switch (filter) {
      case 'Today':
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case 'Yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
      case 'This Week':
        final weekEnd = now.add(Duration(days: 7 - now.weekday));
        return DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59);
      case 'This Month':
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        return nextMonth.subtract(const Duration(seconds: 1));
      case 'This Year':
        return DateTime(now.year + 1, 1, 1).subtract(const Duration(seconds: 1));
      case 'Custom':
        return customEndDate.value != null 
            ? DateTime(customEndDate.value!.year, customEndDate.value!.month, customEndDate.value!.day, 23, 59, 59)
            : null;
      default:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  List<Expense> get filteredExpenses {
    final startDate = _filterStartDate;
    final endDate = _filterEndDate;
    final search = searchText.value.toLowerCase();
    final categoryFilter = selectedCategoryFilter.value;
    final expenseType = currentExpenseType.value;
    
    return expenses.where((expense) {
      // Filter by expense type first
      if (expense.expenseType != expenseType) return false;
      
      final expenseDate = expense.date;
      final afterStart = startDate == null || !expenseDate.isBefore(startDate);
      final beforeEnd = endDate == null || !expenseDate.isAfter(endDate);
      
      final matchesSearch = search.isEmpty || 
          expense.title.toLowerCase().contains(search) ||
          expense.description.toLowerCase().contains(search);
      
      final matchesCategory = categoryFilter == null || 
          expense.category == categoryFilter;
      
      return afterStart && beforeEnd && matchesSearch && matchesCategory;
    }).toList();
  }

  double get totalFilteredExpenses {
    return filteredExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  Map<String, double> get categoryTotals {
    final totals = <String, double>{};
    for (final expense in filteredExpenses) {
      final category = expense.category;
      totals[category] = (totals[category] ?? 0) + expense.amount;
    }
    return totals;
  }

  List<MapEntry<String, double>> get sortedCategoryTotals {
    final entries = categoryTotals.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  int get filteredExpenseCount {
    return filteredExpenses.length;
  }

  void setDateFilter(String filter) {
    selectedDateFilter.value = filter;
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    customStartDate.value = start;
    customEndDate.value = end;
    selectedDateFilter.value = 'Custom';
  }

  void setSearchText(String text) {
    searchText.value = text;
  }

  void setCategoryFilter(String? category) {
    selectedCategoryFilter.value = category;
  }

  void clearFilters() {
    searchText.value = '';
    selectedCategoryFilter.value = null;
    selectedDateFilter.value = 'Today';
    customStartDate.value = null;
    customEndDate.value = null;
  }

  // Get pending expenses (not uploaded yet) - filtered by current expense type
  List<Expense> get pendingExpenses {
    final expenseType = currentExpenseType.value;
    return expenses.where((e) => e.uploadStatus == 'pending' && e.expenseType == expenseType).toList();
  }

  // Get all pending expenses regardless of type (for dashboard and back_pos display)
  List<Expense> get allPendingExpenses {
    return expenses.where((e) => e.uploadStatus == 'pending').toList();
  }

  // Get pending expenses for a specific type (helper for back_pos)
  List<Expense> getPendingByType(String type) {
    return expenses.where((e) => e.uploadStatus == 'pending' && e.expenseType == type).toList();
  }

  // Sync all pending expenses
  Future<void> syncPendingExpenses() async {
    // Check connectivity first
    final isOnline = await NetworkHelper.hasConnection();
    if (!isOnline) {
      throw Exception('No internet connection');
    }

    final pending = pendingExpenses;
    if (pending.isEmpty) return;

    debugPrint('Syncing ${pending.length} pending expenses...');
    
    int failedCount = 0;
    String lastError = '';
    
    for (final expense in pending) {
      try {
        final cashAccount = _getDefaultCashAccount();
        final paymentData = {
          "adhoc": "true",
          "currencyid": cashAccount['currencyid'],
          "bpid": expense.staffId ?? expense.subject ?? '',
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

        debugPrint('Syncing expense ${expense.id}: $paymentData');

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
            staffId: expense.staffId,
            uploadStatus: 'uploaded',
            expenseType: expense.expenseType,
          );
          expenses[index] = updated;
          await _db.insertExpense(updated);
        }
      } catch (e) {
        debugPrint('Failed to sync expense ${expense.id}: $e');
        failedCount++;
        lastError = e.toString();
      }
    }
    
    debugPrint('Pending expenses sync complete');
    
    if (failedCount > 0) {
      throw Exception('Failed to sync $failedCount expense(s). $lastError');
    }
  }
}