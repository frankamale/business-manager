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
    final cardColor = AppColors.getCardColor(context);
    final shadowColor = AppColors.getShadowLightColor(context);
    final textPrimary = AppColors.getTextPrimaryColor(context);
    final textSecondary = AppColors.getTextSecondaryColor(context);
    final borderColor = AppColors.getBorderColor(context);
    final secondaryColor = AppColors.getSecondaryColor(context);
    final successColor = AppColors.getSuccessColor(context);
    final errorColor = AppColors.getErrorColor(context);

    // Parse the trend value to determine if it's positive or negative
    final trendValue = _parseTrendValue(outstandingSelectedPeriodTrend);
    // For outstanding payments, increase is bad (red), decrease is good (green)
    final isPositive = trendValue < 0;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Title with Period Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Outstanding Payments',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                periodLabel,
                style: TextStyle(
                  color: textSecondary.withOpacity(0.7),
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
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                ),
              ),
              const SizedBox(width: 12),
              // _buildTrendIndicator(isPositive, trendValue.abs() * 100),
            ],
          ),
          const SizedBox(height: 20),

          Divider(color: borderColor),
          const SizedBox(height: 12),

          // 3. Detail Rows
          _buildDetailRow(context, 'Month to Date', 'UGX$outstandingMTD'),
          const SizedBox(height: 8),
          _buildDetailRow(context, 'Year to Date', 'UGX$outstandingYTD', isHighlighted: true),
        ],
      ),
    );
  }

  /// A helper widget for the trend indicator (e.g., +15.2%)
  Widget _buildTrendIndicator(BuildContext context, bool isPositive, double percentage) {
    final successColor = AppColors.getSuccessColor(context);
    final errorColor = AppColors.getErrorColor(context);
    final Color trendColor = isPositive ? successColor : errorColor;
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
  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isHighlighted = false}) {
    final textSecondary = AppColors.getTextSecondaryColor(context);
    final textPrimary = AppColors.getTextPrimaryColor(context);
    final secondaryColor = AppColors.getSecondaryColor(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textSecondary.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlighted ? secondaryColor : textPrimary,
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
