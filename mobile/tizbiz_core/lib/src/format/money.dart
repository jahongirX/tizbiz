/// Money helpers. Amounts are integer tiyin (1/100 so'm) on the wire.
abstract final class Money {
  /// U+00A0 NO-BREAK SPACE. This is exactly what `Number.toLocaleString('ru-RU')` emits in V8/ICU
  /// (checked: (1500000).toLocaleString('ru-RU') -> '1 500 000'), and it keeps
  /// "150 000 so'm" on one line in Flutter Text.
  static const String groupSeparator = ' ';
  static const String currency = "so'm";

  /// tiyin -> whole so'm, rounded half away from zero (Dart num.round()). 5000050 -> 50001.
  static int toSom(int tiyin) => (tiyin / 100).round();

  /// so'm -> tiyin, (som * 100).round(). 50 -> 5000; 12.5 -> 1250.
  static int fromSom(num som) => (som * 100).round();

  /// "150 000 so'm" with [separator] between groups and between number and currency.
  /// null -> '—'. Negative -> "-150 000 so'm" (ASCII hyphen-minus, like apps/admin formatSom).
  static String format(int? tiyin, {bool withCurrency = true, String separator = groupSeparator}) {
    if (tiyin == null) return '—';
    final s = group(toSom(tiyin), separator: separator);
    return withCurrency ? '$s$separator$currency' : s;
  }

  /// Digits only, grouped: 1500000 -> '1 500 000' (separator configurable). Accepts negative.
  static String group(int value, {String separator = groupSeparator}) {
    final neg = value < 0;
    final digits = (neg ? -value : value).toString();
    final buf = StringBuffer(neg ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(separator);
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  /// Short form for chart axes and chips (decimal comma, at most 1 decimal, trailing ',0' dropped):
  /// < 1 000 so'm -> "950 so'm"; < 1e6 -> "150 ming so'm"; < 1e9 -> "1,5 mln so'm"; else "2 mlrd so'm".
  static String compact(int tiyin, {bool withCurrency = true}) {
    final som = tiyin / 100;
    final neg = som < 0;
    final abs = som.abs();
    const units = [(1e9, 'mlrd'), (1e6, 'mln'), (1e3, 'ming')];
    String body;
    final rounded = abs.round();
    if (rounded < 1000) {
      body = rounded.toString();
    } else {
      var idx = units.indexWhere((u) => rounded >= u.$1);
      var scaled = (abs / units[idx].$1 * 10).round() / 10;
      // 999 960 so'm rounds to "1000 ming": promote to the next unit.
      if (idx > 0 && scaled >= 1000) {
        idx -= 1;
        scaled = (abs / units[idx].$1 * 10).round() / 10;
      }
      body = '${_oneDecimal(scaled)} ${units[idx].$2}';
    }
    final signed = neg && body != '0' ? '-$body' : body;
    return withCurrency ? '$signed $currency' : signed;
  }

  /// Parses a user-typed so'm amount ('150 000', '150000', '150 000,50', '1 500') -> tiyin.
  /// Returns null for empty or invalid input. Spaces/NBSP/U+202F are ignored; one ',' or '.'
  /// decimal (max 2 digits).
  static int? parseSomInput(String? text) {
    if (text == null) return null;
    final s = text.replaceAll(RegExp(r'[\s  ]'), '');
    if (s.isEmpty) return null;
    final m = RegExp(r'^(\d+)(?:[.,](\d{1,2}))?$').firstMatch(s);
    if (m == null) return null;
    final whole = int.tryParse(m.group(1)!);
    if (whole == null) return null;
    final frac = m.group(2) == null ? 0 : int.parse(m.group(2)!.padRight(2, '0'));
    return whole * 100 + frac;
  }

  static String _oneDecimal(double v) {
    final tenths = (v * 10).round();
    final whole = tenths ~/ 10;
    final dec = tenths % 10;
    final w = group(whole, separator: ' ');
    return dec == 0 ? w : '$w,$dec';
  }
}
