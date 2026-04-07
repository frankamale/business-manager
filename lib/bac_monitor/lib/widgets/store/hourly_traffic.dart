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
      return Center(child: Text('No data available', style: TextStyle(color: AppColors.getTextSecondaryColor(context))));
    }

    final maxY = (trafficData.map((e) => e.customerCount).reduce((a, b) => a > b ? a : b) * 1.4)
        .clamp(10.0, double.infinity);

    final lineBarData = _lineChartBarData(context);

    return LineChart(
      LineChartData(
        backgroundColor: AppColors.getSurfaceColor(context).withOpacity(0.1),
        lineBarsData: [lineBarData],
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: AppColors.getBorderColor(context), width: 1),
            bottom: BorderSide(color: AppColors.getBorderColor(context), width: 1),
          ),
        ),
        gridData: _mainGridData(context, maxY),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: maxY / 5,
              getTitlesWidget: (value, meta) => _leftTitles(context, value, meta),
            ),
            axisNameWidget: Text(
              'Customers',
              style: TextStyle(color: AppColors.getTextSecondaryColor(context), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            axisNameSize: 20,
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 3, // show label every 3 hours
              reservedSize: 36,
              getTitlesWidget: (value, meta) => _bottomTitles(context, value, meta),
            ),
            axisNameWidget: Text(
              'Hour of Day',
              style: TextStyle(color: AppColors.getTextSecondaryColor(context), fontSize: 12, fontWeight: FontWeight.bold),
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

  LineChartBarData _lineChartBarData(BuildContext context) {
    final spots = trafficData.map((data) {
      return FlSpot(data.hour.toDouble(), data.customerCount.toDouble());
    }).toList();

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: AppColors.getAccentColor(context),
      barWidth: 3,
      isStrokeCapRound: true,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            AppColors.getAccentColor(context).withOpacity(0.3),
            AppColors.getAccentColor(context).withOpacity(0.0),
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
            color: AppColors.getAccentColor(context),
            strokeWidth: 2,
            strokeColor: AppColors.getBorderColor(context),
          );
        },
      ),
    );
  }

  FlGridData _mainGridData(BuildContext context, double maxY) {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      verticalInterval: 3,
      horizontalInterval: maxY / 5,
      getDrawingHorizontalLine: (value) => FlLine(
        color: AppColors.getBorderColor(context).withOpacity(0.3),
        strokeWidth: 1,
        dashArray: [5, 5],
      ),
      getDrawingVerticalLine: (value) => FlLine(
        color: AppColors.getBorderColor(context).withOpacity(0.2),
        strokeWidth: 1,
      ),
    );
  }

  LineTouchData _lineTouchData() => LineTouchData(enabled: false);

  Widget _leftTitles(BuildContext context, double value, TitleMeta meta) {
    return Text(
      value.toInt().toString(),
      style: TextStyle(color: AppColors.getTextSecondaryColor(context), fontSize: 10),
      textAlign: TextAlign.right,
    );
  }

  Widget _bottomTitles(BuildContext context, double value, TitleMeta meta) {
    // Show only at every 3-hour mark
    if (value % 3 != 0) return const SizedBox.shrink();
    final label = _formatHour(value.toInt());
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Text(
        label,
        style: TextStyle(color: AppColors.getTextSecondaryColor(context), fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _formatHour(int hour) {
    final period = hour < 12 ? 'am' : 'pm';
    final displayHour = (hour % 12 == 0) ? 12 : hour % 12;
    return '$displayHour$period';
  }
}
