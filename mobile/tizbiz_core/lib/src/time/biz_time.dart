import 'package:meta/meta.dart';

import 'hm_time.dart';
import 'local_date.dart';

/// An instant plus the business's fixed UTC offset. Never use `DateTime.toLocal()` for business
/// times: the device zone is irrelevant, the business zone (business.timezone, fallback
/// Asia/Tashkent) rules.
@immutable
final class BizTime implements Comparable<BizTime> {
  const BizTime(this.utc, this.offset, this.timezone);

  /// isUtc == true.
  final DateTime utc;

  /// +05:00 for Asia/Tashkent.
  final Duration offset;

  /// 'Asia/Tashkent'.
  final String timezone;

  /// utc + offset, still flagged isUtc; its FIELDS are the business wall clock.
  /// Internal helper; prefer the getters.
  DateTime get wall => utc.toUtc().add(offset);

  int get year => wall.year;
  int get month => wall.month;
  int get day => wall.day;
  int get hour => wall.hour;
  int get minute => wall.minute;

  /// ISO 1..7, business-local.
  int get weekday => wall.weekday;

  /// Business-local calendar day.
  LocalDate get date => LocalDate.fromDateTime(wall);

  HmTime get time {
    final w = wall;
    return HmTime(w.hour, w.minute);
  }

  /// '10:00'.
  String get hhmm => time.format();

  int get minutesOfDay => time.minutesOfDay;

  @override
  bool operator ==(Object other) => other is BizTime && other.utc.isAtSameMomentAs(utc);

  @override
  int get hashCode => utc.microsecondsSinceEpoch.hashCode;

  @override
  int compareTo(BizTime other) => utc.compareTo(other.utc);

  @override
  String toString() => '${date.toIso()} $hhmm ($timezone)';
}
