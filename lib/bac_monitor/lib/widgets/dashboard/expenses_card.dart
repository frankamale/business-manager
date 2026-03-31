import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../additions/colors.dart';

class ExpensesCard extends StatelessWidget {
  final double stockExpenses;
  final double nonStockExpenses;
  final String periodLabel;
  final VoidCallback? onStockExpensesTap;
  final VoidCallback? onNonStockExpensesTap;

  const ExpensesCard({
    super.key,
    required this.stockExpenses,
    required this.nonStockExpenses,
    required this.periodLabel,
    this.onStockExpensesTap,
    this.onNonStockExpensesTap,
  });

  @override
  Widget build(BuildContext context) {
    final compactFormatter = NumberFormat.compact(locale: 'en_US');
    final totalExpenses = stockExpenses + nonStockExpenses;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LightColors.primaryLight.withOpacity(0.9),
            LightColors.primaryDark.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Title with Period Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expenses',
                style: TextStyle(
                  color: LightColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                periodLabel,
                style: TextStyle(
                  color: LightColors.textSecondary.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Hero Metric (Total Expenses)
          Text(
            'UGX${compactFormatter.format(totalExpenses)}',
            style: TextStyle(
              color: LightColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 36,
            ),
          ),
          const SizedBox(height: 20),

          Divider(color: LightColors.border),
          const SizedBox(height: 12),

          // 3. Clickable Expense Categories
          _buildExpenseCategoryCard(
            context: context,
            label: 'Stock Expenses',
            amount: compactFormatter.format(stockExpenses),
            icon: Icons.inventory_2_outlined,
            color: Colors.orangeAccent,
            onTap: onStockExpensesTap,
          ),
          const SizedBox(height: 12),
          _buildExpenseCategoryCard(
            context: context,
            label: 'Non-Stock Expenses',
            amount: compactFormatter.format(nonStockExpenses),
            icon: Icons.receipt_long_outlined,
            color: Colors.purpleAccent,
            onTap: onNonStockExpensesTap,
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCategoryCard({
    required BuildContext context,
    required String label,
    required String amount,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LightColors.card.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: LightColors.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Label and Amount
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: LightColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'UGX$amount',
                    style: TextStyle(
                      color: LightColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow Icon
            Icon(
              Icons.arrow_forward_ios,
              color: LightColors.textSecondary.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
