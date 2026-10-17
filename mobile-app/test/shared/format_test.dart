import 'package:flutter_test/flutter_test.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fake_http.dart';
import '../support/fixtures.dart';

void main() {
  final a = ActiveBusiness.fromSession(fxAuthSession(engine: Engine.rental))!;

  test('sourceLabel', () {
    expect(sourceLabel('admin'), 'Admin');
    expect(sourceLabel('link'), 'Sayt');
    expect(sourceLabel('site'), 'Sayt');
    expect(sourceLabel('telegram'), 'Telegram');
    expect(sourceLabel('bot'), 'Telegram');
    expect(sourceLabel('app'), 'Bizcat');
    expect(sourceLabel(null), '—');
  });

  test('status action labels', () {
    expect(AppointmentStatus.confirmed.actionLabel, 'Tasdiqlash');
    expect(AppointmentStatus.arrived.actionLabel, 'Keldi');
    expect(AppointmentStatus.completed.actionLabel, 'Yakunlash');
    expect(AppointmentStatus.noShow.actionLabel, 'Kelmadi');
    expect(AppointmentStatus.canceled.actionLabel, 'Bekor qilish');
    expect(OrderStatus.newOrder.nextActionLabel, 'Tasdiqlash');
    expect(OrderStatus.confirmed.nextActionLabel, 'Tayyorlashni boshlash');
    expect(OrderStatus.preparing.nextActionLabel, 'Tayyor');
    expect(OrderStatus.ready.nextActionLabel, 'Topshirildi');
    expect(OrderStatus.delivered.nextActionLabel, '');
  });

  test('rentalSessionLabel', () {
    // 10:00-23:00 Tashkent = 05:00-18:00Z
    expect(rentalSessionLabel(fxAppointment(startsAt: '2026-11-14 05:00:00', endsAt: '2026-11-14 18:00:00'), a), "Kun bo'yi");
    expect(rentalSessionLabel(fxAppointment(startsAt: '2026-11-14 05:00:00', endsAt: '2026-11-14 11:00:00'), a), 'Ertalab');
    expect(rentalSessionLabel(fxAppointment(startsAt: '2026-11-14 13:00:00', endsAt: '2026-11-14 18:00:00'), a), 'Kechqurun');
  });

  test('bizTime / bizToday / fmtDayTime use the business zone', () {
    final t = bizTime(DateTime.utc(2026, 10, 17, 5), a);
    expect(t.hhmm, '10:00');
    expect(bizToday(() => DateTime.utc(2026, 10, 16, 20), a), const LocalDate(2026, 10, 17));
    expect(fmtDayTime(DateTime.utc(2026, 10, 17, 5), a, today: bizToday(() => kTestNow, a)), 'Bugun, 10:00');
  });
}
