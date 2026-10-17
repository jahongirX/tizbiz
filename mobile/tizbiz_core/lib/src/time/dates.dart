import 'biz_time.dart';
import 'hm_time.dart';
import 'local_date.dart';

/// Parsing, conversion and zone offsets. All business times use a fixed offset (no DST).
abstract final class Dates {
  static const String defaultTimezone = 'Asia/Tashkent';

  /// Fixed offsets (no DST anywhere in this table). Unknown or null zone -> Asia/Tashkent (+5),
  /// the same fallback the backend uses.
  static const Map<String, Duration> fixedOffsets = {
    'Asia/Tashkent': Duration(hours: 5),
    'Asia/Samarkand': Duration(hours: 5),
    'Asia/Dushanbe': Duration(hours: 5),
    'Asia/Ashgabat': Duration(hours: 5),
    'Asia/Almaty': Duration(hours: 5),
    'Asia/Bishkek': Duration(hours: 6),
    'Europe/Moscow': Duration(hours: 3),
    'UTC': Duration.zero,
    'Etc/UTC': Duration.zero,
  };

  static final RegExp _offsetPattern =
      RegExp(r'^(?:UTC|GMT)?\s*([+-])(\d{1,2})(?::?(\d{2}))?$', caseSensitive: false);

  static final RegExp _dateTimePattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[ Tt](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,9}))?)?)?\s*(Z|z|[+-]\d{2}:?\d{2})?$',
  );

  static final RegExp _digits = RegExp(r'^-?\d+(?:\.\d+)?$');

  /// Also understands '+05:00', '+0500', 'UTC+5', 'GMT+05:00'.
  static Duration offsetOf(String? timezone) {
    const fallback = Duration(hours: 5);
    if (timezone == null) return fallback;
    final tz = timezone.trim();
    if (tz.isEmpty) return fallback;
    final known = fixedOffsets[tz];
    if (known != null) return known;
    final upper = tz.toUpperCase();
    if (upper == 'GMT' || upper == 'Z') return Duration.zero;
    final m = _offsetPattern.firstMatch(tz);
    if (m != null) {
      final sign = m.group(1) == '-' ? -1 : 1;
      final h = int.parse(m.group(2)!);
      final mi = m.group(3) == null ? 0 : int.parse(m.group(3)!);
      if (h <= 14 && mi <= 59) return Duration(minutes: sign * (h * 60 + mi));
    }
    return fallback;
  }

  /// API datetime -> DateTime (isUtc true).
  /// - 'Y-m-d H:i:s' WITHOUT offset (starts_at, ends_at, start_utc, last_visit, next_at) is UTC.
  /// - 'YYYY-MM-DDTHH:MM:SS' without offset: UTC as well.
  /// - ISO with 'Z' or ±HH:MM: honoured, returned as UTC.
  /// - int / numeric string: unix seconds (created_at, updated_at, replied_at, expires_at).
  /// - null, '', '0000-00-00 00:00:00', garbage -> null.
  static DateTime? parseUtc(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is num) return fromUnix(value);
    if (value is! String) return null;
    final s = value.trim();
    if (s.isEmpty) return null;
    if (_digits.hasMatch(s)) return fromUnix(s);
    final m = _dateTimePattern.firstMatch(s);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final h = m.group(4) == null ? 0 : int.parse(m.group(4)!);
    final mi = m.group(5) == null ? 0 : int.parse(m.group(5)!);
    final sec = m.group(6) == null ? 0 : int.parse(m.group(6)!);
    final frac = m.group(7);
    final us = frac == null ? 0 : int.parse(frac.padRight(6, '0').substring(0, 6));
    if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || sec > 59) return null;
    final base = DateTime.utc(y, mo, d, h, mi, sec, us ~/ 1000, us % 1000);
    if (base.day != d || base.month != mo) return null;
    final zone = m.group(8);
    if (zone == null || zone == 'Z' || zone == 'z') return base;
    final sign = zone.startsWith('-') ? -1 : 1;
    final digits = zone.substring(1).replaceAll(':', '');
    final off = Duration(
      minutes: sign * (int.parse(digits.substring(0, 2)) * 60 + int.parse(digits.substring(2, 4))),
    );
    return base.subtract(off);
  }

  /// int | num | numeric string; 0 or negative -> null.
  static DateTime? fromUnix(Object? seconds) {
    num? s;
    if (seconds is num) {
      s = seconds;
    } else if (seconds is String) {
      s = num.tryParse(seconds.trim());
    }
    if (s == null || !s.isFinite || s <= 0) return null;
    final ms = s is int ? s * 1000 : (s * 1000).round();
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  /// Seconds, floor.
  static int toUnix(DateTime instant) {
    final us = instant.microsecondsSinceEpoch;
    return us >= 0 ? us ~/ 1000000 : -((-us + 999999) ~/ 1000000);
  }

  /// 'Y-m-d H:i:s' in UTC (converts non-UTC input with toUtc()). Used for POST starts_at and
  /// appointment ranges.
  static String formatApiUtc(DateTime instant) {
    final u = instant.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)} '
        '${two(u.hour)}:${two(u.minute)}:${two(u.second)}';
  }

  static BizTime toBizLocal(DateTime instant, [String? timezone]) =>
      BizTime(instant.toUtc(), offsetOf(timezone), _zoneName(timezone));

  static LocalDate localDateOf(DateTime instant, [String? timezone]) =>
      toBizLocal(instant, timezone).date;

  static LocalDate todayLocal({String? timezone, DateTime? now}) =>
      localDateOf(now ?? DateTime.now(), timezone);

  /// Business wall clock -> UTC instant. (2026-10-17, 10:00, Tashkent) -> 2026-10-17 05:00:00Z.
  static DateTime localToUtc(LocalDate date, HmTime time, [String? timezone]) =>
      DateTime.utc(date.year, date.month, date.day, time.hour, time.minute).subtract(offsetOf(timezone));

  /// Local 00:00 of [date] as UTC. (2026-10-17, Tashkent) -> 2026-10-16 19:00:00Z.
  static DateTime startOfLocalDayUtc(LocalDate date, [String? timezone]) =>
      localToUtc(date, const HmTime(0, 0), timezone);

  static String _zoneName(String? timezone) {
    final tz = timezone?.trim();
    return (tz == null || tz.isEmpty) ? defaultTimezone : tz;
  }
}
