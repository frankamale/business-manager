import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/finanacial_data.dart';
import '../../additions/colors.dart';

class NetCashFlowChart extends StatelessWidget {
  final List<CashFlowDataPoint> data;

  const NetCashFlowChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.4,
      child: LineChart(
        LineChartData(
          backgroundColor: PrimaryColors.light.withOpacity(0.1),
          lineBarsData: [_mainLine(context)],
          borderData: FlBorderData(
            show: true, // Enable axes
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
                reservedSize: 50,
                interval: (data.isNotEmpty
                    ? (data.map((e) => e.amount).reduce((a, b) => a > b ? a : b) / 5)
                    : 1)
                    .ceil()
                    .toDouble(), // Dynamic interval
              ),
              axisNameWidget: const Text(
                'Amount', // Match axis name
                style: TextStyle(
                  color: PrimaryColors.brightYellow,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              axisNameSize: 24, // Match axis name size
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: _bottomTitles,
                reservedSize: 38, // Match reserved size
                interval: (data.length / 5).ceilToDouble(), // Match interval
              ),
              axisNameWidget: const Text(
                'Date', // Match axis name
                style: TextStyle(
                  color: PrimaryColors.brightYellow,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              axisNameSize: 24, // Match axis name size
            ),
          ),
          lineTouchData: _lineTouchData(context),
        ),
      ),
    );
  }

  /// Creates the main line for the chart from the cash flow data.
  LineChartBarData _mainLine(BuildContext context) {
    return LineChartBarData(
      spots: data
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value.amount))
          .toList(),
      isCurved: true,
      color: PrimaryColors.brightYellow, // Match line color
      barWidth: 4, // Match bar width
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false), // Match: no dots
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            PrimaryColors.brightYellow.withOpacity(0.3), // Match gradient
            PrimaryColors.brightYellow.withOpacity(0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  /// Configures the grid lines.
  FlGridData _mainGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: false, // Match: no vertical lines
      drawHorizontalLine: true,
      horizontalInterval: (data.isNotEmpty
          ? (data.map((e) => e.amount).reduce((a, b) => a > b ? a : b) / 5)
          : 1)
          .ceil()
          .toDouble(), // Match dynamic interval
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Colors.white.withOpacity(0.3), // Match grid color
          strokeWidth: 1,
          dashArray: [5, 5], // Match dash pattern
        );
      },
    );
  }

  /// Configures the tooltips that appear on touch.
  LineTouchData _lineTouchData(BuildContext context) {
    final currencyFormatter = NumberFormat.compactCurrency(
      locale: 'en_US',
      symbol: 'UGX ',
    );
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (spots) => spots.map((spot) {
          final date = data[spot.spotIndex].date;
          return LineTooltipItem(
            '${DateFormat.MMMEd().format(date)}\n',
            const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            children: [
              TextSpan(
                text: currencyFormatter.format(spot.y),
                style: const TextStyle(fontWeight: FontWeight.normal),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Creates the labels for the bottom (X) axis.
  Widget _bottomTitles(double value, TitleMeta meta) {
    final int index = value.toInt();
    if (index < 0 || index >= data.length) return const Text('');
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        DateFormat.Md().format(data[index].date),
        style: const TextStyle(
          color: Colors.white, // Match label color
          fontSize: 12, // Match font size
        ),
      ),
    );
  }

  /// Creates the labels for the left (Y) axis.
  Widget _leftTitles(double value, TitleMeta meta) {
    return Text(
      value.toInt().toString(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
      ),
    );
  }
}