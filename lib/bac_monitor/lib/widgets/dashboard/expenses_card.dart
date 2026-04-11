import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:bac_pos/back_pos/controllers/expenses_controller.dart';
import '../../additions/colors.dart';

class ExpensesCard extends StatelessWidget {
  final String periodLabel;
  final VoidCallback? onStockExpensesTap;
  final VoidCallback? onNonStockExpensesTap;

  const ExpensesCard({
    super.key,
    required this.periodLabel,
    this.onStockExpensesTap,
    this.onNonStockExpensesTap,
  });

@override
  Widget build(BuildContext context) {
    final compactFormatter = NumberFormat.compact();
    final cardColor = AppColors.getCardColor(context);
    final borderColor = AppColors.getBorderColor(context);
    final textPrimary = AppColors.getTextPrimaryColor(context);
    final textSecondary = AppColors.getTextSecondaryColor(context);

    return Obx(() {
      final expensesController = Get.find<ExpensesController>();
      final expenses = expensesController.expenses;
      final totalExpense = expenses.fold(0.0, (sum, e) => sum + e.amount);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(
              'UGX ${compactFormatter.format(totalExpense)}',
              style: TextStyle(
                color: textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniCategoryCard(
                    context: context,
                    label: 'Stock Purchases',
                    amount: 0.0,
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
                    label: 'Non-Stock Payments',
                    amount: totalExpense,
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
    });
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