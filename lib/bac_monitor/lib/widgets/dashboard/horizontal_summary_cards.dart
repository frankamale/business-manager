import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../additions/colors.dart';
import '../../controllers/mon_salestrends_controller.dart';
import '../../models/dashboard.dart';

class HorizontalSummaryCards extends StatelessWidget {
  const HorizontalSummaryCards({super.key});

  static const List<Color> _paymentColors = [
    Color(0xff4392F1),
    Color(0xff58FADD),
    Color(0xffF7B32B),
    Color(0xffD95D39),
    Color(0xffA846A0),
  ];

  static const List<Color> _cashierColors = [
    Color(0xffF7B32B),
    Color(0xffD95D39),
    Color(0xff4392F1),
    Color(0xff58FADD),
    Color(0xffA846A0),
  ];

  List<PaymentData> _processPaymentData(List<dynamic> salesData) {
    final Map<String, double> salesByMode = {};
    for (final sale in salesData) {
      String paymentMode = sale['kpi'] as String? ?? 'Cash';
      final amount = (sale['amount1'] as num?)?.toDouble() ?? 0.0;

      if (paymentMode.trim().isEmpty) {
        paymentMode = 'Cash';
      }

      salesByMode.update(
        paymentMode,
            (value) => value + amount,
        ifAbsent: () => amount,
      );
    }

    final processedList = salesByMode.entries
        .map(
          (entry) =>
          PaymentData(paymentMode: entry.key, totalAmount: entry.value),
    )
        .toList();

    processedList.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return processedList;
  }

  List<CashierData> _processCashierData(List<dynamic> salesData) {
    final Map<String, double> salesByCashier = {};

    for (final sale in salesData) {
      String cashierName =
          (sale['kpi'] as String?)?.trim() ?? 'Unknown Cashier';

      if (cashierName.isEmpty) {
        cashierName = 'Unknown Cashier';
      }

      final amount = (sale['amount1'] as num?)?.toDouble() ?? 0.0;

      salesByCashier.update(
        cashierName,
            (value) => value + amount,
        ifAbsent: () => amount,
      );
    }

    final processedList = salesByCashier.entries
        .map(
          (entry) =>
          CashierData(cashierName: entry.key, totalAmount: entry.value),
    )
        .toList();

    processedList.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return processedList;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MonSalesTrendsController>();

    return Obx(() {
      final paymentData = _processPaymentData(controller.rawSalesForKpi3.value);
      final cashierData = _processCashierData(controller.rawSalesForKpi4.value);
      final compactFormatter = NumberFormat.compact(locale: 'en_US');

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cashier Summary Card
            _buildSummaryCard(
              title: 'Summary by Cashier',
              totalSales: cashierData.fold(
                0.0,
                    (sum, item) => sum + item.totalAmount,
              ),
              items: cashierData,
              colors: _cashierColors,
              compactFormatter: compactFormatter,
            ),

            const SizedBox(width: 16),

            // Payment Summary Card
            _buildSummaryCard(
              title: 'Summary by Payment',
              totalSales: paymentData.fold(
                0.0,
                    (sum, item) => sum + item.totalAmount,
              ),
              items: paymentData,
              colors: _paymentColors,
              compactFormatter: compactFormatter,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSummaryCard<T>({
    required String title,
    required double totalSales,
    required List<T> items,
    required List<Color> colors,
    required NumberFormat compactFormatter,
  }) {
    final double maxValue = items.isEmpty
        ? 0
        : items.fold(0.0, (max, item) {
      final value = item is PaymentData
          ? item.totalAmount
          : (item as CashierData).totalAmount;
      return value > max ? value : max;
    });

    return Container(
      width: 300,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LightColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: LightColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: LightColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'UGX ${compactFormatter.format(totalSales)}',
                  style: TextStyle(
                    color: LightColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: LightColors.border, height: 1),
          const SizedBox(height: 8),
          // Items list with bar charts
          if (items.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No data available',
                  style: TextStyle(color: LightColors.textDisabled, fontSize: 12),
                ),
              ),
            )
          else
            Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final color = colors[index % colors.length];
                final double value = data is PaymentData
                    ? data.totalAmount
                    : (data as CashierData).totalAmount;
                final String name = data is PaymentData
                    ? data.paymentMode
                    : (data as CashierData).cashierName;
                final percentage =
                    totalSales > 0 ? (value / totalSales) * 100 : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: LightColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${percentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'UGX ${compactFormatter.format(value)}',
                            style: TextStyle(
                              color: LightColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final barWidth = maxValue > 0
                              ? (value / maxValue) * constraints.maxWidth
                              : 0.0;
                          return Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: LightColors.border,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              Container(
                                height: 8,
                                width: barWidth.isNaN ? 0 : barWidth,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: LinearGradient(
                                    colors: [color, color.withOpacity(0.6)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
