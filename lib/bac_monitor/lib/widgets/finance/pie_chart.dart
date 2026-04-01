import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../additions/colors.dart';
import '../../models/finanacial_data.dart';

class ExpensesPieChart extends StatelessWidget {
  final List<ExpenseCategory> expenses;

  const ExpensesPieChart({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final totalExpenses = expenses.fold<double>(0, (sum, item) => sum + item.amount);

    return AspectRatio(
      aspectRatio: 1.8,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 0,
                sections: expenses.asMap().entries.map((entry) {
                  final category = entry.value;
                  final percentage = (category.amount / totalExpenses) * 100;

                  return PieChartSectionData(
                    color: category.color,
                    value: category.amount,
                    radius: 80,
                    title: '${percentage.toStringAsFixed(0)}%',
                    titleStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimaryColor(context),
                      shadows: [Shadow(color: AppColors.getShadowColor(context), blurRadius: 2)],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: expenses.map((category) => _buildLegendItem(context, category)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, ExpenseCategory category) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.rectangle, // Or BoxShape.circle
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              category.name,
              style: TextStyle(color: AppColors.getTextSecondaryColor(context), fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}