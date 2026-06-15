import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bac_pos/back_pos/models/expense.dart';

class ExpenseDetailDialog extends StatelessWidget {
  final Expense expense;
  final String Function(String?) getUserName;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final NumberFormat currencyFormatter;
  final DateFormat dateFormatter;
  final Color color;

  const ExpenseDetailDialog({
    super.key,
    required this.expense,
    required this.getUserName,
    this.onEdit,
    required this.onDelete,
    required this.currencyFormatter,
    required this.dateFormatter,
    required this.color,
  });

  static Future<void> show({
    required BuildContext context,
    required Expense expense,
    required String Function(String?) getUserName,
    VoidCallback? onEdit,
    required VoidCallback onDelete,
    required NumberFormat currencyFormatter,
    required Color color,
  }) {
    final dateFormatter = DateFormat('MMM dd, yyyy • h:mm a');
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpenseDetailDialog(
        expense: expense,
        getUserName: getUserName,
        onEdit: onEdit,
        onDelete: onDelete,
        currencyFormatter: currencyFormatter,
        dateFormatter: dateFormatter,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = expense.uploadStatus == 'pending';
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: color,
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
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
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              expense.category,
                              style: TextStyle(
                                color: color,
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
                  icon: Icon(Icons.close, color: Colors.grey.shade500),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Amount
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amount',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormatter.format(expense.amount),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildDetailRow(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  value: dateFormatter.format(expense.date),
                ),
                _buildDetailRow(
                  icon: Icons.person_outline,
                  label: 'Staff',
                  value: getUserName(expense.subject),
                ),
                if (expense.description.isNotEmpty)
                  _buildDetailRow(
                    icon: Icons.notes_outlined,
                    label: 'Description',
                    value: expense.description,
                  ),
                if (expense.servicePointId != null)
                  _buildDetailRow(
                    icon: Icons.store_outlined,
                    label: 'Service Point',
                    value: expense.servicePointId ?? 'N/A',
                  ),
                _buildDetailRow(
                  icon: isPending ? Icons.cloud_off : Icons.cloud_done,
                  label: 'Status',
                  value: isPending ? 'Pending Sync' : 'Synced',
                  valueColor: isPending ? Colors.orange : Colors.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Row(
              children: [
                if (onEdit != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onEdit!();
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (onEdit != null) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation(context);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? Colors.grey.shade900,
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

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}