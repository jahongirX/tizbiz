import 'dart:async';

import 'package:bizcat/core/prefs.dart';
import 'package:bizcat/features/onboarding/splash_screen.dart';
import 'package:bizcat/shared/widgets/brand.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump.dart';

void main() {
  testWidgets('splash renders the logo and the slow note after 8 s', (t) async {
    await pumpInApp(t, const SplashScreen(), wrapInScaffold: false);
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.text('Ulanish sekin...'), findsOneWidget); // present but transparent
    await t.pump(const Duration(seconds: 9));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Ulanish sekin...'), findsOneWidget);
  });

  testWidgets('skip jumps to the city page; Boshlash saves city + onboarded and goes home', (t) async {
    final h = await pumpBizcat(t, location: '/onboarding', prefs: {AppPrefs.kOnboarded: false});
    expect(find.text('Shahringizdagi eng yaxshi joylar'), findsOneWidget);
    await t.tap(find.text("O'tkazib yuborish"));
    await settle(t);
    expect(find.text('Shahringizni tanlang'), findsOneWidget);
    expect(find.text("O'tkazib yuborish"), findsNothing);

    await t.tap(find.text('Toshkent'));
    await t.pump();
    await t.tap(find.text('Boshlash'));
    await settle(t);

    final prefs = h.container.read(appPrefsProvider);
    expect(prefs.onboarded, isTrue);
    expect(prefs.city, 'Toshkent');
    expect(h.location, '/home');
  });

  testWidgets('Keyinroq sets onboarded and keeps the city null', (t) async {
    final h = await pumpBizcat(t, location: '/onboarding', prefs: {AppPrefs.kOnboarded: false});
    await t.tap(find.text("O'tkazib yuborish"));
    await settle(t);
    await t.tap(find.text('Keyinroq'));
    await settle(t);
    final prefs = h.container.read(appPrefsProvider);
    expect(prefs.onboarded, isTrue);
    expect(prefs.city, isNull);
    expect(h.location, '/home');
  });

  testWidgets('city picker saves Termiz and pops', (t) async {
    final h = await pumpBizcat(t);
    unawaited(h.router.push('/city'));
    await settle(t);
    expect(find.text('Shahar'), findsOneWidget);
    await t.tap(find.text('Termiz'));
    await settle(t);
    expect(h.container.read(appPrefsProvider).city, 'Termiz');
    expect(h.location, '/home');
  });
}
