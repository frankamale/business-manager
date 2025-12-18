import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../additions/colors.dart';
import '../../models/hourly_customer_traffic.dart';

class HourlyTrafficChart extends StatelessWidget {
  final List<HourlyTraffic> trafficData;

  const HourlyTrafficChart({super.key, required this.trafficData});

  @override
  Widget build(BuildContext context) {
    if (trafficData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final maxY = (trafficData.map((e) => e.customerCount).reduce((a, b) => a > b ? a : b) * 1.4)
        .clamp(10.0, double.infinity);

    final lineBarData = _lineChartBarData();

    return LineChart(
      LineChartData(
        backgroundColor: PrimaryColors.light.withOpacity(0.1),
        lineBarsData: [lineBarData],
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(color: Colors.white70, width: 1),
            bottom: BorderSide(color: Colors.white70, width: 1),
          ),
        ),
        gridData: _mainGridData(maxY),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: maxY / 5,
              getTitlesWidget: (value, meta) => _leftTitles(value, meta),
            ),
            axisNameWidget: const Text(
              'Customers',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            axisNameSize: 20,
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 3, // show label every 3 hours
              reservedSize: 36,
              getTitlesWidget: (value, meta) => _bottomTitles(value, meta),
            ),
            axisNameWidget: const Text(
              'Hour of Day',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            axisNameSize: 20,
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        minX: 0,
        maxX: 23,
        maxY: maxY,
        lineTouchData: _lineTouchData(),
      ),
    );
  }

  LineChartBarData _lineChartBarData() {
    final spots = trafficData.map((data) {
      return FlSpot(data.hour.toDouble(), data.customerCount.toDouble());
    }).toList();

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: PrimaryColors.brightYellow,
      barWidth: 3,
      isStrokeCapRound: true,
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
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: PrimaryColors.brightYellow,
            strokeWidth: 2,
            strokeColor: Colors.white70,
          );
        },
      ),
    );
  }

  FlGridData _mainGridData(double maxY) {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      verticalInterval: 3,
      horizontalInterval: maxY / 5,
      getDrawingHorizontalLine: (value) => FlLine(
        color: Colors.white70.withOpacity(0.3),
        strokeWidth: 1,
        dashArray: [5, 5],
      ),
      getDrawingVerticalLine: (value) => FlLine(
        color: Colors.white70.withOpacity(0.2),
        strokeWidth: 1,
      ),
    );
  }

  LineTouchData _lineTouchData() => LineTouchData(enabled: false);

  Widget _leftTitles(double value, TitleMeta meta) {
    return Text(
      value.toInt().toString(),
      style: const TextStyle(color: Colors.white70, fontSize: 10),
      textAlign: TextAlign.right,
    );
  }

  Widget _bottomTitles(double value, TitleMeta meta) {
    // Show only at every 3-hour mark
    if (value % 3 != 0) return const SizedBox.shrink();
    final label = _formatHour(value.toInt());
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _formatHour(int hour) {
    final period = hour < 12 ? 'am' : 'pm';
    final displayHour = (hour % 12 == 0) ? 12 : hour % 12;
    return '$displayHour$period';
  }
}
