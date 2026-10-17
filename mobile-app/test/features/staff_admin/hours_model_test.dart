import 'package:flutter_test/flutter_test.dart';
import 'package:tizbiz_biznes/features/staff_admin/hours_model.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

void main() {
  test('fromRows groups by weekday; missing days are off', () {
    final m = HoursModel.fromRows([
      fxWorkingHours(weekday: 1, start: '14:00:00', end: '18:00:00'),
      fxWorkingHours(id: 22, weekday: 1, start: '09:00:00', end: '13:00:00'),
      fxWorkingHours(id: 23, weekday: 7, start: '10:00:00', end: '15:00:00'),
    ]);
    expect(m.days.length, 7);
    expect(m.day(1).working, isTrue);
    expect(m.day(1).intervals.first.start, const HmTime(9, 0));
    expect(m.day(2).working, isFalse);
    expect(m.day(7).working, isTrue);
  });

  test('start must be before end', () {
    final m = HoursModel.fromRows([fxWorkingHours(weekday: 2, start: '18:00:00', end: '09:00:00')]);
    expect(m.validate(), {2: kStartError});
  });

  test('overlapping intervals are rejected, touching ones are fine', () {
    var m = HoursModel.fromRows([
      fxWorkingHours(weekday: 3, start: '09:00:00', end: '13:00:00'),
      fxWorkingHours(id: 2, weekday: 3, start: '12:00:00', end: '18:00:00'),
    ]);
    expect(m.validate(), {3: kOverlapError});
    m = m.setInterval(3, 1, const HoursInterval(HmTime(13, 0), HmTime(18, 0)));
    expect(m.validate(), isEmpty);
  });

  test('toInput yields items with weekday 7 for Sunday', () {
    final m = HoursModel.fromRows([
      fxWorkingHours(weekday: 7, start: '10:00:00', end: '15:00:00'),
      fxWorkingHours(id: 2, weekday: 1, start: '09:00:00', end: '18:00:00'),
    ]);
    expect(m.toInput().toJson(), {
      'items': [
        {'weekday': 1, 'start_time': '09:00:00', 'end_time': '18:00:00'},
        {'weekday': 7, 'start_time': '10:00:00', 'end_time': '15:00:00'},
      ],
    });
    expect(m.weekdayOfItem(1), 7);
    expect(m.setWorking(1, false).setWorking(7, false).toInput().toJson(), {'items': <Object>[]});
  });

  test('standard and copy Monday', () {
    final std = HoursModel.standard();
    expect([for (final d in std.days) d.working], [true, true, true, true, true, true, false]);
    final m = HoursModel.fromRows([fxWorkingHours(weekday: 1, start: '08:00:00', end: '17:00:00')]).copyMondayToWeekdays();
    expect([for (var d = 2; d <= 6; d++) m.day(d).intervals.single], everyElement(const HoursInterval(HmTime(8, 0), HmTime(17, 0))));
    expect(m.day(7).working, isFalse);
  });
}
