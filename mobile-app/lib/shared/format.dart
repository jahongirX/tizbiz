import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// [utc] in the business zone.
BizTime bizTime(DateTime utc, ActiveBusiness a) => Dates.toBizLocal(utc, a.timezone);

/// Business-local "today" from the app clock (`ref.read(clockProvider)`).
LocalDate bizToday(DateTime Function() clock, [ActiveBusiness? a]) =>
    Dates.todayLocal(timezone: a?.timezone, now: clock());

/// 'Bugun, 10:00' / '20 oktabr, 18:00' in the business zone.
String fmtDayTime(DateTime utc, ActiveBusiness a, {required LocalDate today}) =>
    UzDates.dateTime(bizTime(utc, a), today: today);

/// Booking / order source label: admin -> Admin, link/site -> Sayt, telegram/bot -> Telegram,
/// app -> Bizcat; unknown -> as is; null/empty -> '—'.
String sourceLabel(String? source) {
  final s = source?.trim().toLowerCase();
  return switch (s) {
    null || '' => '—',
    'admin' => 'Admin',
    'link' || 'site' => 'Sayt',
    'telegram' || 'bot' => 'Telegram',
    'app' => 'Bizcat',
    _ => source!.trim(),
  };
}

/// Button label for moving an appointment INTO this status.
extension AppointmentStatusAction on AppointmentStatus {
  String get actionLabel => switch (this) {
        AppointmentStatus.confirmed => 'Tasdiqlash',
        AppointmentStatus.arrived => 'Keldi',
        AppointmentStatus.completed => 'Yakunlash',
        AppointmentStatus.noShow => 'Kelmadi',
        AppointmentStatus.canceled => 'Bekor qilish',
        AppointmentStatus.pending || AppointmentStatus.unknown => label,
      };
}

/// One-tap label for the order's suggested next step (`status.next`); '' when there is none.
extension OrderStatusAction on OrderStatus {
  String get nextActionLabel => switch (this) {
        OrderStatus.newOrder => 'Tasdiqlash',
        OrderStatus.confirmed => 'Tayyorlashni boshlash',
        OrderStatus.preparing => 'Tayyor',
        OrderStatus.ready => 'Topshirildi',
        _ => '',
      };
}

/// Rental session of a booking from its local times: 10:00-23:00 -> "Kun bo'yi",
/// start before 17:00 -> "Ertalab", else "Kechqurun".
String rentalSessionLabel(Appointment a, ActiveBusiness b) {
  final start = a.startLocal(b.timezone);
  final end = a.endLocal(b.timezone);
  if (start.hour == 10 && end.hour == 23) return "Kun bo'yi";
  return start.hour < 17 ? 'Ertalab' : 'Kechqurun';
}
