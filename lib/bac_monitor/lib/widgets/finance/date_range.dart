import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bac_monitor/additions/colors.dart';

enum DateRange { today, yesterday, last7Days, monthToDate, custom }

extension DateRangeExtension on DateRange {
  bool get isSingleDay => this == DateRange.today || this == DateRange.yesterday;
  bool get isWeekly => this == DateRange.last7Days;
  bool get isMonthly => this == DateRange.monthToDate;
}

class DateRangePicker extends StatefulWidget {
  final Function(DateRange, DateTimeRange?) onDateRangeSelected;

  const DateRangePicker({super.key, required this.onDateRangeSelected});

  @override
  State<DateRangePicker> createState() => _DateRangePickerState();
}

class _DateRangePickerState extends State<DateRangePicker> {
  DateRange _selectedRange = DateRange.last7Days;
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    // Notify parent of the initial default date range on widget mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDateRangeSelected(_selectedRange, _customDateRange);
    });
  }

  Future<DateTime?> _showCustomDatePicker({
    required BuildContext context,
    DateTime? initialDate,
  }) async {
    final now = DateTime.now();
    return await showDialog<DateTime>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: PrimaryColors.darkBlue,
        child: Theme(
          data: ThemeData(
            colorScheme: const ColorScheme.dark().copyWith(
              primary: PrimaryColors.brightYellow,
              onPrimary: Colors.black,
              surface: PrimaryColors.darkBlue,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: PrimaryColors.darkBlue,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400, maxWidth: 320),
            child: CalendarDatePicker(
              initialDate: initialDate ?? now,
              firstDate: DateTime(now.year - 5),
              lastDate: now,
              onDateChanged: (date) => Navigator.pop(context, date),
            ),
          ),
        ),
      ),
    );
  }

  Future<DateTimeRange?> _showCompactDateRangePicker(
    BuildContext context,
  ) async {
    DateTime? startDate;
    DateTime? endDate;

    return await showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: PrimaryColors.darkBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              title: const Text(
                "Select Custom Range",
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                height: 150,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPickerTile(
                      context: context,
                      title: 'Start Date',
                      date: startDate,
                      onTap: () async {
                        final pickedDate = await _showCustomDatePicker(
                          context: context,
                        );
                        if (pickedDate != null) {
                          setState(() => startDate = pickedDate);
                        }
                      },
                    ),
                    _buildPickerTile(
                      context: context,
                      title: 'End Date',
                      date: endDate,
                      onTap: () async {
                        final pickedDate = await _showCustomDatePicker(
                          context: context,
                          initialDate: startDate,
                        );
                        if (pickedDate != null) {
                          setState(() => endDate = pickedDate);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                FilledButton(
                  onPressed: (startDate != null && endDate != null)
                      ? () {
                          if (startDate!.isAfter(endDate!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Start date must be before end date.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          // Normalize dates: start at 00:00:00, end at 23:59:59
                          final normalizedStart = DateTime(
                            startDate!.year,
                            startDate!.month,
                            startDate!.day,
                          ); // 00:00:00
                          final normalizedEnd = DateTime(
                            endDate!.year,
                            endDate!.month,
                            endDate!.day,
                            23,
                            59,
                            59,
                          ); // 23:59:59
                          Navigator.of(context).pop(
                            DateTimeRange(
                              start: normalizedStart,
                              end: normalizedEnd,
                            ),
                          );
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: PrimaryColors.brightYellow,
                    disabledBackgroundColor: Colors.grey.shade600,
                  ),
                  child: const Text(
                    'APPLY',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPickerTile({
    required BuildContext context,
    required String title,
    DateTime? date,
    required VoidCallback onTap,
  }) {
    final displayFormat = DateFormat.yMMMd();
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      subtitle: Text(
        date != null ? displayFormat.format(date) : 'Not Set',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      trailing: const Icon(
        Icons.calendar_month_outlined,
        color: PrimaryColors.brightYellow,
      ),
      onTap: onTap,
    );
  }

  Future<void> _handleSelection(DateRange range) async {
    Navigator.of(context).pop();

    if (range == DateRange.custom) {
      final DateTimeRange? picked = await _showCompactDateRangePicker(context);
      if (picked != null) {
        setState(() {
          _selectedRange = DateRange.custom;
          _customDateRange = picked;
        });
        widget.onDateRangeSelected(DateRange.custom, picked);
      }
    } else {
      setState(() {
        _selectedRange = range;
        _customDateRange = null;
      });
      widget.onDateRangeSelected(range, null);
    }
  }

  String _getDisplayLabel() {
    final formatter = DateFormat.MMMd();
    final now = DateTime.now();
    switch (_selectedRange) {
      case DateRange.today:
        return 'Today (${formatter.format(now)})';
      case DateRange.yesterday:
        return 'Yesterday (${formatter.format(now.subtract(Duration(days: 1)))})';
      case DateRange.last7Days:
        final start = now.subtract(Duration(days: 6));
        final startNormalized = DateTime(start.year, start.month, start.day);
        return 'Last 7 Days (${formatter.format(startNormalized)} - ${formatter.format(now)})';
      case DateRange.monthToDate:
        final start = DateTime(now.year, now.month, 1);
        return 'Month to Date (${formatter.format(start)} - ${formatter.format(now)})';
      case DateRange.custom:
        if (_customDateRange != null) {
          final formatter = DateFormat.yMMMd();
          final start = formatter.format(_customDateRange!.start);
          final end = formatter.format(_customDateRange!.end);
          return '$start - $end';
        }
        return 'Custom Range';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: OutlinedButton.icon(
          onPressed: _showSelectionSheet,
          icon: const Icon(
            Icons.calendar_today,
            color: PrimaryColors.brightYellow,
          ),
          label: Text(
            _getDisplayLabel(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            side: const BorderSide(color: Colors.white30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  // This method builds and displays the modal bottom sheet with the range options.
  void _showSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: PrimaryColors.darkBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Select a Period',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              _buildOptionTile('Today', DateRange.today),
              _buildOptionTile('Yesterday', DateRange.yesterday),
              _buildOptionTile('Last 7 Days', DateRange.last7Days),
              _buildOptionTile('Month to Date', DateRange.monthToDate),
              _buildOptionTile('Custom Range...', DateRange.custom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(String title, DateRange range) {
    final bool isSelected = _selectedRange == range;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? PrimaryColors.brightYellow : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: PrimaryColors.brightYellow)
          : null,
      onTap: () => _handleSelection(range),
    );
  }
}
