import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../additions/colors.dart';
import '../../models/sales.dart';

class DailySalesLineChart extends StatelessWidget {
  final List<DailySales> salesData;

  const DailySalesLineChart({super.key, required this.salesData});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.7,
      child: LineChart(
        LineChartData(
          backgroundColor: PrimaryColors.light.withOpacity(0.1),
          lineBarsData: [_mainLine()],
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(
                color: Colors.white.withOpacity(0.5),
                width: 1,
                style: BorderStyle.solid,
              ),
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.5),
                width: 1,
                style: BorderStyle.solid,
              ),
            ),
          ),
          gridData: _mainGridData(),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: _leftTitles,
                reservedSize: 40,
                interval:
                    (salesData.isNotEmpty
                            ? (salesData
                                      .map((e) => e.sales)
                                      .reduce((a, b) => a > b ? a : b) /
                                  5)
                            : 1)
                        .ceil()
                        .toDouble(),
              ),
              axisNameWidget: const Text(
                'Sales', // Match axis name
                style: TextStyle(
                  color: PrimaryColors.brightYellow,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              axisNameSize: 24,
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
                getTitlesWidget: _bottomTitles,
                reservedSize: 38,
                interval: 1,
              ),
              axisNameWidget: const Text(
                'Day', // Match axis name
                style: TextStyle(
                  color: PrimaryColors.brightYellow,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              axisNameSize: 24,
            ),
          ),
          lineTouchData: _mainTouchData(),
        ),
      ),
    );
  }

  /// Creates the main line for the chart from the sales data.
  LineChartBarData _mainLine() {
    return LineChartBarData(
      spots: _getSpots(),
      isCurved: true,
      color: PrimaryColors.brightYellow,
      barWidth: 4,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
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

  /// Maps the sales data to a list of FlSpot objects for the chart.
  List<FlSpot> _getSpots() {
    return salesData.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final sales = entry.value.sales;
      return FlSpot(index, sales);
    }).toList();
  }

  /// Configures the grid lines.
  FlGridData _mainGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      drawHorizontalLine: true,
      horizontalInterval:
          (salesData.isNotEmpty
                  ? (salesData
                            .map((e) => e.sales)
                            .reduce((a, b) => a > b ? a : b) /
                        5)
                  : 1)
              .ceil()
              .toDouble(),
      // Match dynamic interval
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Colors.white.withOpacity(0.3),
          strokeWidth: 1,
          dashArray: [5, 5],
        );
      },
    );
  }

  /// Configures the tooltips that appear on touch.
  LineTouchData _mainTouchData() {
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (List<LineBarSpot> touchedSpots) {
          return touchedSpots.map((spot) {
            final day = salesData[spot.spotIndex].day;
            final sales = spot.y.toStringAsFixed(2);
            return LineTooltipItem(
              '$day\n',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: '\$$sales',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            );
          }).toList();
        },
      ),
    );
  }

  /// Creates the labels for the bottom (X) axis.
  Widget _bottomTitles(double value, TitleMeta meta) {
    final int index = value.toInt();
    if (index < 0 || index >= salesData.length) {
      return const Text('');
    }
    final String text = salesData[index].day;
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  /// Creates the labels for the left (Y) axis.
  Widget _leftTitles(double value, TitleMeta meta) {
    final String text = value.toInt().toString();
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
      ),
    );
  }
}
