import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

void main() {
  const today = LocalDate(2026, 10, 17);

  test('day/month formats', () {
    expect(UzDates.dayMonth(today), '17 oktabr');
    expect(UzDates.dayMonth(const LocalDate(2026, 9, 1)), '1 sentabr');
    expect(UzDates.dayMonthShort(const LocalDate(2026, 7, 18)), '18 iyl');
    expect(UzDates.dayMonthYear(today), '17 oktabr 2026');
    expect(UzDates.monthFull(1), 'yanvar');
    expect(UzDates.monthShort(12), 'dek');
  });

  test('weekdays', () {
    expect(UzDates.weekdayLong(1), 'Dushanba');
    expect(UzDates.weekdayLong(7), 'Yakshanba');
    expect(UzDates.weekdayShort(6), 'Shan');
    expect(UzDates.weekdayMin(3), 'Ch');
    expect(UzDates.weekdayDayMonth(today), 'Shanba, 17 oktabr');
  });

  test('relativeDay / dayLabel', () {
    expect(UzDates.relativeDay(today, today: today), 'Bugun');
    expect(UzDates.relativeDay(const LocalDate(2026, 10, 18), today: today), 'Ertaga');
    expect(UzDates.relativeDay(const LocalDate(2026, 10, 16), today: today), 'Kecha');
    expect(UzDates.relativeDay(const LocalDate(2026, 10, 20), today: today), isNull);
    expect(UzDates.dayLabel(const LocalDate(2027, 1, 3), today: today), '3 yanvar 2027');
    expect(UzDates.dayLabel(const LocalDate(2026, 10, 20), today: today), '20 oktabr');
    expect(UzDates.dayLabel(today, today: today), 'Bugun');
  });

  test('dateTime / hhmm / timeRange', () {
    final t = Dates.toBizLocal(DateTime.utc(2026, 10, 17, 5));
    expect(UzDates.dateTime(t, today: today), 'Bugun, 10:00');
    expect(UzDates.dateTime(Dates.toBizLocal(DateTime.utc(2026, 10, 18, 5)), today: today), 'Ertaga, 10:00');
    expect(UzDates.dateTime(Dates.toBizLocal(DateTime.utc(2026, 10, 20, 13)), today: today), '20 oktabr, 18:00');
    expect(UzDates.hhmm(t), '10:00');
    final end = Dates.toBizLocal(DateTime.utc(2026, 10, 17, 5, 40));
    expect(UzDates.timeRange(t, end), '10:00 – 10:40');
  });

  test('weekRange', () {
    expect(UzDates.weekRange(const LocalDate(2026, 7, 13)), '13 - 19 iyul');
    expect(UzDates.weekRange(const LocalDate(2026, 6, 29)), '29 iyun - 5 iyul');
  });

  test('duration', () {
    expect(UzDates.duration(30), '30 daqiqa');
    expect(UzDates.duration(60), '1 soat');
    expect(UzDates.duration(90), '1 soat 30 daqiqa');
    expect(UzDates.duration(0), '0 daqiqa');
  });

  test('ago', () {
    final now = DateTime.utc(2026, 10, 17, 7);
    expect(UzDates.ago(now.subtract(const Duration(seconds: 30)), now: now), 'hozirgina');
    expect(UzDates.ago(now.subtract(const Duration(minutes: 5)), now: now), '5 daqiqa oldin');
    expect(UzDates.ago(now.subtract(const Duration(hours: 3)), now: now), '3 soat oldin');
    expect(UzDates.ago(now.subtract(const Duration(days: 2)), now: now), '2 kun oldin');
    expect(UzDates.ago(now.subtract(const Duration(days: 10)), now: now), '7 oktabr');
    expect(UzDates.ago(now.subtract(const Duration(days: 400)), now: now), '12 sentabr 2025');
  });
}
