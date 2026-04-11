import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:bac_pos/back_pos/controllers/expenses_controller.dart';
import 'package:bac_pos/back_pos/controllers/user_controller.dart';
import 'package:bac_pos/back_pos/controllers/service_point_controller.dart';
import 'package:bac_pos/back_pos/widgets/expense_form_dialog.dart';
import 'package:bac_pos/back_pos/models/expense.dart';
import '../additions/colors.dart';
import '../controllers/mon_store_controller.dart';

class ExpensesDetailPage extends StatefulWidget {
  final String expenseType; // 'stock' or 'non-stock'
  final String periodLabel;

  const ExpensesDetailPage({
    super.key,
    required this.expenseType,
    required this.periodLabel,
  });

  @override
  State<ExpensesDetailPage> createState() => _ExpensesDetailPageState();
}

class _ExpensesDetailPageState extends State<ExpensesDetailPage> {
  late ExpensesController _expensesController;
  late UserController _userController;
  bool _controllersInitialized = false;
  final List<String> _dateFilters = ['Today', 'Yesterday', 'This Week', 'This Month', 'This Year', 'Custom'];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  Future<void> _initControllers() async {
    if (!Get.isRegistered<ExpensesController>()) {
      Get.put(ExpensesController());
    }
    _expensesController = Get.find<ExpensesController>();

    if (!Get.isRegistered<UserController>()) {
      Get.put(UserController());
    }
    _userController = Get.find<UserController>();
    await _userController.fetchUsers();

    if (!Get.isRegistered<ServicePointController>()) {
      Get.put(ServicePointController());
    }
    final spController = Get.find<ServicePointController>();
    await spController.loadServicePointsFromCache();

    setState(() => _controllersInitialized = true);
  }

  void _showAddExpenseDialog(BuildContext context) {
    final storeController = Get.find<MonStoresController>();
    final selectedStore = storeController.selectedStore.value;
    // Use actual store ID, not the "all stores" ID
    final servicePointId = (selectedStore != null && selectedStore.id != '---all-stores-id---')
        ? selectedStore.id
        : null;

    ExpenseFormDialog.show(
      context: context,
      expensesController: _expensesController,
      servicePointId: servicePointId,
      color: LightColors.primary,
    );
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

    try {
      await _expensesController.syncPendingExpenses();
      Get.snackbar(
        'Success',
        'Expenses synced successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to sync: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
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

  @override
  Widget build(BuildContext context) {
    final isStockExpense = widget.expenseType == 'stock';
    final compactFormatter = NumberFormat.compact(locale: 'en_US');
    final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: 'UGX', decimalDigits: 0);

    return Scaffold(
      backgroundColor: LightColors.background,
      appBar: AppBar(
        backgroundColor: LightColors.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: LightColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text(
          isStockExpense ? 'Stock Expenses' : 'Non-Stock Payments',
          style: TextStyle(
            color: LightColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Obx(() {
            final pending = _expensesController.pendingExpenses;
            if (pending.isEmpty || isStockExpense) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: _syncPendingExpenses,
              icon: const Icon(Icons.cloud_upload, size: 20, color: Colors.green),
              label: Text(
                'Sync (${pending.length})',
                style: const TextStyle(color: Colors.green),
              ),
            );
          }),
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 16.0),
          //   child: Center(
          //     child: Text(
          //       widget.periodLabel,
          //       style: TextStyle(
          //         color: LightColors.textSecondary,
          //         fontSize: 12,
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Filter Chips
            Obx(() {
              final selectedFilter = _expensesController.selectedDateFilter.value;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
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
                              color: isSelected ? Colors.white : LightColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: LightColors.primary,
                          backgroundColor: LightColors.surface,
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
              );
            }),

            const SizedBox(height: 8),

            // Summary Card
            _buildSummaryCard(
              isStockExpense: isStockExpense,
              compactFormatter: compactFormatter,
            ),
            const SizedBox(height: 24),

            // Breakdown Section
            Text(
              'Expense Breakdown',
              style: TextStyle(
                color: LightColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Placeholder for expense items
            _buildExpenseItemsList(
              isStockExpense: isStockExpense,
              currencyFormatter: currencyFormatter,
            ),
          ],
        ),
      ),
      // FAB for adding non-stock expenses
      floatingActionButton: !isStockExpense && _controllersInitialized
          ? Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.extended(
                onPressed: () => _showAddExpenseDialog(context),
                backgroundColor: LightColors.primary,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                icon:  Icon(Icons.add,  color: AppColors.getTextPrimary(context),),
                label:  Text(
                  'Add Expense',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSummaryCard({
    required bool isStockExpense,
    required NumberFormat compactFormatter,
  }) {
    return Obx(() {
      final expenses = _expensesController.filteredExpenses;
      final totalExpense = expenses.fold(0.0, (sum, e) => sum + e.amount);
      final itemCount = expenses.length;

      return Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: LightColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: LightColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LightColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isStockExpense ? Icons.inventory_2_outlined : Icons.receipt_long_outlined,
                    color: LightColors.textPrimary,
                    size: 32,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total ${isStockExpense ? 'Stock' : 'Non-Stock'} Expenses',
                      style: TextStyle(
                        color: LightColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'UGX${compactFormatter.format(totalExpense)}',
                      style: TextStyle(
                        color: LightColors.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: LightColors.border),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Total Items', itemCount.toString()),
              _buildStatItem('Average', itemCount > 0 ? 'UGX${(totalExpense / itemCount).toStringAsFixed(0)}' : 'UGX0'),
            ],
          ),
        ],
      ),
    );
    });
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: LightColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: LightColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseItemsList({
    required bool isStockExpense,
    required NumberFormat currencyFormatter,
  }) {
    return Obx(() {
      final expenses = _expensesController.filteredExpenses;
      final selectedFilter = _expensesController.selectedDateFilter.value;
      
      if (expenses.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: LightColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: LightColors.border,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.data_usage_outlined,
                color: LightColors.textHint,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'No expenses for $selectedFilter',
                style: TextStyle(
                  color: LightColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap + to add an expense',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LightColors.textHint,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          final expense = expenses[index];
          final dateStr = DateFormat('MMM dd, yyyy').format(expense.date);
          return _buildExpenseItem(
            expenseId: expense.id,
            name: expense.title,
            amount: currencyFormatter.format(expense.amount),
            date: dateStr,
            category: expense.category,
            uploadStatus: expense.uploadStatus,
          );
        },
      );
    });
  }

  Widget _buildExpenseItem({
    required String expenseId,
    required String name,
    required String amount,
    required String date,
    String? category,
    String uploadStatus = 'uploaded',
  }) {
    final isPending = uploadStatus == 'pending';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LightColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: LightColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: LightColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isPending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Pending',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    color: LightColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (category != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: LightColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: LightColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                amount,
                style: TextStyle(
                  color: LightColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isPending) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                  onPressed: () => _showDeleteConfirmation(expenseId, name),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String expenseId, String expenseName) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "$expenseName"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _expensesController.deleteExpense(expenseId);
              Get.back();
              Get.snackbar(
                'Deleted',
                'Expense deleted',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: Text('Delete', style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );
  }
}
