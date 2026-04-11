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
    final servicePointId = storeController.selectedStore.value?.id;

    ExpenseFormDialog.show(
      context: context,
      expensesController: _expensesController,
      servicePointId: servicePointId,
      color: LightColors.primary,
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
          isStockExpense ? 'Stock Expenses' : 'Non-Stock Expenses',
          style: TextStyle(
            color: LightColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                widget.periodLabel,
                style: TextStyle(
                  color: LightColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
      final expenses = _expensesController.expenses;
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
      final expenses = _expensesController.expenses;
      
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
                'No expenses yet',
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
            name: expense.title,
            amount: currencyFormatter.format(expense.amount),
            date: dateStr,
            category: expense.category,
          );
        },
      );
    });
  }

  Widget _buildExpenseItem({
    required String name,
    required String amount,
    required String date,
    String? category,
  }) {
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
                Text(
                  name,
                  style: TextStyle(
                    color: LightColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
          Text(
            amount,
            style: TextStyle(
              color: LightColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
