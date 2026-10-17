import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

void main() {
  test('parse / toIso', () {
    final d = LocalDate.parse('2026-10-17');
    expect([d.year, d.month, d.day], [2026, 10, 17]);
    expect(d.toIso(), '2026-10-17');
    expect(LocalDate.parse(d.toIso()), d);
    expect(d.toString(), '2026-10-17');
    expect(LocalDate.parse('2026-10-17 05:00:00'), const LocalDate(2026, 10, 17));
    expect(LocalDate.parse('2026-10-17T05:00:00Z'), const LocalDate(2026, 10, 17));
    expect(() => LocalDate.parse('17.10.2026'), throwsFormatException);
    expect(() => LocalDate.parse('2026-02-30'), throwsFormatException);
    expect(LocalDate.tryParse(null), isNull);
    expect(LocalDate.tryParse(''), isNull);
    expect(LocalDate.tryParse('0000-00-00'), isNull);
    expect(LocalDate.tryParse('2026-10-17'), const LocalDate(2026, 10, 17));
  });

  test('weekday is ISO', () {
    expect(const LocalDate(2026, 10, 17).weekday, 6);
    expect(const LocalDate(2026, 10, 19).weekday, 1);
    expect(const LocalDate(2026, 10, 18).weekday, 7);
  });

  test('addDays / mondayOfWeek', () {
    expect(const LocalDate(2026, 10, 17).addDays(15), const LocalDate(2026, 11, 1));
    expect(const LocalDate(2026, 12, 25).addDays(7), const LocalDate(2027, 1, 1));
    expect(const LocalDate(2026, 1, 1).addDays(-1), const LocalDate(2025, 12, 31));
    expect(const LocalDate(2026, 10, 18).mondayOfWeek, const LocalDate(2026, 10, 12));
    expect(const LocalDate(2026, 10, 12).mondayOfWeek, const LocalDate(2026, 10, 12));
  });

  test('addMonths clamps / month bounds', () {
    expect(const LocalDate(2026, 1, 31).addMonths(1), const LocalDate(2026, 2, 28));
    expect(const LocalDate(2028, 1, 31).addMonths(1), const LocalDate(2028, 2, 29));
    expect(const LocalDate(2026, 11, 15).addMonths(3), const LocalDate(2027, 2, 15));
    expect(const LocalDate(2026, 1, 15).addMonths(-1), const LocalDate(2025, 12, 15));
    expect(const LocalDate(2028, 2, 10).lastOfMonth, const LocalDate(2028, 2, 29));
    expect(const LocalDate(2028, 2, 10).firstOfMonth, const LocalDate(2028, 2, 1));
  });

  test('daysUntil, ordering, equality', () {
    const a = LocalDate(2026, 10, 17);
    const b = LocalDate(2026, 11, 1);
    expect(a.daysUntil(b), 15);
    expect(b.daysUntil(a), -15);
    expect(a.isBefore(b), isTrue);
    expect(b.isAfter(a), isTrue);
    expect(a.isSameMonth(const LocalDate(2026, 10, 1)), isTrue);
    final list = [b, a, const LocalDate(2025, 12, 31)]..sort();
    expect(list, [const LocalDate(2025, 12, 31), a, b]);
    final map = {LocalDate.parse('2026-10-17'): 'x'};
    expect(map[const LocalDate(2026, 10, 17)], 'x');
    expect(LocalDate.parse('2026-10-17').hashCode, a.hashCode);
  });
}
