import 'package:intl/intl.dart';

/// Financial formatting. All values are AUD unless stated.
class Fmt {
  static final _aud = NumberFormat.currency(locale: 'en_AU', symbol: 'A\$', decimalDigits: 2);
  static final _aud0 = NumberFormat.currency(locale: 'en_AU', symbol: 'A\$', decimalDigits: 0);
  static final _num = NumberFormat.decimalPattern('en_AU');
  static final _n2 = NumberFormat('#,##0.00', 'en_AU');

  static String aud(num v, {bool cents = true}) => (cents ? _aud : _aud0).format(v);

  /// Signed currency with explicit plus or minus sign.
  static String audSigned(num v, {bool cents = true}) {
    final s = (cents ? _aud : _aud0).format(v.abs());
    if (v > 0.004) return '+$s';
    if (v < -0.004) return '−$s';
    return s;
  }

  static String price(num v) => _n2.format(v);
  static String units(num v) => _num.format(v);

  static String pct(num v, {int dp = 2}) {
    final s = '${v.abs().toStringAsFixed(dp)}%';
    if (v > 0.0049) return '+$s';
    if (v < -0.0049) return '−$s';
    return s;
  }

  static String compact(num v) {
    if (v.abs() >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
    if (v.abs() >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

/// Australia/Sydney time without a tz database.
/// AEDT (UTC+11) runs from the first Sunday in October 02:00 AEST
/// to the first Sunday in April 03:00 AEDT. Otherwise AEST (UTC+10).
class Sydney {
  static DateTime _firstSunday(int year, int month) {
    var d = DateTime.utc(year, month, 1);
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  static bool isDst(DateTime instant) {
    final utc = instant.toUtc();
    final y = utc.year;
    // Both transitions happen at 16:00 UTC on the Saturday before.
    final end = _firstSunday(y, 4).subtract(const Duration(hours: 8));
    final start = _firstSunday(y, 10).subtract(const Duration(hours: 8));
    return utc.isBefore(end) || !utc.isBefore(start);
  }

  /// Wall-clock Sydney time, returned as a UTC-flagged DateTime for formatting.
  static DateTime local(DateTime instant) {
    final utc = instant.toUtc();
    return utc.add(Duration(hours: isDst(utc) ? 11 : 10));
  }

  static String zone(DateTime instant) => isDst(instant) ? 'AEDT' : 'AEST';

  static String time(DateTime instant) => '${DateFormat('h:mm a').format(local(instant)).toLowerCase()} ${zone(instant)}';

  static String stamp(DateTime instant) => '${DateFormat('EEE d MMM yyyy').format(local(instant))}, ${time(instant)}';

  static String date(DateTime instant) => DateFormat('d MMM yyyy').format(local(instant));
  static String shortDate(DateTime instant) => DateFormat('d MMM').format(local(instant));
  static String dayLabel(DateTime instant) => DateFormat('EEEE d MMMM').format(local(instant));
  static String hm(DateTime instant) => DateFormat('h:mm a').format(local(instant)).toLowerCase();
}
