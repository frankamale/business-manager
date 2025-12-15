import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../additions/colors.dart';
import '../../models/finanacial_data.dart';
import '../../widgets/finance/cash_flow.dart';
import '../../widgets/finance/date_range.dart';
import '../../widgets/finance/expandable_expences.dart';
import '../../widgets/dashboard/kpi_card.dart';

class Finance extends StatefulWidget {
  const Finance({super.key});

  @override
  State<Finance> createState() => _FinancePageState();
}

class _FinancePageState extends State<Finance> {
  final List<ExpenseCategory> _expenseData = [
    ExpenseCategory(name: "Rent", amount: 1200000, color: Colors.blue.shade300),
    ExpenseCategory(
      name: "Salaries",
      amount: 2500000,
      color: Colors.green.shade300,
    ),
    ExpenseCategory(
      name: "Stock",
      amount: 3100000,
      color: Colors.orange.shade300,
    ),
    ExpenseCategory(
      name: "Utilities",
      amount: 450000,
      color: Colors.red.shade300,
    ),
    ExpenseCategory(
      name: "Misc.",
      amount: 250000,
      color: Colors.purple.shade300,
    ),
  ];

  final List<CashFlowDataPoint> _cashFlowData = List.generate(30, (i) {
    final date = DateTime.now().subtract(Duration(days: 30 - i));
    final random = Random();

    final baseAmount = 1000 + (i * 50);

    final noise = (random.nextDouble() - 0.5) * 1000;

    final isWeeklyPeak = i % 7 == 0;
    final peakBoost = isWeeklyPeak ? 1000 : 0;

    final amount = (baseAmount + noise + peakBoost)
        .clamp(-500, 3000)
        .toDouble();

    return CashFlowDataPoint(date: date, amount: amount);
  });

  void _onDateRangeChanged(DateRange newRange, DateTimeRange? customRange) {
    if (newRange == DateRange.custom && customRange != null) {
      if (kDebugMode) {
        print(
          "Custom range selected: ${customRange.start} to ${customRange.end}",
        );
      }
      // TODO: Fetch data from your backend using these start and end dates.
    } else {
      if (kDebugMode) {
        print("Predefined range selected: $newRange");
      }
      // TODO: Fetch data for "Last 7 Days" or "Month-to-Date".
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimaryColors.darkBlue,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            // floating: true,
            title: const Text(
              "Financial Summary",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(65.0),
              child: DateRangePicker(onDateRangeSelected: _onDateRangeChanged),
            ),
            backgroundColor: PrimaryColors.darkBlue,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              // Adjust this ratio as needed
              children: [
                KpiCard(title: "Gross Sales", unit: "UGX", value: "7.5M"),
                KpiCard(title: "Net Profit", unit: "UGX", value: "2.8M"),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: ExpandableExpensesCard(expenses: _expenseData),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                "Net Cash Flow",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Card(
                color: PrimaryColors.lightBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: NetCashFlowChart(data: _cashFlowData),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
