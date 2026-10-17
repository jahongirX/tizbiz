import 'dart:async';
import 'dart:convert';

import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/core/prefs.dart';
import 'package:bizcat/core/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/pump.dart';

void main() {
  testWidgets('restore with no token -> signed out', (t) async {
    final h = await pumpBizcat(t);
    expect(h.session, isA<SessionSignedOut>());
    expect((h.session as SessionSignedOut).reason, SignOutReason.none);
    expect(h.api.called('GET', Endpoints.consumerMe), isFalse);
  });

  testWidgets('restore with a token + me 200 -> signed in and cached', (t) async {
    final h = await pumpBizcat(t, signedIn: true);
    final s = h.session;
    expect(s, isA<SessionSignedIn>());
    s as SessionSignedIn;
    expect(s.consumer.id, 17);
    expect(s.consumer.name, 'Aziza Karimova');
    expect(s.consumer.stats?.favoritesTotal, 2);
    expect(s.stale, isFalse);
    expect(h.api.last('GET', Endpoints.consumerMe).headers['authorization'], startsWith('Bearer '));
    expect(h.container.read(appPrefsProvider).cachedProfile?.id, 17);
    expect(h.container.read(consumerIdProvider), 17);
    expect(h.container.read(isSignedInProvider), isTrue);
  });

  testWidgets('me 401 -> signed out (expired) and the token store cleared', (t) async {
    final h = await pumpBizcat(t, signedIn: true, setup: (api) {
      api.on('GET', Endpoints.consumerMe, status: 401, body: Fx.unauthorized);
    });
    expect(h.session, const SessionSignedOut(SignOutReason.expired));
    expect(h.api.tokenStore!.value, isNull);
    expect(h.container.read(consumerIdProvider), isNull);
  });

  testWidgets('network error with a cached profile -> signed in, stale', (t) async {
    const cached = ConsumerUser(id: 17, phone: '+998900000001', name: 'Aziza Karimova');
    final h = await pumpBizcat(
      t,
      signedIn: true,
      prefs: {AppPrefs.kProfile: jsonEncode(cached.toJson())},
      setup: (api) => api.on('GET', Endpoints.consumerMe, networkError: true),
    );
    final s = h.session;
    expect(s, isA<SessionSignedIn>());
    s as SessionSignedIn;
    expect(s.stale, isTrue);
    expect(s.consumer.name, 'Aziza Karimova');

    // Back online: refreshProfile() clears the stale flag.
    h.api.on('GET', Endpoints.consumerMe, body: Fx.me);
    unawaited(h.container.read(sessionProvider.notifier).refreshProfile());
    await settle(t);
    expect((h.session as SessionSignedIn).stale, isFalse);
  });

  testWidgets('network error without a cache -> signed in (id from the token), stale', (t) async {
    final h = await pumpBizcat(t, signedIn: true, setup: (api) => api.on('GET', Endpoints.consumerMe, networkError: true));
    final s = h.session as SessionSignedIn;
    expect(s.stale, isTrue);
    expect(s.consumer.id, 17);
  });

  testWidgets('on /profile/wallet a 401 from any request -> login with expired=1', (t) async {
    final h = await pumpBizcat(t, signedIn: true, location: '/profile/wallet', setup: (api) {
      api
        ..on('GET', Endpoints.consumerLoyalty, body: Fx.loyalty)
        ..on('GET', '/v1/consumer/probe', status: 401, body: Fx.unauthorized);
    });
    expect(h.location, '/profile/wallet');

    Object? error;
    unawaited(h.container.read(apiProvider).get<Object?>('/v1/consumer/probe').then(
          (_) {},
          onError: (Object e) => error = e,
        ));
    await settle(t);

    expect(error, isA<ApiException>());
    expect(h.session, const SessionSignedOut(SignOutReason.expired));
    expect(h.location, '/login?from=%2Fprofile%2Fwallet&expired=1');
    // The snackbar (BIZCAT-SPEC §6) and the login screen's banner (§9.2) both say it.
    expect(find.text('Sessiya tugadi. Qaytadan kiring.'), findsNWidgets(2));
    expect(h.container.read(appPrefsProvider).cachedProfile, isNull);
  });

  testWidgets('signIn stores the token, caches the profile and sets the city', (t) async {
    final h = await pumpBizcat(t);
    final session = ConsumerSession.fromJson(Fx.data(Fx.verify));
    unawaited(h.container.read(sessionProvider.notifier).signIn(session));
    await settle(t);
    expect(h.session, isA<SessionSignedIn>());
    expect(h.api.tokenStore!.value, session.token);
    expect(h.container.read(appPrefsProvider).cachedProfile?.id, 17);
    expect(h.container.read(cityProvider), 'Toshkent');
    expect(h.prefs.getString(AppPrefs.kCity), 'Toshkent');
  });

  testWidgets('signIn keeps an explicitly chosen city', (t) async {
    final h = await pumpBizcat(t, prefs: {AppPrefs.kCity: 'Termiz'});
    final session = ConsumerSession.fromJson(Fx.data(Fx.verify));
    unawaited(h.container.read(sessionProvider.notifier).signIn(session));
    await settle(t);
    expect(h.container.read(cityProvider), 'Termiz');
  });

  testWidgets('signOut clears the token and the cache', (t) async {
    final h = await pumpBizcat(t, signedIn: true);
    unawaited(h.container.read(sessionProvider.notifier).signOut());
    await settle(t);
    expect(h.session, const SessionSignedOut(SignOutReason.user));
    expect(h.api.tokenStore!.value, isNull);
    expect(h.container.read(appPrefsProvider).cachedProfile, isNull);
  });

  testWidgets('updateConsumer replaces the profile', (t) async {
    final h = await pumpBizcat(t, signedIn: true);
    h.container
        .read(sessionProvider.notifier)
        .updateConsumer(const ConsumerUser(id: 17, phone: '+998900000001', name: 'Aziza K.'));
    await settle(t);
    expect(h.container.read(currentConsumerProvider)?.name, 'Aziza K.');
    expect(h.container.read(appPrefsProvider).cachedProfile?.name, 'Aziza K.');
  });
}
