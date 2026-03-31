import '../../additions/colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GrossProfitCard extends StatelessWidget {
  final double grossProfit;
  final String trend;

  const GrossProfitCard({
    super.key,
    required this.grossProfit,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final compactFormatter = NumberFormat.compact(locale: 'en_US');

    // Parse trend to determine direction
    final trendValue = double.tryParse(
      trend.replaceAll('%', '').replaceAll('+', '').replaceAll('-', '')
    ) ?? 0.0;
    final isPositive = trend.startsWith('+');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: LightColors.card,
        boxShadow: [
          BoxShadow(
            color: LightColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative glow blob top-right
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF26A69A).withOpacity(0.25),
                    const Color(0xFF26A69A).withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category label pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: LightColors.secondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: LightColors.secondary.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'GROSS PROFIT',
                    style: TextStyle(
                      color: LightColors.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Big value
                Text(
                  compactFormatter.format(grossProfit),
                  style: TextStyle(
                    color: LightColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),

                // Trend row
                const SizedBox(height: 6),
                _TrendBadge(
                  isPositive: isPositive,
                  percentage: trendValue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Trend badge
// ─────────────────────────────────────────────────────────────
class _TrendBadge extends StatelessWidget {
  final bool isPositive;
  final double percentage;

  const _TrendBadge({
    required this.isPositive,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? LightColors.success : LightColors.error;
    final bgColor = color.withOpacity(0.12);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.35), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: color,
                size: 12,
              ),
              const SizedBox(width: 3),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'vs last period',
          style: TextStyle(
            color: LightColors.textSecondary.withOpacity(0.4),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}