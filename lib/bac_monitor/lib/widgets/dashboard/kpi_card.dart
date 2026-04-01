import 'package:flutter/material.dart';
import '../../additions/colors.dart';
import '../../models/trend_direction.dart';

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? unit;
  final String? trendValue;
  final TrendDirection trendDirection;
  final String? trendReference;

  // Sub-metrics shown on the right side
  final List<MiniKpiData> miniKpis;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    this.trendValue,
    this.trendReference,
    this.trendDirection = TrendDirection.none,
    this.miniKpis = const [],
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.getTextPrimaryColor(context);
    final textSecondary = AppColors.getTextSecondaryColor(context);
    final primaryLight = AppColors.getPrimaryLightColor(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.getCardColor(context),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: Stack(
        children: [
          // Decorative glow blob top-right
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Category label pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        child: Text(
                          title.toUpperCase(),
                          style: TextStyle(
                            color: primaryLight,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Big value
                      RichText(
                        text: TextSpan(
                          children: [
                            if (unit != null)
                              TextSpan(
                                text: '$unit  ',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            TextSpan(
                              text: value,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Trend row
                      if (trendDirection != TrendDirection.none &&
                          trendValue != null) ...[
                        const SizedBox(height: 6),
                        _TrendBadge(
                          value: trendValue!,
                          direction: trendDirection,
                          reference: trendReference,
                        ),
                      ],
                    ],
                  ),
                ),

                // Vertical divider
                Container(
                  width: 1,
                  height: 64,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        textPrimary.withOpacity(0),
                        textPrimary.withOpacity(0.18),
                        textPrimary.withOpacity(0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // ── RIGHT: mini KPIs ────────────────────────────────────
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: miniKpis
                        .map((kpi) => _MiniKpiRow(data: kpi))
                        .toList(),
                  ),
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
// Mini KPI data model
// ─────────────────────────────────────────────────────────────
class MiniKpiData {
  final String label;
  final String value;
  final Color? accentColor;

  const MiniKpiData({
    required this.label,
    required this.value,
    this.accentColor,
  });
}

// ─────────────────────────────────────────────────────────────
// Mini KPI row
// ─────────────────────────────────────────────────────────────
class _MiniKpiRow extends StatelessWidget {
  final MiniKpiData data;

  const _MiniKpiRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final accent = data.accentColor ?? AppColors.getInfoColor(context);
    final textPrimary = AppColors.getTextPrimaryColor(context);
    final textSecondary = AppColors.getTextSecondaryColor(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                data.label,
                style: TextStyle(
                  color: textSecondary.withOpacity(0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Text(
                  "UGX",
                  style: TextStyle(
                    color: textSecondary.withOpacity(0.55),
                    fontSize: 12,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  data.value,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
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
  final String value;
  final TrendDirection direction;
  final String? reference;

  const _TrendBadge({
    required this.value,
    required this.direction,
    this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = direction == TrendDirection.up;
    final color = isUp ? AppColors.getSuccessColor(context) : AppColors.getErrorColor(context);
    final textSecondary = AppColors.getTextSecondaryColor(context);

    return Row(
      children: [

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUp
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: color,
                size: 12,
              ),
              const SizedBox(width: 3),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (reference != null) ...[
          const SizedBox(width: 6),
          Text(
            reference!,
            style: TextStyle(
              color: textSecondary.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
