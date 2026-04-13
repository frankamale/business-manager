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
import 'package:bac_pos/back_pos/widgets/expense_detail_dialog.dart';
import 'package:bac_pos/back_pos/widgets/expense_statistics_dialog.dart';

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
  final _searchController = TextEditingController();

  final List<String> _dateFilters = ['Today', 'Yesterday', 'This Week', 'This Month', 'This Year', 'Custom'];

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

  void _showExpenseDetail(Expense expense) {
    ExpenseDetailDialog.show(
      context: context,
      expense: expense,
      getUserName: _getUserName,
      onDelete: () => _expensesController.deleteExpense(expense.id),
      currencyFormatter: _currencyFormatter,
      color: _getColorForServicePoint(),
    );
  }

  void _showStatistics() {
    ExpenseStatisticsDialog.show(
      context: context,
      categoryTotals: _expensesController.categoryTotals,
      sortedTotals: _expensesController.sortedCategoryTotals,
      totalAmount: _expensesController.totalFilteredExpenses,
      expenseCount: _expensesController.filteredExpenseCount,
      currencyFormatter: _currencyFormatter,
      color: _getColorForServicePoint(),
    );
  }

  void _onSearchChanged(String value) {
    _expensesController.setSearchText(value);
  }

  Future<void> _syncPendingExpenses() async {
    final pending = _expensesController.pendingExpenses;
    if (pending.isEmpty) {
      Get.snackbar(
        'Info',
        'No pending expenses to sync',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.dialog(
      const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Syncing expenses...'),
          ],
        ),
      ),
    );

    try {
      await _expensesController.syncPendingExpenses();
      Get.back(); // Close dialog
      Get.snackbar(
        'Success',
        'Expenses synced successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
      );
    } catch (e) {
      Get.back(); // Close dialog
      Get.snackbar(
        'Error',
        'Failed to sync expenses: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    }
  }

  Future<void> _showCustomDatePicker() async {
    DateTime? startDate;
    DateTime? endDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Select Custom Range'),
            content: SizedBox(
              height: 150,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(
                      startDate != null 
                          ? DateFormat.yMMMd().format(startDate!) 
                          : 'Not Set',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => startDate = picked);
                    },
                  ),
                  ListTile(
                    title: const Text('End Date'),
                    subtitle: Text(
                      endDate != null 
                          ? DateFormat.yMMMd().format(endDate!) 
                          : 'Not Set',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => endDate = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              FilledButton(
                onPressed: (startDate != null && endDate != null)
                    ? () {
                        if (startDate!.isAfter(endDate!)) {
                          Get.snackbar('Error', 'Start date must be before end date');
                          return;
                        }
                        _expensesController.setCustomDateRange(startDate!, endDate!);
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text('APPLY'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleMenuOption(String option) {
    switch (option) {
      case 'sync_all':
        _syncPendingExpenses();
        break;
      case 'statistics':
        _showStatistics();
        break;
      case 'clear_filters':
        _expensesController.clearFilters();
        _searchController.clear();
        break;
    }
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
        actions: [
          Obx(() {
            final pending = _expensesController.pendingExpenses;
            if (pending.isEmpty) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: _syncPendingExpenses,
              icon: const Icon(Icons.cloud_upload, size: 20),
              label: Text('Sync (${pending.length})'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green.shade700,
              ),
            );
          }),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
            onSelected: _handleMenuOption,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'sync_all',
                child: Row(
                  children: [
                    Icon(Icons.sync, size: 20, color: Colors.green.shade700),
                    SizedBox(width: 12),
                    Text('Sync All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Obx(() {
        final expenses = _expensesController.filteredExpenses;
        final selectedFilter = _expensesController.selectedDateFilter.value;

        return Column(
          children: [
            // Date Filter Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _dateFilters.map((filter) {
                    final isSelected = selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          filter == 'Custom' && _expensesController.customStartDate.value != null
                              ? 'Custom Range'
                              : filter,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: Colors.grey.shade100,
                        onSelected: (selected) {
                          if (selected) {
                            if (filter == 'Custom') {
                              _showCustomDatePicker();
                            } else {
                              _expensesController.setDateFilter(filter);
                            }
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // TOP SECTION (Summary with padding)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ExpenseSummaryCard(
                totalExpenses: _expensesController.totalFilteredExpenses,
                todayExpenses: _expensesController.totalFilteredExpenses,
                currencyFormatter: _currencyFormatter,
                color: color,
              ),
            ),

            // LIST SECTION
            Expanded(
              child: expenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'No expenses for $selectedFilter',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
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