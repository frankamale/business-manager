import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dashboard.dart';
import '../../additions/colors.dart';
import '../finance/date_range.dart';

class SalesTrendLineGraph extends StatelessWidget {
  final List<SalesDataPoint> salesData;
  final DateRange dateRange;
  final DateTimeRange? customRange;
  final String aggregationType;

  const SalesTrendLineGraph({
    super.key,
    required this.salesData,
    required this.dateRange,
    this.customRange,
    required this.aggregationType,
  });

  @override
  Widget build(BuildContext context) {
    // Show empty state if no data
    if (salesData.isEmpty) {
      return const Center(
        child: Text(
          'No sales data available for this period',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    final maxY = _calculateMaxY();
    final lineBarData = _mainLine();

    return LineChart(
      LineChartData(
        backgroundColor: PrimaryColors.light.withOpacity(0.1),
        showingTooltipIndicators: salesData.asMap().entries.map((entry) {
          return ShowingTooltipIndicators([
            LineBarSpot(lineBarData, entry.key, lineBarData.spots[entry.key]),
          ]);
        }).toList(),
        lineBarsData: [lineBarData],
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(
              color: Colors.white70,
              width: 1,
              style: BorderStyle.solid,
            ),
            bottom: BorderSide(
              color: Colors.white70,
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
        ),
        gridData: _mainGridData(maxY),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => _leftTitles(value, meta),
              reservedSize: 50,
              interval: maxY / 5,
            ),
            axisNameWidget: const Text(
              'Amount (UGX)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            axisNameSize: 18,
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => _bottomTitles(value, meta),
              reservedSize: 42,
              interval: _getBottomTitleInterval(),
            ),
            axisNameWidget: const Text(
              'Time Period',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            axisNameSize: 18,
          ),
        ),
        minY: 0,
        maxY: maxY,
        lineTouchData: _lineTouchData(),
        clipData: const FlClipData.none(),
      ),
    );
  }

  // -------------------- AXIS CALCULATION HELPERS --------------------

  double _calculateMaxY() {
    if (salesData.isEmpty) return 1000.0;

    final maxVal = salesData
        .map((e) => e.amount)
        .reduce((a, b) => a > b ? a : b);

    // If all values are zero, return a default
    if (maxVal == 0) return 1000.0;

    // Calculate a nice round number for the max Y value
    // Round up to nearest power of 10
    final orderOfMagnitude = pow(10, (log(maxVal) / ln10).floor()).toDouble();
    final normalizedMax = maxVal / orderOfMagnitude;

    double niceMax;
    if (normalizedMax <= 1) {
      niceMax = 1;
    } else if (normalizedMax <= 2) {
      niceMax = 2;
    } else if (normalizedMax <= 5) {
      niceMax = 5;
    } else {
      niceMax = 10;
    }

    final calculatedMax = (niceMax * orderOfMagnitude * 1.1);
    return calculatedMax.clamp(100.0, double.infinity);
  }

  double _getBottomTitleInterval() {
    if (salesData.isEmpty) return 1.0;

    switch (dateRange) {
      case DateRange.today:
      case DateRange.yesterday:
        // Show every 3-hour interval (8 labels for 24 hours)
        return 1.0;

      case DateRange.last7Days:
        // Show every day (7 labels)
        return 1.0;

      case DateRange.monthToDate:
        // Adaptive interval based on days elapsed in month
        final numDays = salesData.length;
        if (numDays <= 7) {
          return (numDays <= 4) ? 1.0 : 2.0;
        } else if (numDays <= 14) {
          return 3.0;
        } else if (numDays <= 21) {
          return 4.0;
        } else {
          return 5.0;
        }

      case DateRange.custom:
        final durationDays = customRange != null
            ? customRange!.end.difference(customRange!.start).inDays + 1
            : 7;

        if (durationDays <= 1) {
          // Single day: Show every 3-hour interval
          return 1.0;
        } else if (durationDays <= 7) {
          // Week: Show every day
          return 1.0;
        } else if (durationDays <= 31) {
          // Month: Show approximately every 5 days
          return (salesData.length / 6).clamp(1.0, 5.0);
        } else if (durationDays <= 90) {
          // Up to 3 months: Show about 6-8 labels
          return (salesData.length / 6).ceilToDouble().clamp(1.0, double.infinity);
        } else if (durationDays <= 365) {
          // Up to a year: Show every month
          return (salesData.length / 12).ceilToDouble().clamp(1.0, double.infinity);
        } else {
          // More than a year: Show every 2-3 months
          return (salesData.length / 8).ceilToDouble().clamp(1.0, double.infinity);
        }

      default:
        return 1.0;
    }
  }

  // -------------------- CHART APPEARANCE --------------------

  LineChartBarData _mainLine() {
    return LineChartBarData(
      spots: salesData
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value.amount))
          .toList(),
      isCurved: true,
      color: PrimaryColors.brightYellow,
      barWidth: 4,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 4,
          color: PrimaryColors.brightYellow,
          strokeWidth: 2,
          strokeColor: Colors.white70,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            PrimaryColors.brightYellow.withOpacity(0.3),
            PrimaryColors.brightYellow.withOpacity(0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  FlGridData _mainGridData(double maxY) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      drawHorizontalLine: true,
      horizontalInterval: maxY / 5,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Colors.white70.withOpacity(0.3),
          strokeWidth: 1,
          dashArray: [5, 5],
        );
      },
    );
  }

  LineTouchData _lineTouchData() {
    return LineTouchData(
      enabled: true,
      handleBuiltInTouches: false,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => Colors.transparent,
        tooltipPadding: const EdgeInsets.only(bottom: -7.0),
        fitInsideHorizontally: false,
        fitInsideVertically: true,
        getTooltipItems: (List<LineBarSpot> touchedSpots) {
          return touchedSpots.map((barSpot) {
            // Format with appropriate suffix
            String formattedValue;
            final value = barSpot.y;
            if (value >= 1000000000) {
              formattedValue = '${(value / 1000000000).toStringAsFixed(1)}B';
            } else if (value >= 1000000) {
              formattedValue = '${(value / 1000000).toStringAsFixed(1)}M';
            } else if (value >= 1000) {
              formattedValue = '${(value / 1000).toStringAsFixed(1)}K';
            } else {
              formattedValue = NumberFormat('#,###').format(value);
            }

            return LineTooltipItem(
              formattedValue,
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            );
          }).toList();
        },
      ),
      getTouchedSpotIndicator:
          (LineChartBarData barData, List<int> spotIndexes) {
            return spotIndexes.map((spotIndex) {
              return TouchedSpotIndicatorData(
                const FlLine(color: Colors.transparent),
                FlDotData(show: false),
              );
            }).toList();
          },
    );
  }

  // -------------------- LABELS --------------------

  Widget _bottomTitles(double value, TitleMeta meta) {
    final int index = value.toInt();
    if (index < 0 || index >= salesData.length) return const Text('');

    final date = salesData[index].date;
    String text;

    switch (dateRange) {
      case DateRange.today:
      case DateRange.yesterday:
        // Show hours in 3-hour intervals: 00, 03, 06, 09, 12, 15, 18, 21
        text = DateFormat('HH').format(date);
        break;

      case DateRange.last7Days:
        // Show day names: Sun, Mon, Tue, Wed, Thu, Fri, Sat
        text = DateFormat('EEE').format(date);
        break;

      case DateRange.monthToDate:
        // Adaptive intervals based on how many days have passed in the month
        final numDays = salesData.length;
        final isFirstDay = index == 0;
        final isLastDay = index == salesData.length - 1;

        // Calculate optimal interval to show 5-7 labels
        int interval;
        if (numDays <= 7) {
          // First week: Show every day or every 2 days
          interval = numDays <= 4 ? 1 : 2;
        } else if (numDays <= 14) {
          // First 2 weeks: Show every 2-3 days
          interval = 3;
        } else if (numDays <= 21) {
          // First 3 weeks: Show every 3-4 days
          interval = 4;
        } else {
          // Rest of month: Show every 5 days
          interval = 5;
        }

        // Show label at regular intervals, plus first and last days
        final shouldShowLabel = index % interval == 0;

        if (isFirstDay || isLastDay || shouldShowLabel) {
          // For first week, show day name + date for clarity
          if (numDays <= 7) {
            text = DateFormat('EEE\nd').format(date); // "Mon\n1"
          } else {
            text = DateFormat('MMM d').format(date); // "Nov 1"
          }
        } else {
          return const Text('');
        }
        break;

      case DateRange.custom:
        final durationDays = customRange != null
            ? customRange!.end.difference(customRange!.start).inDays + 1
            : 7;

        if (durationDays <= 1) {
          // Single day: Show hours (00, 03, 06, 09...)
          text = DateFormat('HH').format(date);
        } else if (durationDays <= 7) {
          // Week or less: Show day names (Sun, Mon, Tue...)
          text = DateFormat('EEE').format(date);
        } else if (durationDays <= 31) {
          // Month or less: Show dates at intervals (Nov 1, Nov 6, Nov 11...)
          final isFirstDay = index == 0;
          final isLastDay = index == salesData.length - 1;
          // Show label every ~5 days
          final shouldShowLabel = index % 5 == 0;

          if (isFirstDay || isLastDay || shouldShowLabel) {
            text = DateFormat('MMM d').format(date);
          } else {
            return const Text('');
          }
        } else if (durationDays <= 90) {
          // Up to 3 months: Show dates at wider intervals
          final shouldShowLabel = index % ((salesData.length / 6).ceil()) == 0;
          if (shouldShowLabel || index == 0 || index == salesData.length - 1) {
            text = DateFormat('MMM d').format(date);
          } else {
            return const Text('');
          }
        } else if (durationDays <= 365) {
          // Up to a year: Show month names (Jan, Feb, Mar...)
          text = DateFormat('MMM').format(date);
        } else {
          // More than a year: Show month and year (Jan '24, Feb '24...)
          text = DateFormat('MMM yy').format(date);
        }
        break;

      default:
        text = DateFormat('M/d').format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _leftTitles(double value, TitleMeta meta) {
    // Don't show label at the very top to avoid overlap
    if (value == meta.max) return const Text('');

    // Calculate interval
    final interval = meta.max / 5;

    // Show 0 baseline and labels at interval boundaries
    final isZero = value == 0;
    final isAtInterval = interval > 0 && (value % interval).abs() < (interval * 0.01);

    if (!isZero && !isAtInterval) return const Text('');

    String text;
    if (value == 0) {
      text = '0';
    } else if (value >= 1000000000) {
      text = '${(value / 1000000000).toStringAsFixed(value >= 10000000000 ? 0 : 1)}B';
    } else if (value >= 1000000) {
      text = '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    } else if (value >= 1000) {
      text = '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    } else {
      text = value.toStringAsFixed(0);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }
}
