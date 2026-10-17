import 'package:flutter_test/flutter_test.dart';
import 'package:tizbiz_biznes/features/timetable/layout.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

void main() {
  const tz = 'Asia/Tashkent';
  const day = LocalDate(2026, 10, 17); // Saturday

  test('three overlapping appointments get lanes 0,1,0 with a shared count', () {
    final a = fxAppointment(id: 1, startsAt: '2026-10-17 04:00:00', endsAt: '2026-10-17 05:00:00');
    final b = fxAppointment(id: 2, startsAt: '2026-10-17 04:30:00', endsAt: '2026-10-17 05:30:00');
    final c = fxAppointment(id: 3, startsAt: '2026-10-17 05:00:00', endsAt: '2026-10-17 06:00:00');
    final d = fxAppointment(id: 4, startsAt: '2026-10-17 08:00:00', endsAt: '2026-10-17 08:30:00');
    final lanes = computeLanes([c, a, d, b], tz);
    expect(lanes[1], (lane: 0, lanes: 2));
    expect(lanes[2], (lane: 1, lanes: 2));
    expect(lanes[3], (lane: 0, lanes: 2));
    expect(lanes[4], (lane: 0, lanes: 1));
  });

  test('visible range from working hours 09:00-20:00 and an 08:30 appointment', () {
    final hours = [fxWorkingHours(weekday: 6, start: '09:00:00', end: '20:00:00'), fxWorkingHours(weekday: 1, start: '06:00:00')];
    // 08:30 Tashkent = 03:30 UTC.
    final appt = fxAppointment(startsAt: '2026-10-17 03:30:00', endsAt: '2026-10-17 04:10:00');
    expect(visibleRange(day: day, hours: hours, appts: [appt], timezone: tz), (startMin: 480, endMin: 1200));
  });

  test('visible range defaults to 08:00-21:00 and rounds outwards', () {
    expect(visibleRange(day: day, hours: const [], appts: const [], timezone: tz), (startMin: 480, endMin: 1260));
    final late = fxAppointment(startsAt: '2026-10-17 16:15:00', endsAt: '2026-10-17 17:10:00'); // 21:15-22:10
    expect(visibleRange(day: day, hours: [fxWorkingHours(weekday: 6)], appts: [late], timezone: tz),
        (startMin: 540, endMin: 1380));
  });

  test('snapToSlot snaps to 30 minutes', () {
    expect(snapToSlot(0, 480), const HmTime(8, 0));
    expect(snapToSlot(kHourPx * 1.4, 480), const HmTime(9, 0));
    expect(snapToSlot(kHourPx * 1.6, 480), const HmTime(9, 30));
    expect(snapToSlot(kHourPx * 100, 480), const HmTime(23, 30));
  });
}
