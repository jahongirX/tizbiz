import 'package:meta/meta.dart';

/// A wall-clock time of day (HH:MM), e.g. working hours or a slot's local start.
@immutable
final class HmTime implements Comparable<HmTime> {
  const HmTime(this.hour, this.minute)
      : assert(hour >= 0 && hour <= 23, 'hour must be 0..23'),
        assert(minute >= 0 && minute <= 59, 'minute must be 0..59');

  /// 'HH:MM' or 'HH:MM:SS' ('9:05' accepted). Throws [FormatException].
  factory HmTime.parse(String s) {
    final m = _pattern.firstMatch(s.trim());
    if (m == null) throw FormatException('Invalid time', s);
    final h = int.parse(m.group(1)!);
    final mi = int.parse(m.group(2)!);
    final sec = m.group(3) == null ? 0 : int.parse(m.group(3)!);
    if (h > 23 || mi > 59 || sec > 59) throw FormatException('Invalid time', s);
    return HmTime(h, mi);
  }

  /// Null for null, '' and anything unparseable.
  static HmTime? tryParse(Object? s) {
    if (s is HmTime) return s;
    if (s is! String || s.trim().isEmpty) return null;
    try {
      return HmTime.parse(s);
    } on FormatException {
      return null;
    }
  }

  /// 570 -> 09:30 (mod 1440).
  factory HmTime.fromMinutes(int minutesOfDay) {
    final m = minutesOfDay % 1440;
    return HmTime(m ~/ 60, m % 60);
  }

  static final RegExp _pattern = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$');

  final int hour;
  final int minute;

  int get minutesOfDay => hour * 60 + minute;

  /// '09:30'.
  String format() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// '09:30:00' (working_hours / time_off writes).
  String toWire() => '${format()}:00';

  @override
  String toString() => format();

  @override
  bool operator ==(Object other) => other is HmTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  int compareTo(HmTime other) => minutesOfDay.compareTo(other.minutesOfDay);
}
