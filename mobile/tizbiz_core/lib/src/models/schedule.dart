import 'package:meta/meta.dart';

import '../time/hm_time.dart';
import '../time/local_date.dart';
import '../util/json_read.dart';

/// GET /v1/staff/{id}/working-hours (live: id, staff_id, weekday, start_time 'HH:MM:SS', end_time)
/// and me/schedule.working_hours (BP 4.3: no staff_id).
@immutable
final class WorkingHours {
  const WorkingHours({this.id, this.staffId, required this.weekday, required this.start, required this.end});

  factory WorkingHours.fromJson(Map<String, dynamic> json) => WorkingHours(
        id: JsonRead.integerOrNull(json['id']),
        staffId: JsonRead.integerOrNull(json['staff_id']),
        weekday: JsonRead.integer(json['weekday'], 1),
        start: JsonRead.time(json['start_time']) ?? const HmTime(0, 0),
        end: JsonRead.time(json['end_time']) ?? const HmTime(0, 0),
      );

  final int? id;
  final int? staffId;

  /// ISO 1..7 (NOT 0 for Sunday).
  final int weekday;

  /// json: start_time.
  final HmTime start;

  /// json: end_time.
  final HmTime end;

  Map<String, dynamic> toJson() => {
        'id': id,
        'staff_id': staffId,
        'weekday': weekday,
        'start_time': start.toWire(),
        'end_time': end.toWire(),
      };
}

/// GET /v1/staff/{id}/time-off (live: id, staff_id, date, start_time|null, end_time|null, reason)
/// and me/schedule.time_off.
@immutable
final class TimeOff {
  const TimeOff({this.id, this.staffId, required this.date, this.start, this.end, this.reason});

  factory TimeOff.fromJson(Map<String, dynamic> json) => TimeOff(
        id: JsonRead.integerOrNull(json['id']),
        staffId: JsonRead.integerOrNull(json['staff_id']),
        date: JsonRead.date(json['date']) ?? const LocalDate(1970, 1, 1),
        start: JsonRead.time(json['start_time']),
        end: JsonRead.time(json['end_time']),
        reason: JsonRead.stringOrNull(json['reason']),
      );

  final int? id;
  final int? staffId;
  final LocalDate date;

  /// json: start_time (null + end null = whole day).
  final HmTime? start;

  /// json: end_time.
  final HmTime? end;
  final String? reason;

  bool get isFullDay => start == null && end == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'staff_id': staffId,
        'date': date.toIso(),
        'start_time': start?.toWire(),
        'end_time': end?.toWire(),
        'reason': reason,
      };
}

/// GET /v1/me/schedule.
@immutable
final class MeSchedule {
  const MeSchedule({this.workingHours = const [], this.timeOff = const []});

  factory MeSchedule.fromJson(Map<String, dynamic> json) => MeSchedule(
        workingHours: JsonRead.list(json['working_hours'], WorkingHours.fromJson),
        timeOff: JsonRead.list(json['time_off'], TimeOff.fromJson),
      );

  final List<WorkingHours> workingHours;
  final List<TimeOff> timeOff;

  Map<String, dynamic> toJson() => {
        'working_hours': [for (final w in workingHours) w.toJson()],
        'time_off': [for (final t in timeOff) t.toJson()],
      };
}
