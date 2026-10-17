import 'package:tizbiz_core/tizbiz_core.dart';

/// Height of one hour in the day grid.
const double kHourPx = 64;

/// Width of the left time gutter.
const double kGutterPx = 48;

/// Minimum column width per staff.
const double kMinColumnPx = 132;

/// Minimum block height.
const double kMinBlockPx = 24;

const int _defaultStart = 8 * 60;
const int _defaultEnd = 21 * 60;

/// Local start minute of [a] on [day] (0 when it started the day before).
int apptStartMin(Appointment a, LocalDate day, String timezone) {
  final s = a.startLocal(timezone);
  if (s.date.isBefore(day)) return 0;
  if (s.date.isAfter(day)) return 1440;
  return s.minutesOfDay;
}

/// Local end minute of [a] on [day] (1440 when it ends after midnight).
int apptEndMin(Appointment a, LocalDate day, String timezone) {
  final e = a.endLocal(timezone);
  if (e.date.isAfter(day)) return 1440;
  if (e.date.isBefore(day)) return 0;
  return e.minutesOfDay;
}

/// Visible hour range: min(start of working hours of the visible staff on [day].weekday, first
/// appointment start), max(end, last appointment end); default 08:00-21:00 when there is neither;
/// clamped to 00:00-24:00; rounded outwards to whole hours.
({int startMin, int endMin}) visibleRange({
  required LocalDate day,
  required List<WorkingHours> hours,
  required List<Appointment> appts,
  required String timezone,
}) {
  int? start;
  int? end;
  void take(int s, int e) {
    start = start == null || s < start! ? s : start;
    end = end == null || e > end! ? e : end;
  }

  for (final h in hours) {
    if (h.weekday != day.weekday) continue;
    take(h.start.minutesOfDay, h.end.minutesOfDay);
  }
  for (final a in appts) {
    take(apptStartMin(a, day, timezone), apptEndMin(a, day, timezone));
  }
  var s = start ?? _defaultStart;
  var e = end ?? _defaultEnd;
  s = (s ~/ 60) * 60;
  e = ((e + 59) ~/ 60) * 60;
  if (s < 0) s = 0;
  if (e > 1440) e = 1440;
  if (e <= s) e = (s + 60).clamp(60, 1440);
  if (e <= s) s = e - 60;
  return (startMin: s, endMin: e);
}

/// Overlap lanes for one staff column: greedy by start time. Every appointment of one cluster of
/// overlapping appointments gets the cluster's lane count.
Map<int, ({int lane, int lanes})> computeLanes(List<Appointment> appts, String timezone) {
  final sorted = [...appts]..sort((a, b) {
      final c = a.startsAt.compareTo(b.startsAt);
      return c != 0 ? c : a.endsAt.compareTo(b.endsAt);
    });
  final result = <int, ({int lane, int lanes})>{};
  final laneEnds = <DateTime>[];
  final cluster = <int, int>{}; // id -> lane
  DateTime? clusterEnd;

  void closeCluster() {
    final n = laneEnds.length;
    for (final e in cluster.entries) {
      result[e.key] = (lane: e.value, lanes: n);
    }
    cluster.clear();
    laneEnds.clear();
    clusterEnd = null;
  }

  for (final a in sorted) {
    final end = a.endsAt.isAfter(a.startsAt) ? a.endsAt : a.startsAt.add(const Duration(minutes: 1));
    if (clusterEnd != null && !a.startsAt.isBefore(clusterEnd!)) closeCluster();
    var lane = laneEnds.indexWhere((e) => !e.isAfter(a.startsAt));
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(end);
    } else {
      laneEnds[lane] = end;
    }
    cluster[a.id] = lane;
    clusterEnd = clusterEnd == null || end.isAfter(clusterEnd!) ? end : clusterEnd;
  }
  closeCluster();
  return result;
}

/// Snap a tap y offset (from the top of the grid) to a 30-minute slot.
HmTime snapToSlot(double dy, int startMin) {
  final raw = startMin + (dy / kHourPx * 60).floor();
  final snapped = (raw ~/ 30) * 30;
  return HmTime.fromMinutes(snapped.clamp(0, 1410));
}

/// Pixel offset of minute-of-day [min] inside a grid starting at [startMin].
double minuteToY(int min, int startMin) => (min - startMin) / 60 * kHourPx;
