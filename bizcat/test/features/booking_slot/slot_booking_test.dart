import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api.dart';
import '../../support/fixtures.dart';
import '../../support/pump.dart';

final _uuidV4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

void _slotApi(FakeApi api) {
  api
    ..on('GET', '/v1/site/shox-barber', body: Fx.siteSlot)
    ..on('GET', '/v1/staff/2/availability', body: Fx.availability)
    ..on('GET', '/v1/consumer/appointments/5012', body: Fx.appointment5012);
}

Future<void> _pickFirstSlot(WidgetTester t) async {
  await t.tap(find.text('Soch olish + soqol'));
  await settle(t);
  // One active staff: the staff step is skipped.
  expect(find.text('Sanani tanlang'), findsOneWidget);
  await t.ensureVisible(find.text('09:00'));
  await t.tap(find.text('09:00'));
  await settle(t);
}

void main() {
  testWidgets('service -> slot -> Band qilish posts the booking and opens the appointment', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/b/shox-barber/book',
      signedIn: true,
      setup: (api) {
        _slotApi(api);
        api.on('POST', '/v1/consumer/appointments', status: 201, body: Fx.appointment5012);
      },
    );
    await settle(t);
    expect(find.text('Navbatga yozilish'), findsOneWidget);
    expect(find.text('Xizmatni tanlang'), findsOneWidget);

    await _pickFirstSlot(t);
    expect(find.text('4-qadam / 4 · Tasdiqlash'), findsOneWidget);
    expect(find.text('Usta Jahongir'), findsOneWidget);
    expect(find.text('Aziza Karimova'), findsOneWidget);

    await t.tap(find.text('Band qilish'));
    await settle(t);

    final req = h.api.last('POST', '/v1/consumer/appointments');
    expect(req.body, {'staff_id': 2, 'service_id': 11, 'starts_at': '2026-10-19 04:00:00', 'name': 'Aziza Karimova'});
    expect(req.headers['idempotency-key'], matches(_uuidV4));
    expect(h.location, '/bookings/a/5012?new=1');
  });

  testWidgets('a 409 goes back to the time step with the snackbar', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/b/shox-barber/book',
      signedIn: true,
      setup: (api) {
        _slotApi(api);
        api.on('POST', '/v1/consumer/appointments', status: 409, body: Fx.error(409, 'Tanlangan vaqt band.'));
      },
    );
    await settle(t);
    await _pickFirstSlot(t);
    await t.tap(find.text('Band qilish'));
    await settle(t);

    expect(find.text("Kechirasiz, bu vaqt band bo'ldi. Iltimos, boshqa vaqtni tanlang."), findsOneWidget);
    expect(find.text('Sanani tanlang'), findsOneWidget);
    expect(find.text('Band qilish'), findsNothing);
    expect(h.location, '/b/shox-barber/book');
  });

  testWidgets('a 403 shows the server message with a way back to the business', (t) async {
    await pumpBizcat(
      t,
      location: '/b/shox-barber/book',
      signedIn: true,
      setup: (api) {
        _slotApi(api);
        api.on(
          'POST',
          '/v1/consumer/appointments',
          status: 403,
          body: Fx.error(403, 'Bu biznesda onlayn yozilish yopiq.'),
        );
      },
    );
    await settle(t);
    await _pickFirstSlot(t);
    await t.tap(find.text('Band qilish'));
    await settle(t);

    expect(find.text('Bu biznesda onlayn yozilish yopiq.'), findsOneWidget);
    expect(find.text('Biznes sahifasiga'), findsOneWidget);
  });

  testWidgets('rebook params open the time step first', (t) async {
    await pumpBizcat(t, location: '/b/shox-barber/book?service=11&staff=2', signedIn: true, setup: _slotApi);
    await settle(t);
    expect(find.text('Sanani tanlang'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
  });

  testWidgets('a catalog storefront is replaced with the menu', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/b/aziza-tortlari/book',
      signedIn: true,
      setup: (api) => api.on('GET', '/v1/site/aziza-tortlari', body: Fx.siteCatalog),
    );
    await settle(t);
    expect(h.location, '/b/aziza-tortlari/menu');
  });
}
