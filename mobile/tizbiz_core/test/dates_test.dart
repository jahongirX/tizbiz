import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

void main() {
  group('parseUtc', () {
    test('API datetime without offset is UTC', () {
      final d = Dates.parseUtc('2026-10-17 05:00:00');
      expect(d, DateTime.utc(2026, 10, 17, 5));
      expect(d!.isUtc, isTrue);
      expect(Dates.parseUtc('2026-10-17T05:00:00'), DateTime.utc(2026, 10, 17, 5));
    });

    test('ISO offsets are honoured', () {
      expect(Dates.parseUtc('2026-10-17T10:00:00+05:00'), DateTime.utc(2026, 10, 17, 5));
      expect(Dates.parseUtc('2026-10-17T05:00:00Z'), DateTime.utc(2026, 10, 17, 5));
      expect(Dates.parseUtc('2026-10-17T05:00:00Z')!.isUtc, isTrue);
      expect(Dates.parseUtc('2026-10-17T00:30:00-0430'), DateTime.utc(2026, 10, 17, 5));
    });

    test('unix seconds', () {
      final expected = DateTime.fromMillisecondsSinceEpoch(1792054800000, isUtc: true);
      expect(Dates.parseUtc(1792054800), expected);
      expect(Dates.parseUtc('1792054800'), expected);
      expect(Dates.fromUnix(0), isNull);
      expect(Dates.fromUnix(-5), isNull);
      expect(Dates.toUnix(expected), 1792054800);
    });

    test('empty and garbage -> null', () {
      expect(Dates.parseUtc(null), isNull);
      expect(Dates.parseUtc(''), isNull);
      expect(Dates.parseUtc('0000-00-00 00:00:00'), isNull);
      expect(Dates.parseUtc('garbage'), isNull);
      expect(Dates.parseUtc('2026-02-30 10:00:00'), isNull);
    });
  });

  test('formatApiUtc', () {
    expect(Dates.formatApiUtc(DateTime.utc(2026, 10, 17, 5)), '2026-10-17 05:00:00');
    expect(Dates.formatApiUtc(DateTime.utc(2026, 10, 17, 5).toLocal()), '2026-10-17 05:00:00');
  });

  test('toBizLocal', () {
    final t = Dates.toBizLocal(DateTime.utc(2026, 10, 17, 5), 'Asia/Tashkent');
    expect(t.hour, 10);
    expect(t.minute, 0);
    expect(t.date, const LocalDate(2026, 10, 17));
    expect(t.hhmm, '10:00');
    expect(t.weekday, 6);
    expect(t.timezone, 'Asia/Tashkent');
    expect(t.utc.isUtc, isTrue);
  });

  test('day rollover', () {
    final t = Dates.toBizLocal(DateTime.utc(2026, 10, 16, 19, 30));
    expect(t.date, const LocalDate(2026, 10, 17));
    expect(t.hhmm, '00:30');
  });

  test('offsetOf', () {
    expect(Dates.offsetOf(null), const Duration(hours: 5));
    expect(Dates.offsetOf('Europe/Moscow'), const Duration(hours: 3));
    expect(Dates.offsetOf('Mars/Base'), const Duration(hours: 5));
    expect(Dates.offsetOf('+06:00'), const Duration(hours: 6));
    expect(Dates.offsetOf('+0500'), const Duration(hours: 5));
    expect(Dates.offsetOf('UTC+3'), const Duration(hours: 3));
    expect(Dates.offsetOf('GMT+05:00'), const Duration(hours: 5));
    expect(Dates.offsetOf('UTC'), Duration.zero);
    expect(Dates.offsetOf('-03:30'), const Duration(hours: -3, minutes: -30));
  });

  test('localToUtc / startOfLocalDayUtc', () {
    expect(Dates.localToUtc(const LocalDate(2026, 10, 17), const HmTime(10, 0)), DateTime.utc(2026, 10, 17, 5));
    expect(Dates.startOfLocalDayUtc(const LocalDate(2026, 10, 17)), DateTime.utc(2026, 10, 16, 19));
    expect(Dates.startOfLocalDayUtc(const LocalDate(2026, 10, 17), 'Europe/Moscow'), DateTime.utc(2026, 10, 16, 21));
  });

  test('todayLocal', () {
    expect(Dates.todayLocal(now: DateTime.utc(2026, 10, 16, 19, 0, 1)), const LocalDate(2026, 10, 17));
    expect(Dates.todayLocal(now: DateTime.utc(2026, 10, 16, 18, 59, 59)), const LocalDate(2026, 10, 16));
  });

  test('BizTime equality and ordering by instant', () {
    final a = Dates.toBizLocal(DateTime.utc(2026, 10, 17, 5));
    final b = Dates.toBizLocal(DateTime.utc(2026, 10, 17, 5));
    final c = Dates.toBizLocal(DateTime.utc(2026, 10, 17, 6));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.compareTo(c), lessThan(0));
    expect(a.time, const HmTime(10, 0));
    expect(a.minutesOfDay, 600);
  });
}
