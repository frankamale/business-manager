import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bac_pos/back_pos/models/expense.dart';

class ExpenseListItem extends StatelessWidget {
  final Expense expense;
  final NumberFormat currencyFormatter;
  final DateFormat dateFormatter;
  final Color color;
  final String Function(String?) getUserName;
  final VoidCallback onDelete;

  const ExpenseListItem({
    super.key,
    required this.expense,
    required this.currencyFormatter,
    required this.dateFormatter,
    required this.color,
    required this.getUserName,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = expense.uploadStatus == 'pending';
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: isPending
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off,
                  size: 16,
                  color: Colors.orange.shade700,
                ),
              )
            : null,
        title: Text(
          expense.title.isNotEmpty ? expense.title : 'Untitled Expense',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              getUserName(expense.subject),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const Text(' • ', style: TextStyle(color: Colors.grey)),
            Flexible(
              child: Text(
                expense.category,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Amount and date column
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormatter.format(expense.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateFormatter.format(expense.date),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}