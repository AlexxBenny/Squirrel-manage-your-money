import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final _inrDecimalFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final _compactFormat = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  static String format(double amount, {bool compact = false, bool showDecimal = false}) {
    if (compact) return _compactFormat.format(amount);
    if (showDecimal) return _inrDecimalFormat.format(amount);
    return _inrFormat.format(amount);
  }

  static String formatWithSign(double amount) {
    final prefix = amount >= 0 ? '+' : '';
    return '$prefix${format(amount)}';
  }

  static String formatPct(double pct, {int decimals = 1}) {
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(decimals)}%';
  }
}
