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

  /// The business day that contains [moment], identified by the date it
  /// opened on. A moment before 08:30 belongs to the business day that
  /// opened the previous calendar day, e.g. 21 Oct 02:00 falls in the
  /// business day of 20 Oct (20 Oct 08:30 - 21 Oct 08:30).
  static DateTime containing(DateTime moment) {
    final isBeforeCutoff =
        moment.hour < cutoffHour ||
            (moment.hour == cutoffHour && moment.minute < cutoffMinute);
    return isBeforeCutoff
        ? DateTime(moment.year, moment.month, moment.day - 1)
        : DateTime(moment.year, moment.month, moment.day);
  }

  /// Human-readable range, e.g. "17 Oct 2026, 8:30 AM – 18 Oct 2026, 8:30 AM".
  static String rangeLabel(DateTime date) {
    final dateFormat = DateFormat('d MMM yyyy');
    return '${dateFormat.format(startOf(date))}, '
        '${_timeLabel(startOf(date))} – '
        '${dateFormat.format(endOf(date))}, '
        '${_timeLabel(endOf(date))}';
  }

  static String _timeLabel(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
