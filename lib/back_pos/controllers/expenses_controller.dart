import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:bac_pos/back_pos/models/expense.dart';
import 'package:bac_pos/shared/database/unified_db_helper.dart';

class ExpensesController extends GetxController {
  final _uuid = const Uuid();
  final _db = UnifiedDatabaseHelper.instance;

  // Reactive list of expenses
  var expenses = <Expense>[].obs;

  // Current service point ID for filtering
  var currentServicePointId = Rxn<String>();

  // Loading state
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Load expenses from database
    loadExpensesFromDatabase();
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

  // Add a new expense
  Future<void> addExpense({
    required String title,
    required String description,
    required double amount,
    required String category,
    DateTime? date,
    String? servicePointId,
    String? subject,
  }) async {
    final expense = Expense(
      id: _uuid.v4(),
      title: title,
      description: description,
      amount: amount,
      category: category,
      date: date ?? DateTime.now(),
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