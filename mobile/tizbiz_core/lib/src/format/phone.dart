/// Uzbek phone numbers. Apps always send [normalize] output (`+998XXXXXXXXX`).
abstract final class Phone {
  static final RegExp _nonDigits = RegExp(r'\D');

  /// Exact mirror of common\helpers\Phone::normalize: strip non-digits; < 9 digits -> null;
  /// else '+998' + last 9 digits. '90 123 45 67' -> '+998901234567'; '+998 (90) 123-45-67' -> same;
  /// '8 90 123 45 67' -> '+998901234567' (last 9); '12345' -> null.
  static String? normalize(String? input) {
    if (input == null) return null;
    final digits = input.replaceAll(_nonDigits, '');
    if (digits.length < 9) return null;
    return '+998${digits.substring(digits.length - 9)}';
  }

  /// Stricter client-side check used by forms: digit count is 9, or 12 starting with '998'.
  static bool isValid(String? input) {
    if (input == null) return false;
    final digits = input.replaceAll(_nonDigits, '');
    return digits.length == 9 || (digits.length == 12 && digits.startsWith('998'));
  }

  /// '+998 90 123 45 67'. Input that cannot be normalized is returned trimmed, unchanged.
  static String format(String? phone) {
    final n = normalize(phone);
    if (n == null) return (phone ?? '').trim();
    return '+998 ${_groupLocal(n.substring(4))}';
  }

  /// '90 123 45 67' (no country code).
  static String formatLocal(String? phone) {
    final n = normalize(phone);
    if (n == null) return (phone ?? '').trim();
    return _groupLocal(n.substring(4));
  }

  /// As-you-type formatting of the 9 local digits (ignores a leading 998 / +998):
  /// '9' -> '9', '901' -> '90 1', '90123' -> '90 123', '9012345' -> '90 123 45',
  /// '901234567' -> '90 123 45 67'. Extra digits beyond 9 are dropped.
  static String formatPartial(String input) {
    var digits = input.replaceAll(_nonDigits, '');
    final hasPlus = input.trimLeft().startsWith('+');
    if (digits.startsWith('998') && (hasPlus || digits.length > 9)) {
      digits = digits.substring(3);
    }
    if (digits.length > 9) digits = digits.substring(0, 9);
    return _groupLocal(digits);
  }

  /// Masked for lists/logs: '+998 90 *** ** 67'.
  static String mask(String? phone) {
    final n = normalize(phone);
    if (n == null) return (phone ?? '').trim();
    final local = n.substring(4);
    return '+998 ${local.substring(0, 2)} *** ** ${local.substring(7)}';
  }

  /// 'tel:+998901234567' (null when not normalizable).
  static Uri? telUri(String? phone) {
    final n = normalize(phone);
    return n == null ? null : Uri.parse('tel:$n');
  }

  /// Groups up to 9 local digits as 2-3-2-2.
  static String _groupLocal(String d) {
    const sizes = [2, 3, 2, 2];
    final parts = <String>[];
    var i = 0;
    for (final size in sizes) {
      if (i >= d.length) break;
      final end = i + size > d.length ? d.length : i + size;
      parts.add(d.substring(i, end));
      i = end;
    }
    return parts.join(' ');
  }
}
