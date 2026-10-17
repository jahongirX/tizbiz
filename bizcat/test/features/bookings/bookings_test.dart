import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:bizcat/app/routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_api.dart';
import '../../support/fixtures.dart';
import '../../support/pump.dart';

Map<String, dynamic> _copy(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

/// appointment5012 with overrides, as a `{"data": ...}` envelope.
Map<String, dynamic> _appt(Map<String, dynamic> patch) => Fx.wrap({..._copy(Fx.appointment5012), ...patch});

void _tallPhone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.pump();
  await t.tap(f);
  await settle(t);
}

void _lists(FakeApi api) => api
  ..on('GET', '/v1/consumer/appointments', body: Fx.appointmentsUpcoming, when: (q) => q['scope'] == 'upcoming')
  ..on('GET', '/v1/consumer/appointments', body: Fx.appointmentsPast, when: (q) => q['scope'] == 'past')
  ..on('GET', '/v1/consumer/orders', body: Fx.ordersActive, when: (q) => q['scope'] == 'active')
  ..on('GET', '/v1/consumer/orders', body: Fx.ordersPast, when: (q) => q['scope'] == 'past');

void main() {
  testWidgets('signed out: the login prompt', (t) async {
    await pumpBizcat(t, location: AppRoutes.bookings);

    expect(find.text('Bronlaringiz shu yerda'), findsOneWidget);
    expect(find.text('Kirish'), findsWidgets);
  });

  testWidgets('upcoming list shows the Shox Barber card', (t) async {
    final h = await pumpBizcat(t, location: AppRoutes.bookings, signedIn: true, setup: _lists);

    expect(find.text('Shox Barber'), findsOneWidget);
    expect(find.text('Tasdiqlangan'), findsOneWidget);
    expect(find.text('Soch olish + soqol'), findsOneWidget);
    expect(find.text("Oldindan to'lov qilingan"), findsOneWidget);
    final q = h.api.last('GET', '/v1/consumer/appointments').query;
    expect(q['scope'], 'upcoming');
    expect(q['per_page'], '20');
  });

  testWidgets("past tab requests scope=past and 'Sharh qoldirish' opens the composer", (t) async {
    final h = await pumpBizcat(t, location: AppRoutes.bookings, signedIn: true, setup: _lists);

    await t.tap(find.text("O'tgan"));
    await settle(t);
    expect(h.api.last('GET', '/v1/consumer/appointments').query['scope'], 'past');
    expect(find.text('Qayta yozilish'), findsOneWidget);

    await t.tap(find.text('Sharh qoldirish'));
    await settle(t);
    expect(h.location, AppRoutes.reviewNew(appointmentId: 4990, businessName: 'Shox Barber'));
    expect(h.location, '/review/new?appointment=4990&bname=Shox+Barber');
  });

  testWidgets('orders segment lists active orders', (t) async {
    await pumpBizcat(
      t,
      location: AppRoutes.bookingsWith(tab: 'orders'),
      signedIn: true,
      setup: _lists,
    );

    expect(find.text('Aziza Tortlari'), findsOneWidget);
    expect(find.text('Napoleon torti (1 kg) ×2'), findsOneWidget);
    expect(find.text('Yangi'), findsOneWidget);
  });

  testWidgets('empty upcoming list shows the catalog hint', (t) async {
    await pumpBizcat(
      t,
      location: AppRoutes.bookings,
      signedIn: true,
      setup: (api) => api.on('GET', '/v1/consumer/appointments', body: Fx.emptyPage),
    );

    expect(find.text("Kelgusi bronlar yo'q"), findsOneWidget);
    expect(find.text('Katalogni ochish'), findsOneWidget);
  });

  testWidgets('unpaid deposit: Payme opens the checkout and the poll picks up the payment', (t) async {
    _tallPhone(t);
    final unpaid = _appt({'paid': false, 'status': 'pending', 'can_cancel': true});
    final h = await pumpBizcat(
      t,
      location: AppRoutes.appointment(5012),
      signedIn: true,
      setup: (api) => api
        ..on('GET', '/v1/consumer/appointments/5012', body: unpaid)
        ..on('POST', '/v1/payments/deposit', status: 201, body: Fx.deposit),
    );

    expect(find.text('Bron #5012'), findsOneWidget);
    await _tap(t, find.text("Payme orqali to'lash"));

    final req = h.api.last('POST', '/v1/payments/deposit');
    expect(req.json, {'appointment_id': 5012, 'provider': 'payme'});
    expect(req.headers['idempotency-key'], 'dep-5012-payme');
    expect(req.hasAuth, isFalse);
    expect(h.opener.last.toString(), startsWith('https://checkout.paycom.uz/'));
    expect(find.text("To'lov tasdiqlanishi kutilmoqda..."), findsOneWidget);

    h.api
      ..off('GET', '/v1/consumer/appointments/5012')
      ..on('GET', '/v1/consumer/appointments/5012', body: _appt({'paid': true, 'status': 'pending'}));
    await t.pump(const Duration(seconds: 5));
    await settle(t);

    expect(find.text("To'lov qabul qilindi."), findsOneWidget);
    expect(find.text("Oldindan to'lov qilingan"), findsOneWidget);
    expect(find.text("Payme orqali to'lash"), findsNothing);
  });

  testWidgets('cancel sends the chosen reason and shows the cancelled chip', (t) async {
    _tallPhone(t);
    final h = await pumpBizcat(
      t,
      location: AppRoutes.appointment(5012),
      signedIn: true,
      setup: (api) => api
        ..on('GET', '/v1/consumer/appointments/5012', body: _appt({'paid': false, 'can_cancel': true}))
        ..on(
          'POST',
          '/v1/consumer/appointments/5012/cancel',
          body: _appt({'paid': false, 'status': 'canceled', 'can_cancel': false}),
        ),
    );

    await _tap(t, find.text('Bronni bekor qilish'));
    await t.tap(find.text("Rejam o'zgardi"));
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Bekor qilish'));
    await settle(t);

    expect(h.api.last('POST', '/v1/consumer/appointments/5012/cancel').json, {'reason': "Rejam o'zgardi"});
    expect(find.text('Bekor qilingan'), findsOneWidget);
  });

  testWidgets('cancel 409 shows the server message', (t) async {
    _tallPhone(t);
    await pumpBizcat(
      t,
      location: AppRoutes.appointment(5012),
      signedIn: true,
      setup: (api) => api
        ..on('GET', '/v1/consumer/appointments/5012', body: _appt({'paid': false, 'can_cancel': true}))
        ..on(
          'POST',
          '/v1/consumer/appointments/5012/cancel',
          status: 409,
          body: Fx.error(409, "Bu bronni bekor qilib bo'lmaydi."),
        ),
    );

    await _tap(t, find.text('Bronni bekor qilish'));
    await t.tap(find.widgetWithText(FilledButton, 'Bekor qilish'));
    await settle(t);

    expect(find.text("Bu bronni bekor qilib bo'lmaydi."), findsOneWidget);
  });

  testWidgets('missing appointment shows the not-found state', (t) async {
    await pumpBizcat(t, location: AppRoutes.appointment(1), signedIn: true);

    expect(find.text('Bron topilmadi'), findsOneWidget);
  });

  testWidgets('order detail renders and cancels', (t) async {
    _tallPhone(t);
    final cancelled = _copy(Fx.order702)
      ..['status'] = 'cancelled'
      ..['can_cancel'] = false;
    final h = await pumpBizcat(
      t,
      location: AppRoutes.order(702, created: true),
      signedIn: true,
      setup: (api) => api
        ..on('GET', '/v1/consumer/orders/702', body: Fx.wrap(Fx.order702))
        ..on('POST', '/v1/consumer/orders/702/cancel', body: Fx.wrap(cancelled)),
    );

    expect(find.text('Buyurtma #702'), findsOneWidget);
    expect(find.text('Buyurtmangiz qabul qilindi!'), findsOneWidget);
    expect(find.text('Napoleon torti (1 kg) ×2'), findsOneWidget);
    expect(find.text('Tayyorlanmoqda'), findsOneWidget);

    await _tap(t, find.text('Buyurtmani bekor qilish'));
    await t.tap(find.widgetWithText(TextButton, 'Bekor qilish'));
    await settle(t);

    expect(h.api.called('POST', '/v1/consumer/orders/702/cancel'), isTrue);
    expect(find.text('Buyurtma bekor qilindi.'), findsOneWidget);
    expect(find.text('Bekor qilingan'), findsWidgets);
  });
}
