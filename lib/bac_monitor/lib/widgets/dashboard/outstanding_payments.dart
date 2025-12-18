import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../additions/colors.dart';

class OutstandingPaymentsCard extends StatelessWidget {
  final String outstandingSelectedPeriod;
  final String outstandingSelectedPeriodTrend;
  final String outstandingMTD;
  final String outstandingYTD;
  final String periodLabel;

  const OutstandingPaymentsCard({
    super.key,
    required this.outstandingSelectedPeriod,
    required this.outstandingSelectedPeriodTrend,
    required this.outstandingMTD,
    required this.outstandingYTD,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Parse the trend value to determine if it's positive or negative
    final trendValue = _parseTrendValue(outstandingSelectedPeriodTrend);
    // For outstanding payments, increase is bad (red), decrease is good (green)
    final isPositive = trendValue < 0;

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
          // 1. Title with Period Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Outstanding Payments',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                periodLabel,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Hero Metric and Trend Indicator
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'UGX$outstandingSelectedPeriod',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                ),
              ),
              const SizedBox(width: 12),
              // _buildTrendIndicator(isPositive, trendValue.abs() * 100),
            ],
          ),
          const SizedBox(height: 20),

          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 12),

          // 3. Detail Rows
          _buildDetailRow('Month to Date', 'UGX$outstandingMTD'),
          const SizedBox(height: 8),
          _buildDetailRow('Year to Date', 'UGX$outstandingYTD', isHighlighted: true),
        ],
      ),
    );
  }

  /// A helper widget for the trend indicator (e.g., +15.2%)
  Widget _buildTrendIndicator(bool isPositive, double percentage) {
    final Color trendColor = isPositive ? Colors.greenAccent[400]! : Colors.redAccent[400]!;
    final IconData trendIcon = isPositive ? Icons.arrow_downward : Icons.arrow_upward;

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

  double _parseTrendValue(String trendString) {
    try {
      // Remove % sign and parse
      final cleanString = trendString.replaceAll('%', '').trim();
      return double.parse(cleanString) / 100;
    } catch (e) {
      return 0.0;
    }
  }
}
