import 'package:bac_pos/bac_monitor/lib/widgets/finance/pie_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../additions/colors.dart';
import '../../models/finanacial_data.dart';

class ExpandableExpensesCard extends StatelessWidget {
  final List<ExpenseCategory> expenses;

  const ExpandableExpensesCard({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final totalExpenses = expenses.fold<double>(0, (sum, item) => sum + item.amount);
    final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: 'UGX ');

    return Card(
      color: AppColors.getCardColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text("Expenses Breakdown", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimaryColor(context))),
        subtitle: Text(currencyFormatter.format(totalExpenses), style: TextStyle(color: AppColors.getTextSecondaryColor(context))),
        iconColor: AppColors.getAccentColor(context),
        collapsedIconColor: AppColors.getTextSecondaryColor(context),
        childrenPadding: const EdgeInsets.all(16.0).copyWith(top: 0),
        children: [
          ExpensesPieChart(expenses: expenses),
        ],
      ),
    );
  }
}