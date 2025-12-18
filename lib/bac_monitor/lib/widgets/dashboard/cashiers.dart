import '../../additions/colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/dashboard.dart';

class CashierSalesChart extends StatelessWidget {
  final List<dynamic> salesData;
  final String? periodLabel;

  const CashierSalesChart({
    super.key,
    required this.salesData,
    this.periodLabel,
  });

  static const List<Color> _barColors = [
    Color(0xffF7B32B),
    Color(0xffD95D39),
    Color(0xff4392F1),
    Color(0xff58FADD),
    Color(0xffA846A0),
  ];

  /// Processes raw sales data to group totals by 'salesperson'.
  List<CashierData> _processData() {
    final Map<String, double> salesByCashier = {};

    for (final sale in salesData) {
      String cashierName = (sale['salesperson'] as String?)?.trim() ?? 'Unknown Cashier';

      // Handle empty cashier names
      if (cashierName.isEmpty) {
        cashierName = 'Unknown Cashier';
      }

      final amount = (sale['amount'] as num?)?.toDouble() ?? 0.0;

      salesByCashier.update(
        cashierName,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    }

    final processedList = salesByCashier.entries
        .map(
          (entry) =>
              CashierData(cashierName: entry.key, totalAmount: entry.value),
        )
        .toList();

    processedList.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return processedList;
  }

  @override
  Widget build(BuildContext context) {
    final processedData = _processData();
    final double totalSales = processedData.fold(
      0.0,
      (sum, item) => sum + item.totalAmount,
    );
    final double maxValue = processedData.fold(
      0.0,
      (max, current) => current.totalAmount > max ? current.totalAmount : max,
    );

    if (processedData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: PrimaryColors.lightBlue.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            "No cashier sales data available.",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: PrimaryColors.lightBlue.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Summary by Cashier",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (periodLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              periodLabel!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 12),

          Column(
            children: processedData.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              final color = _barColors[index % _barColors.length];
              return _buildBarRow(
                name: data.cashierName,
                value: data.totalAmount,
                totalValue: totalSales,
                maxValue: maxValue > 0 ? maxValue : 1.0,
                color: color,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarRow({
    required String name,
    required double value,
    required double totalValue,
    required double maxValue,
    required Color color,
  }) {
    final formatter = NumberFormat.compact(locale: 'en_US');
    final formattedValue = formatter.format(value);
    final percentage = totalValue > 0 ? (value / totalValue) * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '(${percentage.toStringAsFixed(0)}%)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formattedValue,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = (value / maxValue) * constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    height: 8,
                    width: barWidth.isNaN ? 0 : barWidth,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.5)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
