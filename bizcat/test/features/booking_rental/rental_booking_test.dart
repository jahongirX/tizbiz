import 'package:bizcat/features/booking_rental/providers.dart';
import 'package:bizcat/features/booking_rental/widgets/rental_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/fake_api.dart';
import '../../support/fixtures.dart';
import '../../support/pump.dart';

final _uuidV4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

/// Saturday 2026-10-17, 12:00 in Tashkent.
DateTime _now() => DateTime.utc(2026, 10, 17, 7);

void _rentalApi(FakeApi api) {
  api
    ..on('GET', '/v1/site/serenada', body: Fx.siteRental)
    ..on('GET', '/v1/site/serenada/booked-days', body: Fx.bookedDays)
    ..on('GET', '/v1/consumer/appointments/5012', body: Fx.appointment5012);
}

Future<TestHarness> _pump(WidgetTester t, {int postStatus = 201, Map<String, dynamic>? postBody}) async {
  final h = await pumpBizcat(
    t,
    location: '/b/serenada/rent',
    signedIn: true,
    overrides: [rentalNowProvider.overrideWithValue(_now)],
    setup: (api) {
      _rentalApi(api);
      api.on('POST', '/v1/consumer/appointments', status: postStatus, body: postBody ?? Fx.appointment5012);
    },
  );
  await settle(t);
  return h;
}

VoidCallback? _cellTap(WidgetTester t, LocalDate d) =>
    t.widget<InkWell>(find.descendant(of: find.byKey(rentalDayKey(d)), matching: find.byType(InkWell))).onTap;

/// Kechqurun -> 120 guests -> November -> the 21st (booked only in the morning).
Future<void> _toConfirm(WidgetTester t) async {
  expect(find.text("To'y vaqtini tanlang"), findsOneWidget);
  await t.tap(find.text('Kechqurun'));
  await settle(t);

  await t.tap(find.byTooltip("Ko'paytirish"));
  await t.pump();
  await t.tap(find.byTooltip("Ko'paytirish"));
  await settle(t);
  expect(find.text('120'), findsOneWidget);
  expect(find.text('12 ta stol'), findsOneWidget);
  expect(find.text(Money.format(300000000)), findsOneWidget);

  await t.tap(find.text('Davom etish'));
  await settle(t);
  await t.tap(find.byTooltip('Keyingi oy'));
  await settle(t);

  expect(_cellTap(t, const LocalDate(2026, 11, 15)), isNull, reason: 'booked for the evening');
  expect(_cellTap(t, const LocalDate(2026, 11, 14)), isNull, reason: 'booked for both');
  expect(_cellTap(t, const LocalDate(2026, 11, 21)), isNotNull, reason: 'booked only in the morning');

  final cell = find.byKey(rentalDayKey(const LocalDate(2026, 11, 21)));
  await t.drag(find.byType(Scrollable).first, const Offset(0, -400));
  await settle(t);
  await t.tap(cell);
  await settle(t);
  expect(find.text('4-qadam / 4 · Tasdiqlash'), findsOneWidget);
}

void main() {
  testWidgets('session -> guests -> date -> Bron qilish posts the rental body', (t) async {
    final h = await _pump(t);
    expect(find.text('Sanani band qilish'), findsOneWidget);
    expect(find.text('Serenada'), findsOneWidget);
    await _toConfirm(t);

    await t.tap(find.text('Bron qilish'));
    await settle(t);

    final req = h.api.last('POST', '/v1/consumer/appointments');
    expect(req.body, {'staff_id': 5, 'service_id': 40, 'date': '2026-11-21', 'session': 'evening', 'guests': 120});
    expect(req.headers['idempotency-key'], matches(_uuidV4));
    expect(h.location, '/bookings/a/5012?new=1');
  });

  testWidgets('a 409 goes back to the date step with the snackbar', (t) async {
    final h = await _pump(t, postStatus: 409, postBody: Fx.error(409, 'Bu sana allaqachon band.'));
    await _toConfirm(t);
    await t.tap(find.text('Bron qilish'));
    await settle(t);

    expect(find.text("Kechirasiz, bu sana band bo'ldi. Iltimos, boshqa sanani tanlang."), findsOneWidget);
    expect(find.text('3-qadam / 4 · Sana'), findsOneWidget);
    expect(h.location, '/b/serenada/rent');
  });

  testWidgets('a slot storefront is replaced with the slot flow', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/b/shox-barber/rent',
      signedIn: true,
      setup: (api) => api
        ..on('GET', '/v1/site/shox-barber', body: Fx.siteSlot)
        ..on('GET', '/v1/staff/2/availability', body: Fx.availability),
    );
    await settle(t);
    expect(h.location, '/b/shox-barber/book');
  });
}
