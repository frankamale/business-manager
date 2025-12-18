import 'package:flutter/material.dart';

class ExpenseCategory {
  final String name;
  final double amount;
  final Color color;

  ExpenseCategory({required this.name, required this.amount, required this.color});
}

class CashFlowDataPoint {
  final DateTime date;
  final double amount;

  CashFlowDataPoint({required this.date, required this.amount});
}