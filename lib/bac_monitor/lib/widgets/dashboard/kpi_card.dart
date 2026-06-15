import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../additions/colors.dart';
import '../../models/trend_direction.dart';
import '../../controllers/mon_gross_profit_controller.dart';

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? unit;
  final String? trendValue;
  final TrendDirection trendDirection;
  final String? trendReference;
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
    final textTertiary = textSecondary.withValues(alpha: 0.5);
    final primaryLight = AppColors.getPrimaryLightColor(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.getCardColor(context),
        border: Border.all(
          color: AppColors.getBorderColor(context),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card title ──────────────────────────────────────────
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: primaryLight,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),

          const SizedBox(height: 16),

          // ── Main section: primary metric + divider + mini KPIs ──
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primary metric
                Expanded(
                  flex: 5,
                  child: _PrimaryMetric(
                    value: value,
                    unit: unit,
                    trendValue: trendValue,
                    trendDirection: trendDirection,
                    trendReference: trendReference,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    textTertiary: textTertiary,
                  ),
                ),

                // Divider
                Container(
                  width: 0.5,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        textPrimary.withValues(alpha: 0),
                        textPrimary.withValues(alpha: 0.18),
                        textPrimary.withValues(alpha: 0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Mini KPIs
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

          Container(
            height: 0.5,
            color: AppColors.getBorderColor(context),
            margin: const EdgeInsets.only(bottom: 14),
          ),

          Obx(() => _buildEfrisStatusRow(context)),
        ],
      ),
    );
  }

  Widget _buildEfrisStatusRow(BuildContext context) {
    final controller = Get.find<MonGrossProfitController>();
    final textTertiary =
    AppColors.getTextSecondaryColor(context).withValues(alpha: 0.5);

    const pendingColor = Color(0xFFFFC107);
    const uploadedColor = Color(0xFF4CAF50);
    const failedColor = Color(0xFFF44336);

    return Row(
      children: [
        Icon(Icons.receipt_long_rounded, color: textTertiary, size: 13),
        const SizedBox(width: 5),
        Text(
          'EFRIS',
          style: TextStyle(
            color: textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
        ),
        const Spacer(),
        _EfrisChip(
          label: 'P',
          value: controller.efrisPending.value,
          color: pendingColor,
        ),
        const SizedBox(width: 4),
        _EfrisChip(
          label: 'U',
          value: controller.efrisUploaded.value,
          color: uploadedColor,
        ),
        const SizedBox(width: 4),
        _EfrisChip(
          label: 'F',
          value: controller.efrisFailed.value,
          color: failedColor,
        ),
      ],
    );
  }
}

// ── Primary metric block ─────────────────────────────────────────────────────

class _PrimaryMetric extends StatelessWidget {
  final String value;
  final String? unit;
  final String? trendValue;
  final TrendDirection trendDirection;
  final String? trendReference;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  const _PrimaryMetric({
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    this.unit,
    this.trendValue,
    this.trendDirection = TrendDirection.none,
    this.trendReference,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (unit != null) ...[
          Text(
            unit!,
            style: TextStyle(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
        ],
        Text(
          value,
          style: TextStyle(
            color: textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            height: 1,
          ),
        ),
        if (trendDirection != TrendDirection.none && trendValue != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              _TrendBadge(
                value: trendValue!,
                direction: trendDirection,
              ),
              if (trendReference != null) ...[
                const SizedBox(width: 6),
                Text(
                  trendReference!,
                  style: TextStyle(
                    color: textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

// ── Mini KPI row ─────────────────────────────────────────────────────────────

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

class _MiniKpiRow extends StatelessWidget {
  final MiniKpiData data;

  const _MiniKpiRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final accent = data.accentColor ?? AppColors.getInfoColor(context);
    final textPrimary = AppColors.getTextPrimaryColor(context);
    final textTertiary =
    AppColors.getTextSecondaryColor(context).withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                data.label,
                style: TextStyle(
                  color: textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Value row
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'UGX',
                  style: TextStyle(
                    color: textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  data.value,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1,
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

// ── Trend badge ───────────────────────────────────────────────────────────────

class _TrendBadge extends StatelessWidget {
  final String value;
  final TrendDirection direction;

  const _TrendBadge({required this.value, required this.direction});

  @override
  Widget build(BuildContext context) {
    final isUp = direction == TrendDirection.up;
    final color = isUp
        ? AppColors.getSuccessColor(context)
        : AppColors.getErrorColor(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          color: color,
          size: 11,
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── EFRIS chip ────────────────────────────────────────────────────────────────

class _EfrisChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _EfrisChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.getTextPrimaryColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            '$label - $value',
            style: TextStyle(
              color: textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}