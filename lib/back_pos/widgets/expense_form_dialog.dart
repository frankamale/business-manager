import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bac_pos/back_pos/models/expense.dart';
import 'package:bac_pos/back_pos/controllers/expenses_controller.dart';
import 'package:bac_pos/back_pos/controllers/user_controller.dart';

class ExpenseFormDialog extends StatefulWidget {
  final ExpensesController expensesController;
  final String? servicePointId;

  const ExpenseFormDialog({
    super.key,
    required this.expensesController,
    this.servicePointId,
  });

  static Future<void> show({
    required BuildContext context,
    required ExpensesController expensesController,
    String? servicePointId,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ExpenseFormDialog(
        expensesController: expensesController,
        servicePointId: servicePointId,
      ),
    );
  }

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  late final UserController _userController;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = ExpenseCategory.other;
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _userController = Get.find<UserController>();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submitForm() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final amountText = _amountController.text.trim();

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

    widget.expensesController.addExpense(
      title: title,
      description: description,
      subject: _selectedSubject,
      amount: amount,
      category: _selectedCategory,
      servicePointId: widget.servicePointId,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Description field
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Subject dropdown
            Obx(() => DropdownButtonFormField<String>(
              value: _selectedSubject,
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
                setState(() => _selectedSubject = value);
              },
            )),
            const SizedBox(height: 16),
            // Amount field
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixText: 'UGX ',
              ),
            ),
            const SizedBox(height: 16),
            // Category dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategory,
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
                  setState(() => _selectedCategory = value);
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
          onPressed: _submitForm,
          child: const Text('Add'),
        ),
      ],
    );
  }
}