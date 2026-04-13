import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:bac_pos/back_pos/controllers/expenses_controller.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../additions/colors.dart';
import '../../controllers/mon_dashboard_controller.dart';
import '../finance/date_range.dart';

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

  DateTime _getStartDate(DateRange range, DateTimeRange? customRange) {
    final now = DateTime.now();
    switch (range) {
      case DateRange.today:
        return DateTime(now.year, now.month, now.day);
      case DateRange.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTime(yesterday.year, yesterday.month, yesterday.day);
      case DateRange.last7Days:
        final start = now.subtract(const Duration(days: 6));
        return DateTime(start.year, start.month, start.day);
      case DateRange.monthToDate:
        return DateTime(now.year, now.month, 1);
      case DateRange.custom:
        return customRange?.start ?? DateTime(now.year, now.month, now.day);
    }
  }

  DateTime _getEndDate(DateRange range, DateTimeRange? customRange) {
    final now = DateTime.now();
    switch (range) {
      case DateRange.today:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case DateRange.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
      case DateRange.last7Days:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case DateRange.monthToDate:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case DateRange.custom:
        return customRange?.end ?? DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compactFormatter = NumberFormat.compact();
    final cardColor = AppColors.getCardColor(context);
    final borderColor = AppColors.getBorderColor(context);
    final textPrimary = AppColors.getTextPrimaryColor(context);
    final textSecondary = AppColors.getTextSecondaryColor(context);

    return Obx(() {
      final expensesController = Get.find<ExpensesController>();
      final dateController = Get.find<MonDashboardController>();
      final isLoading = expensesController.isLoading.value || expensesController.expenses.isEmpty;
      
      final selectedRange = dateController.selectedRange.value;
      final customRange = dateController.customRange.value;
      final startDate = _getStartDate(selectedRange, customRange);
      final endDate = _getEndDate(selectedRange, customRange);
      
      final expenses = expensesController.expenses.where((e) {
        final expenseDate = e.date;
        final afterStart = !expenseDate.isBefore(startDate);
        final beforeEnd = !expenseDate.isAfter(endDate);
        return afterStart && beforeEnd;
      }).toList();
      
      final totalExpense = expenses.fold(0.0, (sum, e) => sum + e.amount);
      final stockExpenses = expenses.where((e) => e.category == 'Stock').fold(0.0, (sum, e) => sum + e.amount);
      final nonStockExpenses = expenses.where((e) => e.category != 'Stock').fold(0.0, (sum, e) => sum + e.amount);

      return Skeletonizer(
        enabled: isLoading,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Expenses',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!isLoading && expensesController.pendingExpenses.isNotEmpty)
                        GestureDetector(
                          onTap: () => expensesController.syncPendingExpenses(),
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sync,
                                  size: 10,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${expensesController.pendingExpenses.length}',
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
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
                      label: 'Non-Stock Payments',
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

          border: Border.all(color: AppColors.getBorderColor(context)),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ICON + LABEL
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: AppColors.getTextSecondaryColor(context),
                ),
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
