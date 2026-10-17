import 'package:bizcat/core/session.dart';
import 'package:bizcat/features/profile/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/fixtures.dart';
import '../../support/pump.dart';

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(420, 2000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('shows the name, the phone and the stats', (t) async {
    _tall(t);
    await pumpBizcat(t, location: '/profile', signedIn: true);
    expect(find.text('Aziza Karimova'), findsOneWidget);
    expect(find.text(Phone.format('+998900000001')), findsOneWidget);
    expect(find.text('Bronlar'), findsOneWidget);
    expect(find.text('Hamyon'), findsOneWidget);
  });

  testWidgets('signed out shows the prompt and the app section', (t) async {
    _tall(t);
    await pumpBizcat(t, location: '/profile');
    expect(find.text('Bronlar, sevimlilar va bonuslar uchun kiring.'), findsOneWidget);
    expect(find.text('Ilova haqida'), findsOneWidget);
  });

  testWidgets('editing the name sends only the name', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/profile/edit',
      signedIn: true,
      setup: (api) => api.on('PATCH', '/v1/consumer/me', body: Fx.me),
    );
    expect(find.text("Ma'lumotlarim"), findsOneWidget);
    await t.enterText(find.byKey(const Key('profile-name')), 'Aziza K.');
    await t.pump();
    await t.tap(find.text('Saqlash'));
    await settle(t);
    expect(h.api.last('PATCH', '/v1/consumer/me').json, {'name': 'Aziza K.'});
    expect(find.text('Saqlandi.'), findsOneWidget);
  });

  testWidgets('a 422 shows the field error', (t) async {
    await pumpBizcat(
      t,
      location: '/profile/edit',
      signedIn: true,
      setup: (api) =>
          api.on('PATCH', '/v1/consumer/me', status: 422, body: Fx.error(422, "Ism noto'g'ri.", pointer: 'name')),
    );
    await t.enterText(find.byKey(const Key('profile-name')), 'Aziza K.');
    await t.pump();
    await t.tap(find.text('Saqlash'));
    await settle(t);
    expect(find.text("Ism noto'g'ri."), findsOneWidget);
  });

  testWidgets('Chiqish -> confirm signs out and goes home', (t) async {
    _tall(t);
    final h = await pumpBizcat(t, location: '/profile', signedIn: true);
    await t.tap(find.text('Chiqish'));
    await settle(t);
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Chiqish')));
    await settle(t);
    expect(h.session, isA<SessionSignedOut>());
    expect(h.location, '/home');
  });

  testWidgets('delete needs the checkbox, then sends DELETE /v1/consumer/me', (t) async {
    _tall(t);
    final h = await pumpBizcat(
      t,
      location: '/profile',
      signedIn: true,
      setup: (api) => api.on('DELETE', '/v1/consumer/me', status: 204, body: null),
    );
    await t.tap(find.text("Hisobni o'chirish"));
    await settle(t);
    final delete = find.widgetWithText(FilledButton, "O'chirish");
    expect(t.widget<FilledButton>(delete).onPressed, isNull);
    await t.tap(find.text('Tushundim'));
    await t.pump();
    await t.tap(delete);
    await settle(t);
    expect(h.api.called('DELETE', '/v1/consumer/me'), isTrue);
    expect(h.session, isA<SessionSignedOut>());
    expect(h.location, '/home');
  });

  test('patchBody sends explicit nulls only for cleared fields', () {
    final me = ConsumerUser.fromJson(Fx.data(Fx.me));
    final s = ProfileEditState.of(me).copyWith(gender: null, city: 'Termiz');
    expect(s.patchBody(), {'gender': null, 'city': 'Termiz'});
    expect(ProfileEditState.of(me).changed, isFalse);
  });
}
