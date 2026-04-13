import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:bac_pos/back_pos/controllers/expenses_controller.dart';
import 'package:bac_pos/back_pos/controllers/user_controller.dart';
import 'package:bac_pos/back_pos/controllers/service_point_controller.dart';
import 'package:bac_pos/back_pos/widgets/expense_form_dialog.dart';
import 'package:bac_pos/back_pos/widgets/expense_statistics_dialog.dart';
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
  final List<String> _dateFilters = [
    'Today',
    'Yesterday',
    'This Week',
    'This Month',
    'This Year',
    'Custom',
  ];
  final _searchController = TextEditingController();
  final _dateFormatter = DateFormat('MMM dd, yyyy');
  final _currencyFormatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'UGX',
    decimalDigits: 0,
  );

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
    // Set the expense type filter
    _expensesController.currentExpenseType.value = widget.expenseType;

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
    final servicePointId =
        (selectedStore != null && selectedStore.id != '---all-stores-id---')
        ? selectedStore.id
        : null;

    ExpenseFormDialog.show(
      context: context,
      expensesController: _expensesController,
      servicePointId: servicePointId,
      color: AppColors.getTextPrimaryColor(context),
      expenseType: widget.expenseType,
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
                          Get.snackbar(
                            'Error',
                            'Start date must be before end date',
                          );
                          return;
                        }
                        _expensesController.setCustomDateRange(
                          startDate!,
                          endDate!,
                        );
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

  void _onSearchChanged(String value) {
    _expensesController.setSearchText(value);
  }

  void _showStatistics() {
    ExpenseStatisticsDialog.show(
      context: context,
      categoryTotals: _expensesController.categoryTotals,
      sortedTotals: _expensesController.sortedCategoryTotals,
      totalAmount: _expensesController.totalFilteredExpenses,
      expenseCount: _expensesController.filteredExpenseCount,
      currencyFormatter: NumberFormat.currency(
        locale: 'en_US',
        symbol: 'UGX',
        decimalDigits: 0,
      ),
      color: AppColors.getTextPrimaryColor(context),
    );
  }

  void _handleMenuOption(String option) {
    switch (option) {
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
  Widget build(BuildContext context) {
    final isStockExpense = widget.expenseType == 'stock';
    final compactFormatter = NumberFormat.compact(locale: 'en_US');
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'UGX',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackgroundColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.getTextPrimaryColor(context),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          isStockExpense ? 'Stock Expenses' : 'Non-Stock Payments',
          style: TextStyle(
            color: AppColors.getTextPrimaryColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Obx(() {
            final pending = _expensesController.pendingExpenses;
            if (pending.isEmpty || isStockExpense)
              return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: _syncPendingExpenses,
              icon: const Icon(
                Icons.cloud_upload,
                size: 20,
                color: Colors.green,
              ),
              label: Text(
                'Sync (${pending.length})',
                style: const TextStyle(color: Colors.green),
              ),
            );
          }),
          if (!isStockExpense)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: AppColors.getTextPrimaryColor(context),
              ),
              onSelected: _handleMenuOption,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'statistics',
                  child: Row(
                    children: [
                      Icon(
                        Icons.bar_chart,
                        size: 20,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 12),
                      Text('Statistics'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear_filters',
                  child: Row(
                    children: [
                      Icon(
                        Icons.clear_all,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 12),
                      Text('Clear Filters'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar (non-stock only)
            if (!isStockExpense)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search expenses...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                    suffixIcon: Obx(() {
                      if (_expensesController.searchText.value.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _expensesController.setSearchText('');
                        },
                      );
                    }),
                    filled: true,
                    fillColor: AppColors.getSurfaceColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

            // Category Filter (non-stock only)
            if (!isStockExpense)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Obx(() {
                  final selectedCategory =
                      _expensesController.selectedCategoryFilter.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.getBackgroundColor(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: selectedCategory,
                        hint: Row(
                          children: [
                            Icon(
                              Icons.category,
                              size: 18,
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'All Categories',
                              style: TextStyle(
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                          ],
                        ),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: Colors.grey.shade600,
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'All Categories',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                          ...ExpenseCategory.all.map(
                            (cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          ),
                        ],
                        onChanged: (value) {
                          _expensesController.setCategoryFilter(value);
                        },
                      ),
                    ),
                  );
                }),
              ),

            // Date Filter Chips
            Obx(() {
              final selectedFilter =
                  _expensesController.selectedDateFilter.value;
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
                            filter == 'Custom' &&
                                    _expensesController.customStartDate.value !=
                                        null
                                ? 'Custom Range'
                                : filter,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.getPrimaryColor(context)
                                  : AppColors.getTextPrimaryColor(context),
                              fontSize: 13,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.transparent,
                          backgroundColor: AppColors.getBackgroundColor(
                            context,
                          ),
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
                color: AppColors.getTextSecondaryColor(context),
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
                backgroundColor: AppColors.getCardColor(context),
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                icon: Icon(Icons.add, color: AppColors.getTextPrimaryColor(context)),
                label: Text(
                  'Add Expense',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.getTextSecondaryColor(context),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppColors.getTextPrimaryColor(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
          color: AppColors.getCardColor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.getBackgroundColor(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isStockExpense
                        ? Icons.inventory_2_outlined
                        : Icons.receipt_long_outlined,
                    color: AppColors.getTextPrimaryColor(context),
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
                          color: AppColors.getTextSecondaryColor(context),

                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isStockExpense ? "0" :
                        'UGX${compactFormatter.format(totalExpense)}',
                        style: TextStyle(
                          color: AppColors.getTextPrimaryColor(context),
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
            Divider(color: AppColors.getTextPrimaryColor(context)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Total Items', itemCount.toString()),
                _buildStatItem(
                  'Average',
                  itemCount > 0
                      ? 'UGX${(totalExpense / itemCount).toStringAsFixed(0)}'
                      : 'UGX0',
                ),
              ],
            ),
          ],
        ),
      );
    });
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
            color: AppColors.getCardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorderColor(context), width: 1),
          ),
          child: Column(
            children: [
              Icon(
                Icons.data_usage_outlined,
                color: AppColors.getTextHintColor(context),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text('No expenses for $selectedFilter'),
              if (!isStockExpense) ...[
                const SizedBox(height: 8),
                Text('Tap + to add an expense'),
              ],
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
          return _buildExpenseItem(
            expense: expense,
            amount: currencyFormatter.format(expense.amount),
            dateStr: _dateFormatter.format(expense.date),
          );
        },
      );
    });
  }

  Widget _buildExpenseItem({
    required Expense expense,
    required String amount,
    required String dateStr,
  }) {
    final isPending = expense.uploadStatus == 'pending';
    final isStockExpense = widget.expenseType == 'stock';

    return GestureDetector(
      onTap: isStockExpense ? null : () => _showExpenseDetail(expense),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:AppColors.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color:AppColors.getBorderColor(context), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(expense.title)),
                      if (isPending)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Pending'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(dateStr),
                  if (expense.category.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(expense.category),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(amount),
                if (isPending && !isStockExpense) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () =>
                        _showDeleteConfirmation(expense.id, expense.title),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExpenseDetail(Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildExpenseDetailSheet(expense),
    );
  }

  Widget _buildExpenseDetailSheet(Expense expense) {
    final isPending = expense.uploadStatus == 'pending';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.getTextHintColor(context),
                borderRadius: BorderRadius.circular(2),
              ), 
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: AppColors.getPrimaryColor(context),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title.isNotEmpty
                            ? expense.title
                            : 'Untitled Expense',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              expense.category,
                              style: TextStyle(
                                color: AppColors.getPrimaryColor(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isPending) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Pending',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.getTextHintColor(context)),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.getSurfaceColor(context),
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.getBorderColor(context), height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amount',
                  style: TextStyle(
                    color: AppColors.getTextSecondaryColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currencyFormatter.format(expense.amount),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.getPrimaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildDetailRow(
                  Icons.calendar_today,
                  'Date',
                  _dateFormatter.format(expense.date),
                ),
                _buildDetailRow(
                  Icons.person_outline,
                  'Staff',
                  _getUserName(expense.subject),
                ),
                if (expense.description.isNotEmpty)
                  _buildDetailRow(
                    Icons.notes_outlined,
                    'Description',
                    expense.description,
                  ),
                _buildDetailRow(
                  isPending ? Icons.cloud_off : Icons.cloud_done,
                  'Status',
                  isPending ? 'Pending Upload' : 'Uploaded',
                  valueColor: isPending ? Colors.orange : Colors.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmation(expense.id, expense.title);
              },
              icon: Icon(Icons.delete_outline, color: Colors.red),
              label: Text('Delete', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.getTextHintColor(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: AppColors.getTextSecondaryColor(context), fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppColors.getTextPrimaryColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
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
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
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
