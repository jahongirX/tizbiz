import 'package:bizcat/core/session.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';
import '../../support/pump.dart';

CtaButton _cta(WidgetTester t, String label) => t.widget<CtaButton>(find.widgetWithText(CtaButton, label));

Future<void> _enterPhone(WidgetTester t, String text) async {
  await t.enterText(find.byType(TextField).first, text);
  await t.pump();
}

void main() {
  testWidgets('a short phone keeps Kod olish disabled', (t) async {
    await pumpBizcat(t, location: '/login');
    expect(find.text('Telefon raqamingizni kiriting'), findsOneWidget);
    await _enterPhone(t, '12345');
    expect(_cta(t, 'Kod olish').onPressed, isNull);
  });

  testWidgets('phone -> code -> verify signs in and goes to from', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/login?from=%2Ffavorites',
      setup: (api) => api
        ..on('POST', '/v1/consumer/auth/otp', body: Fx.otp)
        ..on('POST', '/v1/consumer/auth/verify', body: Fx.verify)
        ..on('GET', '/v1/consumer/me', body: Fx.me),
    );
    await _enterPhone(t, '900000001');
    await t.tap(find.text('Kod olish'));
    await settle(t);

    final otp = h.api.last('POST', '/v1/consumer/auth/otp');
    expect(otp.json, {'phone': '+998900000001'});
    expect(otp.hasAuth, isFalse);
    expect(find.text('Kodni kiriting'), findsOneWidget);

    await t.enterText(find.byKey(const ValueKey('otp-code')), '1111');
    await t.pump();
    await t.tap(find.text('Tasdiqlash'));
    await settle(t);

    expect(h.api.last('POST', '/v1/consumer/auth/verify').json, {'phone': '+998900000001', 'code': '1111'});
    expect(h.session, isA<SessionSignedIn>());
    expect(h.location, '/favorites');
  });

  testWidgets('a 422 code shows the field error and clears the field', (t) async {
    await pumpBizcat(
      t,
      location: '/login/code?phone=%2B998900000001',
      setup: (api) => api.on(
        'POST',
        '/v1/consumer/auth/verify',
        status: 422,
        body: Fx.error(422, "Kod noto'g'ri yoki muddati o'tgan.", pointer: 'code'),
      ),
    );
    await t.enterText(find.byKey(const ValueKey('otp-code')), '2222');
    await t.pump();
    await t.tap(find.text('Tasdiqlash'));
    await settle(t);
    expect(find.text("Kod noto'g'ri yoki muddati o'tgan."), findsOneWidget);
    expect(t.widget<TextField>(find.byKey(const ValueKey('otp-code'))).controller!.text, isEmpty);
  });

  testWidgets('429 with Retry-After 42 starts the countdown at 0:42', (t) async {
    await pumpBizcat(
      t,
      location: '/login',
      setup: (api) => api.on(
        'POST',
        '/v1/consumer/auth/otp',
        status: 429,
        headers: {'retry-after': '42'},
        body: Fx.error(429, "Juda ko'p urinish. Birozdan keyin qayta urinib ko'ring."),
      ),
    );
    await _enterPhone(t, '900000001');
    await t.tap(find.text('Kod olish'));
    await settle(t);
    expect(find.text("Juda ko'p urinish. Birozdan keyin qayta urinib ko'ring."), findsOneWidget);
    await t.tap(find.text('Kodni kiritish'));
    await settle(t);
    expect(find.textContaining('Qayta yuborish: 0:4'), findsOneWidget);
    expect(find.text('Qayta yuborish: 0:42'), findsOneWidget);
  });

  testWidgets('is_new goes to the name step, which saves the name', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/login/code?phone=%2B998900000001',
      setup: (api) => api
        ..on('POST', '/v1/consumer/auth/verify', body: Fx.verifyNew)
        ..on('GET', '/v1/consumer/me', body: Fx.me)
        ..on('PATCH', '/v1/consumer/me', body: Fx.me),
    );
    await t.enterText(find.byKey(const ValueKey('otp-code')), '1111');
    await t.pump();
    await t.tap(find.text('Tasdiqlash'));
    await settle(t);
    expect(h.location, startsWith('/login/name'));
    expect(find.text('Ismingiz nima?'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'A');
    await t.tap(find.text('Saqlash'));
    await settle(t);
    expect(find.text("Ism kamida 2 ta harf bo'lsin."), findsOneWidget);

    await t.enterText(find.byType(TextField), 'Aziza');
    await t.tap(find.text('Saqlash'));
    await settle(t);
    expect(h.api.last('PATCH', '/v1/consumer/me').json, {'name': 'Aziza'});
    expect(h.location, '/home');
  });
}
