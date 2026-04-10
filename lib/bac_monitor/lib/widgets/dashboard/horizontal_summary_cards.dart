import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
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

  static const List<Color> _storeColors = [
    Color(0xff4392F1),
    Color(0xff58FADD),
    Color(0xffF7B32B),
    Color(0xffD95D39),
    Color(0xffA846A0),
  ];

  List<PaymentData> _processPaymentData(List<dynamic> salesData) {
    // If no data for kpi_id=3 (payment modes), use kpi_id=0 (all transactions) as fallback
    if (salesData.isEmpty) {
      return [];
    }

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
    // If no data for kpi_id=4 (salesperson), use kpi_id=0 (all transactions) as fallback
    if (salesData.isEmpty) {
      return [];
    }

    final Map<String, double> salesByCashier = {};

    for (final sale in salesData) {
      String cashierName =
          (sale['kpi'] as String?)?.trim() ?? 'Unknown Cashier';

      if (cashierName.isEmpty) {
        cashierName = 'Unknown Cashier';
      }

      // Salesperson uses amount2
      final amount = (sale['amount2'] as num?)?.toDouble() ?? 0.0;

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

  List<StoreData> _processStoreData(List<StorePerformance> storeData) {
    if (storeData.isEmpty) {
      return [];
    }

    final processedList = storeData
        .where((store) => store.performanceValue > 0)
        .map(
          (store) => StoreData(
            storeName: store.storeName,
            totalAmount: store.performanceValue,
          ),
        )
        .toList();

    processedList.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return processedList;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MonSalesTrendsController>();
    print('HorizontalSummaryCards: building, rawSalesForKpi3 length: ${controller.rawSalesForKpi3.value.length}');

    return Obx(() {
      final isLoading =
          controller.isLoadingSales.value || controller.isLoadingStores.value;
      final paymentData = _processPaymentData(controller.rawSalesForKpi3.value);
      final cashierData = _processCashierData(controller.rawSalesForKpi4.value);
      final storeData = _processStoreData(controller.topStoresData.value);
      final compactFormatter = NumberFormat.compact(locale: 'en_US');

      print('HorizontalSummaryCards: Obx rebuild, paymentData length: ${paymentData.length}, cashierData length: ${cashierData.length}, storeData length: ${storeData.length}');

      return Skeletonizer(
        enabled: isLoading,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Stores Summary Card
              _buildSummaryCard(
                context: context,
                title: 'Top Stores by Sales',
                totalSales: storeData.fold(
                  0.0,
                  (sum, item) => sum + item.totalAmount,
                ),
                items: storeData,
                colors: _storeColors,
                compactFormatter: compactFormatter,
              ),

              const SizedBox(width: 16),

              // Payment Summary Card
              _buildSummaryCard(
                context: context,
                title: 'Summary by Payment Methods',
                totalSales: paymentData.fold(
                  0.0,
                  (sum, item) => sum + item.totalAmount,
                ),
                items: paymentData,
                colors: _paymentColors,
                compactFormatter: compactFormatter,
              ),

              const SizedBox(width: 16),

              // Cashier Summary Card
              _buildSummaryCard(
                context: context,
                title: 'Summary by Cashier',
                totalSales: cashierData.fold(
                  0.0,
                  (sum, item) => sum + item.totalAmount,
                ),
                items: cashierData,
                colors: _cashierColors,
                compactFormatter: compactFormatter,
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSummaryCard<T>({
    required BuildContext context,
    required String title,
    required double totalSales,
    required List<T> items,
    required List<Color> colors,
    required NumberFormat compactFormatter,
  }) {
    final cardColor = AppColors.getCardColor(context);
    final borderColor = AppColors.getBorderColor(context);
    final textPrimary = AppColors.getTextPrimaryColor(context);
    final textSecondary = AppColors.getTextSecondaryColor(context);
    final textDisabled = AppColors.getTextDisabledColor(context);
    final borderLightColor = AppColors.getBorderLightColor(context);

    final double maxValue = items.isEmpty
        ? 0
        : items.fold(0.0, (max, item) {
            final value = item is PaymentData
                ? item.totalAmount
                : item is CashierData
                ? item.totalAmount
                : (item as StoreData).totalAmount;
            return value > max ? value : max;
          });

    final displayItems = items.take(5).toList();

    return Container(
      width: Get.width * 0.8,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),

        // subtle border like KPI
        border: Border.all(color: borderColor, width: 1),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Text(
            title,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 6),

          // TOTAL (more prominent)
          Text(
            'UGX ${compactFormatter.format(totalSales)}',
            style: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          if (displayItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No data',
                  style: TextStyle(color: textDisabled, fontSize: 12),
                ),
              ),
            )
          else
            Column(
              children: displayItems.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final color = colors[index % colors.length];

                final double value = data is PaymentData
                    ? data.totalAmount
                    : data is CashierData
                    ? data.totalAmount
                    : (data as StoreData).totalAmount;

                final String name = data is PaymentData
                    ? data.paymentMode
                    : data is CashierData
                    ? data.cashierName
                    : (data as StoreData).storeName;

                final percentage = totalSales > 0
                    ? (value / totalSales) * 100
                    : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LABEL ROW
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          Text(
                            compactFormatter.format(value),
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // BAR (cleaner)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final targetWidth = maxValue > 0
                                ? (value / maxValue) * constraints.maxWidth
                                : 0.0;

                            return Stack(
                              children: [
                                // Background bar
                                Container(
                                  height: 10,
                                  color: borderLightColor.withOpacity(0.4),
                                ),

                                // Animated foreground bar
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: targetWidth),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, animatedWidth, child) {
                                    return Container(
                                      height: 10,
                                      width: animatedWidth,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            color,
                                            color.withOpacity(0.7),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 4),

                      // PERCENT (clean text instead of badge)
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
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
