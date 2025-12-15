import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bac_monitor/additions/colors.dart';
import '../../models/dashboard.dart';

class TopStoresBarChart extends StatelessWidget {
  final List<StorePerformance> storeData;

  const TopStoresBarChart({super.key, required this.storeData});

  static const List<Color> _barColors = [
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.redAccent,
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.amberAccent,
    Colors.indigoAccent,
    Colors.cyanAccent,
  ];

  @override
  Widget build(BuildContext context) {
    print("TopStoresBarChart building with storeData: $storeData");
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildBarChart()),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: _buildLegend()),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.only(top: 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: storeData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            return _buildLegendItem(
              color: _barColors[index % _barColors.length],
              text: data.storeName,
              index: index + 1,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String text,
    required int index,
  }) {
    final displayText = text.length > 20 ? '${text.substring(0, 17)}...' : text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$index. $displayText',
              style: const TextStyle(color: Colors.white70, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final maxY = storeData.isNotEmpty
        ? storeData
                  .map((data) => data.performanceValue)
                  .reduce((a, b) => a > b ? a : b) *
              1.5 // Extra headroom for tilted text
        : 10.0;

    final formatter = NumberFormat.compact(locale: 'en_US');

    return BarChart(
      BarChartData(
        groupsSpace: 20,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(color: Colors.white70, width: 1),
            bottom: BorderSide(color: Colors.white70, width: 1),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white70.withOpacity(0.3),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35, // Space for the rotated titles
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= storeData.length) {
                  return const SizedBox.shrink();
                }

                final store = storeData[index];
                if (store.performanceValue == 0) {
                  return const SizedBox.shrink(); // Don't show label for zero value
                }

                final formattedValue = formatter.format(store.performanceValue);

                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Transform.rotate(
                    angle: -0.785, // Rotates the text -45 degrees
                    child: Text(
                      formattedValue,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => _leftTitles(value, meta),
            ),
            axisNameWidget: const Text(
              'Sales (UGX)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            axisNameSize: 20,
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => _bottomTitles(value, meta),
              interval: 1,
            ),
          ),
        ),
        maxY: maxY,
        barGroups: storeData.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data.performanceValue,
                color: _barColors[index % _barColors.length],
                width: 12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _bottomTitles(double value, TitleMeta meta) {
    final int index = value.toInt();
    final String text = (index + 1).toString();
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8.0,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _leftTitles(double value, TitleMeta meta) {
    if (value == meta.max || value == meta.min) {
      return const Text('');
    }

    final formatter = NumberFormat.compact(locale: 'en_US');
    final String formattedValue = formatter.format(value);

    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Text(
        formattedValue,
        style: const TextStyle(color: Colors.white70, fontSize: 10),
        textAlign: TextAlign.right,
      ),
    );
  }
}
