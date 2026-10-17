import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

void main() {
  test('parse / format / wire', () {
    expect(HmTime.parse('09:00:00'), const HmTime(9, 0));
    expect(HmTime.parse('9:05').format(), '09:05');
    expect(HmTime.parse('9:05').toWire(), '09:05:00');
    expect(HmTime.fromMinutes(570).format(), '09:30');
    expect(HmTime.fromMinutes(1440 + 60), const HmTime(1, 0));
    expect(HmTime.fromMinutes(-30), const HmTime(23, 30));
    expect(const HmTime(9, 30).minutesOfDay, 570);
    expect(() => HmTime.parse('24:00'), throwsFormatException);
    expect(() => HmTime.parse('10:60'), throwsFormatException);
    expect(HmTime.tryParse(null), isNull);
    expect(HmTime.tryParse('x'), isNull);
  });

  test('ordering', () {
    final list = [const HmTime(18, 0), const HmTime(9, 0), const HmTime(9, 30)]..sort();
    expect(list, [const HmTime(9, 0), const HmTime(9, 30), const HmTime(18, 0)]);
    expect(const HmTime(9, 0).compareTo(const HmTime(9, 0)), 0);
  });
}
