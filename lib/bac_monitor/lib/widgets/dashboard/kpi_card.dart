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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: PrimaryColors.lightBlue

      ),
      child: Stack(
        children: [
          // Decorative glow blob top-right

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
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
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: const Color(0xFFFFC107).withOpacity(0.4),
                              width: 1),
                        ),
                        child: Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFFFC107),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
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
                                style: const TextStyle(
                                  color: Color(0xFF90A8D0),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            TextSpan(
                              text: value,
                              style: const TextStyle(
                                color: Colors.white,
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
                        Colors.white.withOpacity(0),
                        Colors.white.withOpacity(0.18),
                        Colors.white.withOpacity(0),
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
    final accent = data.accentColor ?? const Color(0xFF4FC3F7);
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
                  color: Colors.white.withOpacity(0.55),
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
            child: Text(
              data.value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
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
    final color = isUp ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);
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
                isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
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
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}


