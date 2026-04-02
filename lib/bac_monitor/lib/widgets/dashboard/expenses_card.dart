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
    final compactFormatter = NumberFormat.compact();
    final totalExpenses = stockExpenses + nonStockExpenses;
    final cardColor = AppColors.getCardColor(context);
    final borderColor = AppColors.getBorderColor(context);
    final textPrimary = AppColors.getTextPrimaryColor(context);
    final textSecondary = AppColors.getTextSecondaryColor(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),

        // match your other cards
        border: Border.all(
          color: borderColor,
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expenses',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                periodLabel,
                style: TextStyle(
                  color: textSecondary.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // TOTAL (hero)
          Text(
            'UGX ${compactFormatter.format(totalExpenses)}',
            style: TextStyle(
              color: textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          // CATEGORY ROW (side by side)
          Row(
            children: [
              Expanded(
                child: _miniCategoryCard(
                  context: context,
                  label: 'Stock',
                  amount: stockExpenses,
                  color: AppColors.getBackgroundColor(context),
                  icon: Icons.inventory_2_outlined,
                  formatter: compactFormatter,
                  onTap: onStockExpensesTap,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _miniCategoryCard(
                  context: context,
                  label: 'Non-Stock',
                  amount: nonStockExpenses,
                  color: AppColors.getBackgroundColor(context),
                  icon: Icons.receipt_long_outlined,
                  formatter: compactFormatter,
                  onTap: onNonStockExpensesTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniCategoryCard({
    required BuildContext context,
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
    required NumberFormat formatter,
    VoidCallback? onTap,
  }) {
    final textPrimary = AppColors.getTextPrimaryColor(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),

          border: Border.all(
            color: AppColors.getBorderColor(context),
          ),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ICON + LABEL
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.getTextSecondaryColor(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: AppColors.getTextSecondaryColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // VALUE
            Text(
              formatter.format(amount),
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}