import 'package:flutter/foundation.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// One working interval of a day.
@immutable
final class HoursInterval {
  const HoursInterval(this.start, this.end);

  final HmTime start;
  final HmTime end;

  HoursInterval copyWith({HmTime? start, HmTime? end}) => HoursInterval(start ?? this.start, end ?? this.end);

  @override
  bool operator ==(Object other) => other is HoursInterval && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// One weekday row of the editor. [intervals] are kept while the day is switched off so the
/// switch can be flipped back without losing them.
@immutable
final class DayHours {
  const DayHours({required this.weekday, required this.working, required this.intervals});

  /// ISO 1..7 (never 0).
  final int weekday;
  final bool working;
  final List<HoursInterval> intervals;

  DayHours copyWith({bool? working, List<HoursInterval>? intervals}) =>
      DayHours(weekday: weekday, working: working ?? this.working, intervals: intervals ?? this.intervals);

  @override
  bool operator ==(Object other) =>
      other is DayHours && other.weekday == weekday && other.working == working && _listEq(other.intervals, intervals);

  @override
  int get hashCode => Object.hash(weekday, working, Object.hashAll(intervals));
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

const kStartError = "Boshlanish vaqti tugash vaqtidan oldin bo'lishi kerak";
const kOverlapError = 'Oraliqlar kesishmasligi kerak';
const _defaultInterval = HoursInterval(HmTime(9, 0), HmTime(18, 0));

/// Pure model of the working-hours editor (BIZNES-SPEC §9.8): 7 rows Monday..Sunday.
@immutable
final class HoursModel {
  const HoursModel._(this.days);

  /// Rows from GET working-hours; days without rows are days off (with a 09:00-18:00 template).
  factory HoursModel.fromRows(List<WorkingHours> rows) {
    final byDay = <int, List<HoursInterval>>{};
    for (final r in rows) {
      if (r.weekday < 1 || r.weekday > 7) continue;
      byDay.putIfAbsent(r.weekday, () => []).add(HoursInterval(r.start, r.end));
    }
    return HoursModel._([
      for (var d = 1; d <= 7; d++)
        DayHours(
          weekday: d,
          working: byDay.containsKey(d),
          intervals: byDay.containsKey(d)
              ? (byDay[d]!..sort((a, b) => a.start.compareTo(b.start)))
              : const [_defaultInterval],
        ),
    ]);
  }

  /// Mon-Sat 09:00-18:00, Sunday off.
  factory HoursModel.standard() => HoursModel._([
        for (var d = 1; d <= 7; d++) DayHours(weekday: d, working: d <= 6, intervals: const [_defaultInterval]),
      ]);

  final List<DayHours> days;

  DayHours day(int weekday) => days[weekday - 1];

  bool get allOff => days.every((d) => !d.working);

  HoursModel _replace(int weekday, DayHours Function(DayHours) f) =>
      HoursModel._([for (final d in days) d.weekday == weekday ? f(d) : d]);

  HoursModel setWorking(int weekday, bool working) => _replace(weekday, (d) {
        final intervals = d.intervals.isEmpty ? const [_defaultInterval] : d.intervals;
        return d.copyWith(working: working, intervals: intervals);
      });

  HoursModel setInterval(int weekday, int index, HoursInterval interval) => _replace(weekday, (d) {
        final list = [...d.intervals];
        list[index] = interval;
        return d.copyWith(intervals: list);
      });

  /// Appends an interval after the last one (last end .. +1 h), or 09:00-18:00.
  HoursModel addInterval(int weekday) => _replace(weekday, (d) {
        if (d.intervals.isEmpty) return d.copyWith(intervals: const [_defaultInterval]);
        final lastEnd = d.intervals.last.end.minutesOfDay;
        final start = lastEnd >= 23 * 60 ? 23 * 60 : lastEnd;
        final end = (start + 60).clamp(start + 1, 23 * 60 + 59);
        return d.copyWith(intervals: [...d.intervals, HoursInterval(HmTime.fromMinutes(start), HmTime.fromMinutes(end))]);
      });

  HoursModel removeInterval(int weekday, int index) => _replace(weekday, (d) {
        final list = [...d.intervals]..removeAt(index);
        return list.isEmpty ? d.copyWith(working: false, intervals: const [_defaultInterval]) : d.copyWith(intervals: list);
      });

  /// Copies Monday (working flag + intervals) to Tuesday..Saturday.
  HoursModel copyMondayToWeekdays() {
    final mon = day(1);
    return HoursModel._([
      for (final d in days)
        d.weekday >= 2 && d.weekday <= 6 ? d.copyWith(working: mon.working, intervals: [...mon.intervals]) : d,
    ]);
  }

  /// Error text per weekday (working days only): start < end, then no overlaps.
  Map<int, String> validate() {
    final errors = <int, String>{};
    for (final d in days) {
      if (!d.working) continue;
      if (d.intervals.any((i) => i.start.compareTo(i.end) >= 0)) {
        errors[d.weekday] = kStartError;
        continue;
      }
      final sorted = [...d.intervals]..sort((a, b) => a.start.compareTo(b.start));
      for (var i = 1; i < sorted.length; i++) {
        if (sorted[i].start.compareTo(sorted[i - 1].end) < 0) {
          errors[d.weekday] = kOverlapError;
          break;
        }
      }
    }
    return errors;
  }

  /// Items in the order they are sent (weekday ascending, start ascending).
  List<WorkingHours> get items => [
        for (final d in days)
          if (d.working)
            for (final i in [...d.intervals]..sort((a, b) => a.start.compareTo(b.start)))
              WorkingHours(weekday: d.weekday, start: i.start, end: i.end),
      ];

  /// Body of PUT working-hours: `{"items":[...]}`.
  WorkingHoursInput toInput() => WorkingHoursInput(items);

  /// Weekday of the i-th sent item (maps 422 pointers `items[i].start_time` back to a row).
  int? weekdayOfItem(int index) {
    final list = items;
    return index >= 0 && index < list.length ? list[index].weekday : null;
  }

  @override
  bool operator ==(Object other) => other is HoursModel && _listEq(other.days, days);

  @override
  int get hashCode => Object.hashAll(days);
}
