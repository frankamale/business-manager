import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../additions/colors.dart';

class ExpensesDetailPage extends StatelessWidget {
  final String expenseType; // 'stock' or 'non-stock'
  final String periodLabel;

  const ExpensesDetailPage({
    super.key,
    required this.expenseType,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isStockExpense = expenseType == 'stock';
    final compactFormatter = NumberFormat.compact(locale: 'en_US');
    final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: 'UGX', decimalDigits: 0);

    return Scaffold(
      backgroundColor: LightColors.background,
      appBar: AppBar(
        backgroundColor: LightColors.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: LightColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text(
          isStockExpense ? 'Stock Expenses' : 'Non-Stock Expenses',
          style: TextStyle(
            color: LightColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                periodLabel,
                style: TextStyle(
                  color: LightColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            _buildSummaryCard(
              isStockExpense: isStockExpense,
              compactFormatter: compactFormatter,
            ),
            const SizedBox(height: 24),

            // Breakdown Section
            Text(
              'Expense Breakdown',
              style: TextStyle(
                color: LightColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Placeholder for expense items
            _buildExpenseItemsList(
              isStockExpense: isStockExpense,
              currencyFormatter: currencyFormatter,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required bool isStockExpense,
    required NumberFormat compactFormatter,
  }) {
    // Placeholder values - will be replaced with real data
    final totalExpense = 0.0;
    final itemCount = 0;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: LightColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: LightColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LightColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isStockExpense ? Icons.inventory_2_outlined : Icons.receipt_long_outlined,
                  color: LightColors.textPrimary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total ${isStockExpense ? 'Stock' : 'Non-Stock'} Expenses',
                      style: TextStyle(
                        color: LightColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'UGX${compactFormatter.format(totalExpense)}',
                      style: TextStyle(
                        color: LightColors.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: LightColors.border),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Total Items', itemCount.toString()),
              _buildStatItem('Average', 'UGX0'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: LightColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: LightColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseItemsList({
    required bool isStockExpense,
    required NumberFormat currencyFormatter,
  }) {
    // Placeholder - no data yet
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: LightColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LightColors.border,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.data_usage_outlined,
            color: LightColors.textHint,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No expense data available',
            style: TextStyle(
              color: LightColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Expense tracking endpoint is not yet implemented.\nData will appear here once the API is ready.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LightColors.textHint,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    // When data is available, replace above with this:
    /*
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        return _buildExpenseItem(
          name: expense.name,
          amount: currencyFormatter.format(expense.amount),
          date: expense.date,
          category: expense.category,
        );
      },
    );
    */
  }

  Widget _buildExpenseItem({
    required String name,
    required String amount,
    required String date,
    String? category,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LightColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: LightColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: LightColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    color: LightColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (category != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: LightColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: LightColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: LightColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
