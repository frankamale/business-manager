import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseStatisticsDialog extends StatelessWidget {
  final Map<String, double> categoryTotals;
  final List<MapEntry<String, double>> sortedTotals;
  final double totalAmount;
  final int expenseCount;
  final NumberFormat currencyFormatter;
  final Color color;

  const ExpenseStatisticsDialog({
    super.key,
    required this.categoryTotals,
    required this.sortedTotals,
    required this.totalAmount,
    required this.expenseCount,
    required this.currencyFormatter,
    required this.color,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, double> categoryTotals,
    required List<MapEntry<String, double>> sortedTotals,
    required double totalAmount,
    required int expenseCount,
    required NumberFormat currencyFormatter,
    required Color color,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpenseStatisticsDialog(
        categoryTotals: categoryTotals,
        sortedTotals: sortedTotals,
        totalAmount: totalAmount,
        expenseCount: expenseCount,
        currencyFormatter: currencyFormatter,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
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
                    Icons.bar_chart,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Expense Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
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
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Summary cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          label: 'Total',
                          value: currencyFormatter.format(totalAmount),
                          icon: Icons.account_balance_wallet,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          label: 'Items',
                          value: expenseCount.toString(),
                          icon: Icons.receipt_long,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (expenseCount > 0)
                    _buildSummaryCard(
                      label: 'Average',
                      value: currencyFormatter.format(totalAmount / expenseCount),
                      icon: Icons.trending_up,
                    ),
                  const SizedBox(height: 24),
                  // Category breakdown
                  const Text(
                    'Category Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (sortedTotals.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.pie_chart_outline,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No expenses to analyze',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...sortedTotals.map((entry) {
                      final percentage = totalAmount > 0 
                          ? (entry.value / totalAmount * 100) 
                          : 0.0;
                      return _buildCategoryBar(
                        category: entry.key,
                        amount: entry.value,
                        percentage: percentage,
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar({
    required String category,
    required double amount,
    required double percentage,
  }) {
    final barColor = _getCategoryColor(category);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                currencyFormatter.format(amount),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (percentage / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.cyan,
      Colors.indigo,
    ];
    final index = category.hashCode.abs() % colors.length;
    return colors[index];
  }
}