import 'biz_time.dart';
import 'dates.dart';
import 'local_date.dart';

/// Uzbek Latin date/time formatters; they match the web apps exactly.
abstract final class UzDates {
  /// apps/admin/src/lib/datetime.js.
  static const List<String> monthsFull = [
    'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun', //
    'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
  ];

  /// apps/booking/src/format.js.
  static const List<String> monthsShort = [
    'yan', 'fev', 'mar', 'apr', 'may', 'iyn', //
    'iyl', 'avg', 'sen', 'okt', 'noy', 'dek',
  ];

  /// Index 0 = Monday (ISO weekday - 1).
  static const List<String> weekdaysLong = [
    'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba', //
  ];

  /// Booking day strip.
  static const List<String> weekdaysShort = ['Dush', 'Sesh', 'Chor', 'Pay', 'Jum', 'Shan', 'Yak'];

  /// Calendar headers.
  static const List<String> weekdaysMin = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  static String weekdayLong(int isoWeekday) => weekdaysLong[_wd(isoWeekday)];
  static String weekdayShort(int isoWeekday) => weekdaysShort[_wd(isoWeekday)];
  static String weekdayMin(int isoWeekday) => weekdaysMin[_wd(isoWeekday)];
  static String monthFull(int month) => monthsFull[_mo(month)];
  static String monthShort(int month) => monthsShort[_mo(month)];

  /// '17 oktabr'.
  static String dayMonth(LocalDate d) => '${d.day} ${monthFull(d.month)}';

  /// '17 okt'.
  static String dayMonthShort(LocalDate d) => '${d.day} ${monthShort(d.month)}';

  /// '17 oktabr 2026'.
  static String dayMonthYear(LocalDate d) => '${dayMonth(d)} ${d.year}';

  /// 'Shanba, 17 oktabr'.
  static String weekdayDayMonth(LocalDate d) => '${weekdayLong(d.weekday)}, ${dayMonth(d)}';

  /// '09:30'.
  static String hhmm(BizTime t) => t.hhmm;

  /// '09:00 – 09:40' (U+2013 with spaces).
  static String timeRange(BizTime start, BizTime end) => '${start.hhmm} – ${end.hhmm}';

  /// 'Bugun' (d == today), 'Ertaga' (+1), 'Kecha' (-1), else null.
  static String? relativeDay(LocalDate d, {required LocalDate today}) {
    switch (today.daysUntil(d)) {
      case 0:
        return 'Bugun';
      case 1:
        return 'Ertaga';
      case -1:
        return 'Kecha';
    }
    return null;
  }

  /// relativeDay ?? dayMonth, plus ' YYYY' when d.year != today.year:
  /// 'Bugun', 'Ertaga', '17 oktabr', '3 yanvar 2027'.
  static String dayLabel(LocalDate d, {required LocalDate today}) {
    final rel = relativeDay(d, today: today);
    if (rel != null) return rel;
    return d.year == today.year ? dayMonth(d) : dayMonthYear(d);
  }

  /// `'<dayLabel>, HH:MM'`: 'Bugun, 10:00', 'Ertaga, 09:30', '20 oktabr, 18:00'.
  static String dateTime(BizTime t, {required LocalDate today}) => '${dayLabel(t.date, today: today)}, ${t.hhmm}';

  /// apps/admin formatWeekRange: same month '13 - 19 iyul'; across months '29 iyun - 5 iyul'.
  static String weekRange(LocalDate monday) {
    final sunday = monday.addDays(6);
    final m1 = monthFull(monday.month);
    final m2 = monthFull(sunday.month);
    if (m1 == m2) return '${monday.day} - ${sunday.day} $m2';
    return '${monday.day} $m1 - ${sunday.day} $m2';
  }

  /// apps/booking duration(): 30 -> '30 daqiqa', 60 -> '1 soat', 90 -> '1 soat 30 daqiqa',
  /// 0 -> '0 daqiqa'.
  static String duration(int minutes) {
    final m = minutes < 0 ? 0 : minutes;
    final h = m ~/ 60;
    final r = m % 60;
    final parts = <String>[
      if (h > 0) '$h soat',
      if (r > 0 || h == 0) '$r daqiqa',
    ];
    return parts.join(' ');
  }

  /// Review/notification age: < 60 s 'hozirgina'; < 60 min 'N daqiqa oldin'; < 24 h 'N soat oldin';
  /// < 7 days 'N kun oldin'; else dayLabel of the instant's business-local date
  /// ('12 oktabr' / '12 oktabr 2025').
  static String ago(DateTime instant, {required DateTime now, String? timezone}) {
    final diff = now.difference(instant);
    if (diff.inSeconds < 60) return 'hozirgina';
    if (diff.inMinutes < 60) return '${diff.inMinutes} daqiqa oldin';
    if (diff.inHours < 24) return '${diff.inHours} soat oldin';
    if (diff.inDays < 7) return '${diff.inDays} kun oldin';
    return dayLabel(
      Dates.localDateOf(instant, timezone),
      today: Dates.localDateOf(now, timezone),
    );
  }

  static int _wd(int isoWeekday) => ((isoWeekday - 1) % 7 + 7) % 7;
  static int _mo(int month) => ((month - 1) % 12 + 12) % 12;
}
