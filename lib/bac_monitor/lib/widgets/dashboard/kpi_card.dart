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

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    this.trendValue,
    this.trendReference,
    this.trendDirection = TrendDirection.none,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: PrimaryColors.lightBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center, // Center vertically
          children: [
            // Title remains aligned to the start
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: const TextStyle(
                  color: PrimaryColors.brightYellow,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 6),
            // Center the Row containing unit and value
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (unit != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0, bottom: 1.0),
                        child: Text(
                          unit!,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (trendValue != null) _buildTrendSection(),
          ],
        ),
      ),
    );
  }

  /// Helper widget to build a more compact trend section.
  Widget _buildTrendSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (trendDirection != TrendDirection.none)
              Icon(
                trendDirection == TrendDirection.up
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                color: trendDirection == TrendDirection.up
                    ? Colors.greenAccent
                    : Colors.redAccent,
                size: 15,
              ),
            if (trendDirection != TrendDirection.none) const SizedBox(width: 4),
            Expanded(
              child: Text(
                trendValue!,
                style: TextStyle(
                  color: trendDirection == TrendDirection.up
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (trendReference != null)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              trendReference!,
              style: const TextStyle(
                color: PrimaryColors.brightYellow,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
