import 'package:intl/intl.dart';

class DateHelpers {
  static final _dayMonth = DateFormat('d MMM');
  static final _dayMonthYear = DateFormat('d MMM yyyy');
  static final _monthYear = DateFormat('MMM yyyy');
  static final _fullDate = DateFormat('EEEE, d MMMM yyyy');
  static final _time = DateFormat('h:mm a');

  static String dayMonth(DateTime dt) => _dayMonth.format(dt);
  static String dayMonthYear(DateTime dt) => _dayMonthYear.format(dt);
  static String monthYear(DateTime dt) => _monthYear.format(dt);
  static String fullDate(DateTime dt) => _fullDate.format(dt);
  static String time(DateTime dt) => _time.format(dt);

  static String relative(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff <= 7) return '$diff days ago';
    return dayMonthYear(dt);
  }

  static DateTime startOfMonth(DateTime dt) => DateTime(dt.year, dt.month, 1);
  static DateTime endOfMonth(DateTime dt) => DateTime(dt.year, dt.month + 1, 0, 23, 59, 59);
  static DateTime startOfWeek(DateTime dt) {
    final weekday = dt.weekday;
    return DateTime(dt.year, dt.month, dt.day - (weekday - 1));
  }
  static DateTime endOfWeek(DateTime dt) {
    final weekday = dt.weekday;
    return DateTime(dt.year, dt.month, dt.day + (7 - weekday), 23, 59, 59);
  }

  static List<DateTime> last12Months() {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final month = now.month - i;
      final year = now.year + (month <= 0 ? -1 : 0);
      final adjustedMonth = month <= 0 ? month + 12 : month;
      return DateTime(year, adjustedMonth, 1);
    }).reversed.toList();
  }

  static bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
