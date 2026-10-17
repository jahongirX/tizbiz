import 'package:meta/meta.dart';

/// A calendar date without a time or zone (business-local day, birthday, time-off day).
@immutable
final class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  /// 'YYYY-MM-DD' (also accepts 'YYYY-MM-DD HH:MM:SS' / ISO by taking the first 10 chars).
  /// Throws [FormatException].
  factory LocalDate.parse(String s) {
    final t = s.trim();
    final m = _pattern.firstMatch(t.length >= 10 ? t.substring(0, 10) : t);
    if (m == null) throw FormatException('Invalid date', s);
    if (t.length > 10) {
      final sep = t[10];
      if (sep != ' ' && sep != 'T' && sep != 't') throw FormatException('Invalid date', s);
    }
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final probe = DateTime.utc(y, mo, d);
    if (mo < 1 || mo > 12 || d < 1 || probe.year != y || probe.month != mo || probe.day != d) {
      throw FormatException('Invalid date', s);
    }
    return LocalDate(y, mo, d);
  }

  /// Null for null, '' and anything unparseable. Accepts a [LocalDate] or a [DateTime] (its fields).
  static LocalDate? tryParse(Object? s) {
    if (s is LocalDate) return s;
    if (s is DateTime) return LocalDate.fromDateTime(s);
    if (s is! String || s.trim().isEmpty) return null;
    try {
      return LocalDate.parse(s);
    } on FormatException {
      return null;
    }
  }

  /// Takes the y/m/d FIELDS of [dt] as they are (no zone conversion).
  factory LocalDate.fromDateTime(DateTime dt) => LocalDate(dt.year, dt.month, dt.day);

  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  /// ISO 1 = Monday .. 7 = Sunday (== WorkingHours.weekday).
  int get weekday => toUtcMidnight().weekday;

  LocalDate addDays(int days) => LocalDate.fromDateTime(DateTime.utc(year, month, day + days));

  /// Clamps the day (31 Jan + 1 month = 28/29 Feb).
  LocalDate addMonths(int months) {
    final total = year * 12 + (month - 1) + months;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final last = DateTime.utc(y, m + 1, 0).day;
    return LocalDate(y, m, day > last ? last : day);
  }

  /// other - this, in days.
  int daysUntil(LocalDate other) => other.toUtcMidnight().difference(toUtcMidnight()).inDays;

  LocalDate get mondayOfWeek => addDays(1 - weekday);
  LocalDate get firstOfMonth => LocalDate(year, month, 1);
  LocalDate get lastOfMonth => LocalDate(year, month, DateTime.utc(year, month + 1, 0).day);

  bool isBefore(LocalDate o) => compareTo(o) < 0;
  bool isAfter(LocalDate o) => compareTo(o) > 0;
  bool isSameMonth(LocalDate o) => year == o.year && month == o.month;

  /// `DateTime.utc(year, month, day)` (for arithmetic only).
  DateTime toUtcMidnight() => DateTime.utc(year, month, day);

  /// '2026-10-17'.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  String toString() => toIso();

  @override
  bool operator ==(Object other) =>
      other is LocalDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }
}
