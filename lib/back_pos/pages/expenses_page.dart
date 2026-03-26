import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:bac_pos/back_pos/models/expense.dart';
import 'package:bac_pos/back_pos/controllers/expenses_controller.dart';
import 'package:bac_pos/back_pos/controllers/user_controller.dart';
import 'package:bac_pos/back_pos/models/service_point.dart';
import 'package:bac_pos/flavors/flavor_colors.dart';

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
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = ExpenseCategory.other;
    String? selectedSubject;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Obx(() => DropdownButtonFormField<String>(
                  value: selectedSubject,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                  items: _userController.users.map((user) {
                    return DropdownMenuItem(
                      value: user.id,
                      child: Text(user.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedSubject = value);
                  },
                )),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: 'UGX ',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: ExpenseCategory.all.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedCategory = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();
                final amountText = amountController.text.trim();

                if (title.isEmpty) {
                  Get.snackbar(
                    'Error',
                    'Please enter a title',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }

                if (description.isEmpty) {
                  Get.snackbar(
                    'Error',
                    'Please enter a description',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }

                final amount = double.tryParse(amountText);
                if (amount == null || amount <= 0) {
                  Get.snackbar(
                    'Error',
                    'Please enter a valid amount',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }

                _expensesController.addExpense(
                  title: title,
                  description: description,
                  subject: selectedSubject,
                  amount: amount,
                  category: selectedCategory,
                  servicePointId: widget.servicePoint?.id,
                );

                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              _expensesController.deleteExpense(expense.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForServicePoint();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        final expenses = _expensesController.expenses;

        if (expenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No expenses yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the + button to add an expense',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: color.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Expenses',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyFormatter.format(_expensesController.totalExpenses),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyFormatter.format(_expensesController.totalTodayExpenses),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Expenses list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: ListTile(
                      title: Text(
                        expense.title.isNotEmpty ? expense.title : 'Untitled Expense',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${_getUserName(expense.subject)} • ${expense.category}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _currencyFormatter.format(expense.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _dateFormatter.format(expense.date),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _showDeleteConfirmation(expense),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        backgroundColor: color,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {x
      case ExpenseCategory.food:
        return Icons.restaurant;
      case ExpenseCategory.transport:
        return Icons.directions_car;
      case ExpenseCategory.supplies:
        return Icons.inventory_2;
      case ExpenseCategory.utilities:
        return Icons.electrical_services;
      case ExpenseCategory.rent:
        return Icons.home;
      case ExpenseCategory.maintenance:
        return Icons.build;
      case ExpenseCategory.salaries:
        return Icons.people;
      case ExpenseCategory.marketing:
        return Icons.campaign;
      default:
        return Icons.receipt;
    }
  }

  String _getUserName(String? userId) {
    if (userId == null || userId.isEmpty) {
      return 'No Subject';
    }
    final user = _userController.users.firstWhereOrNull((u) => u.id == userId);
    return user?.name ?? 'Unknown User';
  }
}