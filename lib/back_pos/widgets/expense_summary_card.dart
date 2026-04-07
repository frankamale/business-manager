import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseSummaryCard extends StatelessWidget {
  final double totalExpenses;
  final double todayExpenses;
  final NumberFormat currencyFormatter;
  final Color color;

  const ExpenseSummaryCard({
    super.key,
    required this.totalExpenses,
    required this.todayExpenses,
    required this.currencyFormatter,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: color.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Total Expenses
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
                currencyFormatter.format(totalExpenses),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          // Today's Expenses
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
                currencyFormatter.format(todayExpenses),
                style:  TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}