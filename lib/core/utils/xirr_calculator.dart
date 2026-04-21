/// XIRR (Extended Internal Rate of Return) calculator using Newton-Raphson method.
/// Used for accurate annualized return calculation on SIPs and irregular cash flows.
class XirrCalculator {
  /// Calculate XIRR given [cashFlows] and their corresponding [dates].
  /// Cash flows convention: investments are NEGATIVE, redemptions/current value POSITIVE.
  /// Returns XIRR as a decimal (e.g. 0.15 = 15%), or null if calculation fails.
  static double? calculate(List<double> cashFlows, List<DateTime> dates) {
    if (cashFlows.length != dates.length || cashFlows.length < 2) return null;

    // Check that there's at least one negative and one positive
    final hasNeg = cashFlows.any((c) => c < 0);
    final hasPos = cashFlows.any((c) => c > 0);
    if (!hasNeg || !hasPos) return null;

    // Days from first date
    final t0 = dates.first;
    final days = dates.map((d) => d.difference(t0).inDays / 365.0).toList();

    // Newton-Raphson iteration
    double rate = 0.1; // initial guess 10%
    for (int iter = 0; iter < 200; iter++) {
      double f = 0, df = 0;
      for (int i = 0; i < cashFlows.length; i++) {
        final t = days[i];
        final denom = _pow(1 + rate, t);
        f  += cashFlows[i] / denom;
        df -= t * cashFlows[i] / (_pow(1 + rate, t + 1));
      }
      if (df.abs() < 1e-10) break;
      final delta = f / df;
      rate -= delta;
      if (delta.abs() < 1e-8) break;
    }

    if (rate.isNaN || rate.isInfinite || rate < -0.999) return null;
    return rate;
  }

  /// Generate cash flows for a SIP investment.
  /// [sipAmount] per installment (negative = outflow),
  /// [sipDay] day of month, [startDate], total units × [currentNav] as terminal positive.
  static (List<double>, List<DateTime>) buildSipCashFlows({
    required double sipAmount,
    required int sipDay,
    required DateTime startDate,
    required double currentValue,
  }) {
    final now = DateTime.now();
    final flows = <double>[];
    final dates = <DateTime>[];

    DateTime d = _nextSipDate(startDate, sipDay);
    while (!d.isAfter(now)) {
      flows.add(-sipAmount);
      dates.add(d);
      d = _nextSipDate(DateTime(d.year, d.month + 1, 1), sipDay);
    }

    if (flows.isEmpty) return ([-sipAmount, currentValue], [startDate, now]);
    flows.add(currentValue);
    dates.add(now);
    return (flows, dates);
  }

  static DateTime _nextSipDate(DateTime from, int day) {
    final daysInMonth = DateTimeHelper.daysInMonth(from.year, from.month);
    final d = day > daysInMonth ? daysInMonth : day;
    return DateTime(from.year, from.month, d);
  }

  static double _pow(double base, double exp) {
    if (base <= 0) return 0;
    return _expLog(exp * _ln(base));
  }

  static double _ln(double x) {
    if (x <= 0) return double.negativeInfinity;
    // Use dart:math if available, else approximate
    double result = 0;
    double y = (x - 1) / (x + 1);
    double term = y;
    for (int i = 0; i < 50; i++) {
      result += term / (2 * i + 1);
      term *= y * y;
    }
    return 2 * result;
  }

  static double _expLog(double x) {
    double result = 1;
    double term = 1;
    for (int i = 1; i < 30; i++) {
      term *= x / i;
      result += term;
      if (term.abs() < 1e-12) break;
    }
    return result;
  }
}

class DateTimeHelper {
  static int daysInMonth(int year, int month) {
    if (month == 12) return DateTime(year + 1, 1, 1).subtract(const Duration(days: 1)).day;
    return DateTime(year, month + 1, 1).subtract(const Duration(days: 1)).day;
  }
}
