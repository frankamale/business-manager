import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:bac_pos/back_pos/models/expense.dart';
import 'package:bac_pos/back_pos/controllers/expenses_controller.dart';
import 'package:bac_pos/back_pos/controllers/user_controller.dart';
import 'package:bac_pos/back_pos/models/service_point.dart';
import 'package:bac_pos/flavors/flavor_colors.dart';
import 'package:bac_pos/back_pos/widgets/expense_form_dialog.dart';
import 'package:bac_pos/back_pos/widgets/expense_summary_card.dart';
import 'package:bac_pos/back_pos/widgets/expense_list_item.dart';
import 'package:bac_pos/back_pos/widgets/expense_empty_state.dart';
import 'package:bac_pos/back_pos/widgets/expense_delete_dialog.dart';

class ExpensesPage extends StatefulWidget {
  final ServicePoint? servicePoint;

  const ExpensesPage({super.key, this.servicePoint});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  late final ExpensesController _expensesController;
  late final UserController _userController;
  final _currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: 'UGX ');
  final _dateFormatter = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ExpensesController>()) {
      Get.put(ExpensesController());
    }
    _expensesController = Get.find<ExpensesController>();

    if (!Get.isRegistered<UserController>()) {
      Get.put(UserController());
    }
    _userController = Get.find<UserController>();
    _userController.fetchUsers();
  }

  Color _getColorForServicePoint() {
    if (widget.servicePoint == null) {
      return FlavorColors.current.primary;
    }
    final lowerType = widget.servicePoint!.servicepointtype.toLowerCase();
    if (lowerType.contains('restaurant')) return Colors.red;
    if (lowerType.contains('bar')) return Colors.purple;
    if (lowerType.contains('cafe') || lowerType.contains('cafeteria'))
      return Colors.brown;
    if (lowerType.contains('pharmacy')) return Colors.green;
    if (lowerType.contains('hardware')) return Colors.orange;
    if (lowerType.contains('shop')) return FlavorColors.current.primary;
    return Colors.teal;
  }

  void _showAddExpenseDialog() {
    ExpenseFormDialog.show(
      context: context,
      expensesController: _expensesController,
      servicePointId: widget.servicePoint?.id,
      color: _getColorForServicePoint(),
    );
  }

  void _showDeleteConfirmation(Expense expense) {
    ExpenseDeleteDialog.show(
      context: context,
      expense: expense,
      onDelete: () => _expensesController.deleteExpense(expense.id),
    );
  }

  String _getUserName(String? userId) {
    if (userId == null || userId.isEmpty) {
      return 'No Subject';
    }
    final user = _userController.users.firstWhereOrNull((u) => u.id == userId);
    return user?.name ?? 'Unknown User';
  }

  @override
  @override
  @override
  Widget build(BuildContext context) {
    final color = _getColorForServicePoint();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: const Text(
          'Expenses',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      body: Obx(() {
        final expenses = _expensesController.expenses;

        if (expenses.isEmpty) {
          return const ExpenseEmptyState();
        }

        return Column(
          children: [
            // TOP SECTION (Summary with padding)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ExpenseSummaryCard(
                totalExpenses: _expensesController.totalExpenses,
                todayExpenses: _expensesController.totalTodayExpenses,
                currencyFormatter: _currencyFormatter,
                color: color,
              ),
            ),

            // LIST SECTION
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final expense = expenses[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ExpenseListItem(
                      expense: expense,
                      currencyFormatter: _currencyFormatter,
                      dateFormatter: _dateFormatter,
                      color: color,
                      getUserName: _getUserName,
                      onDelete: () => _showDeleteConfirmation(expense),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),

      // IMPROVED FAB
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FloatingActionButton.extended(
          onPressed: _showAddExpenseDialog,
          backgroundColor: color,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.add),
          label: const Text(
            'Add Expense',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}