import 'package:intl/intl.dart';

abstract final class Fmt {
  static final _ugx = NumberFormat.decimalPattern('en_UG');
  static final _date = DateFormat('d MMM yyyy');
  static String money(int amount, {bool compact = false}) {
    if (!compact) return 'UGX ${_ugx.format(amount)}';
    final neg = amount < 0 ? '-' : '';
    final n = amount.abs();
    if (n >= 1000000000) return 'UGX $neg${(n / 1000000000).toStringAsFixed(2)}B';
    if (n >= 1000000) return 'UGX $neg${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000) return 'UGX $neg${(n / 1000).toStringAsFixed(1)}K';
    return money(amount);
  }
  static String date(DateTime d) => _date.format(d);
  static String percent(int basisPoints) => '${(basisPoints / 100).toStringAsFixed(1)}%';
  static int? parseUgx(String text) {
    final s = text.trim().replaceAll(',', '').replaceAll(' ', '');
    if (!RegExp(r'^\d+$').hasMatch(s)) return null;
    return int.tryParse(s);
  }
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).take(2).toList();
    return parts.map((p) => p[0].toUpperCase()).join();
  }
}
