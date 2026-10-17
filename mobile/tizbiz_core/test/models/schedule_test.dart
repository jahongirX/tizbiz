import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('live working hours', () {
    final list = dataList(workingHoursLiveJson).map(WorkingHours.fromJson).toList();
    expect(list.first.start, const HmTime(9, 0));
    expect(list.first.end, const HmTime(20, 0));
    expect(list.first.staffId, 2);
    expect(list.last.weekday, 7);
    expect(list.first.toJson()['start_time'], '09:00:00');
    for (final w in list) {
      expectFixedPoint(w, (x) => x.toJson(), WorkingHours.fromJson);
    }
  });

  test('live time-off with times', () {
    final t = TimeOff.fromJson(dataList(timeOffLiveJson).single);
    expect(t.isFullDay, isFalse);
    expect(t.start, const HmTime(13, 0));
    expectFixedPoint(t, (x) => x.toJson(), TimeOff.fromJson);
  });

  test('me/schedule', () {
    final s = MeSchedule.fromJson(dataMap(meScheduleJson));
    expect(s.workingHours.single.staffId, isNull);
    expect(s.workingHours.single.start, const HmTime(9, 0));
    expect(s.timeOff.single.isFullDay, isTrue);
    expect(s.timeOff.single.date, const LocalDate(2026, 10, 25));
    expect(s.timeOff.single.reason, 'Dam olish');
    expectFixedPoint(s, (x) => x.toJson(), MeSchedule.fromJson);
  });

  test('WorkingHoursInput body', () {
    final s = MeSchedule.fromJson(dataMap(meScheduleJson));
    expect(WorkingHoursInput(s.workingHours).toJson(), {
      'items': [
        {'weekday': 1, 'start_time': '09:00:00', 'end_time': '20:00:00'},
      ],
    });
  });
}
