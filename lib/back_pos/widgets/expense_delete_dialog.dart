import 'package:flutter/material.dart';
import 'package:bac_pos/back_pos/models/expense.dart';

class ExpenseDeleteDialog extends StatelessWidget {
  final Expense expense;
  final VoidCallback onDelete;

  const ExpenseDeleteDialog({
    super.key,
    required this.expense,
    required this.onDelete,
  });

  static Future<void> show({
    required BuildContext context,
    required Expense expense,
    required VoidCallback onDelete,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ExpenseDeleteDialog(
        expense: expense,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            onDelete();
            Navigator.pop(context);
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}