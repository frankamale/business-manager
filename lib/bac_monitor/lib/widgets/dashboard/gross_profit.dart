import '../../additions/colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GrossProfitCard extends StatelessWidget {
  final double grossProfit;
  final double totalSales;
  final double cogs;
  final double previousPeriodProfit;

  const GrossProfitCard({
    super.key,
    required this.grossProfit,
    required this.totalSales,
    required this.cogs,
    required this.previousPeriodProfit,
  });

  @override
  Widget build(BuildContext context) {
    final double changePercentage = previousPeriodProfit > 0
        ? ((grossProfit - previousPeriodProfit) / previousPeriodProfit) * 100
        : (grossProfit > 0 ? 100.0 : 0.0);

    final double profitMargin = totalSales > 0 ? (grossProfit / totalSales) * 100 : 0.0;

    final bool isPositiveChange = grossProfit >= previousPeriodProfit;
    final compactFormatter = NumberFormat.compact(locale: 'en_US');

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            PrimaryColors.lightBlue.withOpacity(0.9),
            PrimaryColors.darkBlue.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Title
          const Text(
            'Gross Profit',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),

          // 2. Hero Metric and Trend Indicator
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                compactFormatter.format(grossProfit),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                ),
              ),
              const SizedBox(width: 12),
              _buildTrendIndicator(isPositiveChange, changePercentage),
            ],
          ),
          const SizedBox(height: 20),

          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 12),

          _buildDetailRow('Total Sales', compactFormatter.format(totalSales)),
          const SizedBox(height: 8),
          _buildDetailRow('Cost of Goods Sold (COGS)', compactFormatter.format(cogs)),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 12),

          _buildDetailRow(
              'Profit Margin',
              '${profitMargin.toStringAsFixed(1)}%',
              isHighlighted: true
          ),
        ],
      ),
    );
  }

  /// A helper widget for the trend indicator (e.g., +15.2%)
  Widget _buildTrendIndicator(bool isPositive, double percentage) {
    final Color trendColor = isPositive ? Colors.greenAccent[400]! : Colors.redAccent[400]!;
    final IconData trendIcon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon, color: trendColor, size: 16),
          const SizedBox(width: 4),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              color: trendColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// A helper widget to create consistent rows for the breakdown.
  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlighted ? Colors.cyanAccent[100] : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isHighlighted ? 16 : 14,
          ),
        ),
      ],
    );
  }
}