import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../additions/colors.dart';
class GrossProfitCard extends StatelessWidget {
  final double grossProfit;
  final String trend; // Expected format: "+12.5%" or "-8.3%"
  const GrossProfitCard({
    super.key,
    required this.grossProfit,
    required this.trend,
  });
  @override
  Widget build(BuildContext context) {
    final compactFormatter = NumberFormat.compactCurrency(
      decimalDigits: 0,
      symbol: '', // Remove currency symbol if you just want number
    );
    
    final cardColor = AppColors.getCardColor(context);
    final borderColor = AppColors.getBorderColor(context);
    final textPrimary = AppColors.getTextPrimaryColor(context);
    final textSecondary = AppColors.getTextSecondaryColor(context);
    final secondaryColor = AppColors.getSecondaryColor(context);
    final successColor = AppColors.getSuccessColor(context);
    final errorColor = AppColors.getErrorColor(context);
    final shadowColor = AppColors.getShadowColor(context);
    
    // Parse trend safely
    final trendStr = trend.replaceAll('%', '').trim();
    final trendValue = double.tryParse(trendStr) ?? 0.0;
    final isPositive = trend.startsWith('+') || trendValue > 0;
    final trendColor = isPositive ? successColor : errorColor;
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: secondaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.trending_up_rounded,
              color: secondaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Main Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gross Profit',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  compactFormatter.format(grossProfit),
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          // Trend Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: trendColor,
                    size: 16,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${trendValue.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: trendColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'vs last period',
                style: TextStyle(
                  color: textSecondary.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}