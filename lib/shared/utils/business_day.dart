import 'package:intl/intl.dart';

/// Boundaries of a POS business day.
///
/// A business day runs from 8:30 AM on the selected date to 8:30 AM on the
/// following calendar day, so late-night sales belong to the day they
/// started. Selecting the 17th, for example, covers
/// 17 Oct 08:30 (inclusive) until 18 Oct 08:30 (exclusive).
class BusinessDay {
  const BusinessDay._();

  static const int cutoffHour = 8;
  static const int cutoffMinute = 30;

  /// Inclusive start of the business day: the selected date at 08:30.
  static DateTime startOf(DateTime date) => DateTime(
        date.year,
        date.month,
        date.day,
        cutoffHour,
        cutoffMinute,
      );

  /// Exclusive end of the business day: the next date at 08:30.
  static DateTime endOf(DateTime date) => DateTime(
        date.year,
        date.month,
        date.day + 1,
        cutoffHour,
        cutoffMinute,
      );

  /// Human-readable range, e.g. "17 Oct 2026, 8:30 AM – 18 Oct 2026, 8:30 AM".
  static String rangeLabel(DateTime date) {
    final dateFormat = DateFormat('d MMM yyyy');
    return '${dateFormat.format(startOf(date))}, '
        '${_timeLabel(startOf(date))} – '
        '${dateFormat.format(endOf(date))}, '
        '${_timeLabel(endOf(date))}';
  }

  /// Compact range for narrow receipts (e.g. 58mm paper), e.g.
  /// "17 – 18 Oct 2026". Falls back to both months when they differ, e.g.
  /// "31 Oct – 1 Nov 2026".
  static String shortRangeLabel(DateTime date) {
    final start = startOf(date);
    final end = endOf(date);
    if (start.year == end.year && start.month == end.month) {
      return '${start.day} – ${end.day} ${DateFormat('MMM yyyy').format(start)}';
    }
    return '${DateFormat('d MMM').format(start)} – '
        '${DateFormat('d MMM yyyy').format(end)}';
  }

  static String _timeLabel(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
