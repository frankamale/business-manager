import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:bac_pos/back_pos/models/expense.dart';

class ExpensesController extends GetxController {
  final _uuid = const Uuid();

  // Reactive list of expenses
  var expenses = <Expense>[].obs;

  // Current service point ID for filtering
  var currentServicePointId = Rxn<String>();

  // Loading state
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize with some sample data for demonstration
    _loadSampleExpenses();
  }

  void _loadSampleExpenses() {
    final now = DateTime.now();
    expenses.value = [
      Expense(
        id: _uuid.v4(),
        description: 'Office supplies',
        amount: 50000,
        category: ExpenseCategory.supplies,
        date: now.subtract(const Duration(days: 1)),
      ),
      Expense(
        id: _uuid.v4(),
        description: 'Transport to market',
        amount: 30000,
        category: ExpenseCategory.transport,
        date: now.subtract(const Duration(days: 2)),
      ),
      Expense(
        id: _uuid.v4(),
        description: 'Electricity bill',
        amount: 150000,
        category: ExpenseCategory.utilities,
        date: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  // Add a new expense
  void addExpense({
    required String description,
    required double amount,
    required String category,
    DateTime? date,
    String? servicePointId,
  }) {
    final expense = Expense(
      id: _uuid.v4(),
      description: description,
      amount: amount,
      category: category,
      date: date ?? DateTime.now(),
      servicePointId: servicePointId ?? currentServicePointId.value,
    );

    expenses.insert(0, expense); // Add to beginning of list

    Get.snackbar(
      'Success',
      'Expense added successfully',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  // Delete an expense
  void deleteExpense(String id) {
    expenses.removeWhere((expense) => expense.id == id);

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