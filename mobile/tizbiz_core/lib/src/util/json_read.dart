import 'dart:convert' show jsonDecode;

import '../time/dates.dart';
import '../time/hm_time.dart';
import '../time/local_date.dart';

/// Tolerant JSON readers used by every `fromJson`.
///
/// The API serialises raw ActiveRecord rows: booleans arrive as `0/1`, decimals as strings
/// (`"41.2756000"`) and PHP's empty associative array as `[]`. None of these readers throw
/// for an odd field value; only [object] throws for a non-map top level.
abstract final class JsonRead {
  /// Top-level guard used by every fromJson: Map -> itself; PHP empty array `[]` -> `{}`;
  /// anything else -> [FormatException].
  static Map<String, dynamic> object(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return _stringKeyed(v);
    if (v is List && v.isEmpty) return <String, dynamic>{};
    throw FormatException('Expected a JSON object, got ${v.runtimeType}');
  }

  /// Same as [object], but null / `[]` / non-map -> null (for optional nested objects).
  static Map<String, dynamic>? objectOrNull(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return _stringKeyed(v);
    return null;
  }

  /// int; double -> truncate; '12' / '12.0' -> 12; true -> 1; else [fallback].
  static int integer(Object? v, [int fallback = 0]) => integerOrNull(v) ?? fallback;

  /// null / '' / unparseable -> null.
  static int? integerOrNull(Object? v) {
    if (v is int) return v;
    if (v is double) return v.isFinite ? v.truncate() : null;
    if (v is bool) return v ? 1 : 0;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      final i = int.tryParse(s);
      if (i != null) return i;
      final d = double.tryParse(s);
      if (d != null && d.isFinite) return d.truncate();
    }
    return null;
  }

  static double number(Object? v, [double fallback = 0]) => numberOrNull(v) ?? fallback;

  /// `'41.2756000'` -> 41.2756; `69` -> 69.0; null / unparseable -> null.
  static double? numberOrNull(Object? v) {
    if (v is num) return v.isFinite ? v.toDouble() : null;
    if (v is bool) return v ? 1 : 0;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      final d = double.tryParse(s);
      if (d != null && d.isFinite) return d;
    }
    return null;
  }

  /// true/false, 1/0, '1'/'0', 'true'/'false' (any case).
  static bool boolean(Object? v, [bool fallback = false]) => booleanOrNull(v) ?? fallback;

  static bool? booleanOrNull(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      switch (v.trim().toLowerCase()) {
        case 'true':
        case '1':
        case 'yes':
          return true;
        case 'false':
        case '0':
        case 'no':
          return false;
      }
    }
    return null;
  }

  /// String as is; num / bool -> toString; null or anything else -> [fallback].
  static String string(Object? v, [String fallback = '']) => stringOrNull(v) ?? fallback;

  /// Keeps '' as ''.
  static String? stringOrNull(Object? v) {
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    return null;
  }

  /// '' / whitespace -> null (logo, cover, brand colors).
  static String? nonEmptyOrNull(Object? v) {
    final s = stringOrNull(v);
    if (s == null || s.trim().isEmpty) return null;
    return s;
  }

  /// List -> strings; JSON-encoded string `'["a"]'` -> decoded; null -> [].
  static List<String> stringList(Object? v) {
    if (v is List) {
      return [
        for (final e in v)
          if (stringOrNull(e) case final String s) s,
      ];
    }
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return <String>[];
      if (s.startsWith('[')) {
        try {
          final decoded = jsonDecode(s);
          if (decoded is List) return stringList(decoded);
        } on FormatException {
          // fall through: treat as a single value
        }
      }
      return [s];
    }
    return <String>[];
  }

  /// null / `{}` -> []; skips non-map entries.
  static List<T> list<T>(Object? v, T Function(Map<String, dynamic>) item) {
    if (v is! List) return <T>[];
    return [
      for (final e in v)
        if (objectOrNull(e) case final Map<String, dynamic> m) item(m),
    ];
  }

  /// [Dates.parseUtc].
  static DateTime? utc(Object? v) => Dates.parseUtc(v);

  /// [Dates.fromUnix].
  static DateTime? unix(Object? v) => Dates.fromUnix(v);

  /// [LocalDate.tryParse].
  static LocalDate? date(Object? v) => LocalDate.tryParse(v);

  /// [HmTime.tryParse].
  static HmTime? time(Object? v) => HmTime.tryParse(v);

  static Map<String, dynamic> _stringKeyed(Map<dynamic, dynamic> m) =>
      m.map((k, v) => MapEntry(k.toString(), v));
}
