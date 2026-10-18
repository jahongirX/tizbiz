import 'dart:async';

import 'package:bizcat/core/favorites.dart';
import 'package:bizcat/shared/widgets/favorite_button.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/pump.dart';

BusinessCard get _aziza => BusinessCard.fromJson(Fx.items(Fx.cards)[1]);

void main() {
  testWidgets('signed in: favorites load from the server', (t) async {
    final h = await pumpBizcat(
      t,
      signedIn: true,
      location: '/favorites',
      setup: (api) => api.on('GET', Endpoints.consumerFavorites, body: Fx.favorites),
    );
    await settle(t);
    expect(h.api.called('GET', Endpoints.consumerFavorites), isTrue);
    final s = h.container.read(favoritesProvider);
    expect(s.loaded, isTrue);
    expect(s.contains(2), isTrue);
    expect(s.cards.single.slug, 'shox-barber');
  });

  testWidgets('signed out: empty and loaded, toggle does nothing', (t) async {
    final h = await pumpBizcat(t);
    final s = h.container.read(favoritesProvider);
    expect(s.loaded, isTrue);
    expect(s.ids, isEmpty);
    bool? result;
    unawaited(h.container.read(favoritesProvider.notifier).toggle(_aziza).then((v) => result = v));
    await settle(t);
    expect(result, isFalse);
    expect(h.api.called('PUT', Endpoints.consumerFavorite(3)), isFalse);
  });

  testWidgets('toggle on -> PUT recorded and ids contain it', (t) async {
    final h = await pumpBizcat(t, signedIn: true, setup: (api) {
      api.on('PUT', Endpoints.consumerFavorite(3), status: 204);
    });
    bool? result;
    unawaited(h.container.read(favoritesProvider.notifier).toggle(_aziza).then((v) => result = v));
    await settle(t);
    expect(result, isTrue);
    expect(h.api.last('PUT', Endpoints.consumerFavorite(3)).hasAuth, isTrue);
    final s = h.container.read(favoritesProvider);
    expect(s.contains(3), isTrue);
    expect(s.cards.first.id, 3);
  });

  testWidgets('a toggle made while the first GET is in flight survives it', (t) async {
    final h = await pumpBizcat(t, signedIn: true, setup: (api) {
      api.on('PUT', Endpoints.consumerFavorite(3), status: 204);
    });
    // The first read schedules GET /favorites (-> []); toggle before it answers.
    unawaited(h.container.read(favoritesProvider.notifier).toggle(_aziza, current: false));
    await settle(t);
    expect(h.api.called('GET', Endpoints.consumerFavorites), isTrue);
    expect(h.container.read(favoritesProvider).contains(3), isTrue);
    expect(h.container.read(favoritesProvider).loaded, isTrue);
  });

  testWidgets('toggle off -> DELETE recorded and removed', (t) async {
    final h = await pumpBizcat(t, signedIn: true, setup: (api) {
      api
        ..on('GET', Endpoints.consumerFavorites, body: Fx.favorites)
        ..on('DELETE', Endpoints.consumerFavorite(2), status: 204);
    });
    h.container.read(favoritesProvider);
    await settle(t);
    expect(h.container.read(favoritesProvider).contains(2), isTrue);
    unawaited(h.container.read(favoritesProvider.notifier).toggleById(2));
    await settle(t);
    expect(h.api.called('DELETE', Endpoints.consumerFavorite(2)), isTrue);
    expect(h.container.read(favoritesProvider).contains(2), isFalse);
  });

  testWidgets('a PUT that returns 500 -> reverted plus a snackbar', (t) async {
    final h = await pumpBizcat(t, signedIn: true, setup: (api) {
      api.on('PUT', Endpoints.consumerFavorite(3), status: 500, body: Fx.error(500, 'Serverda xatolik.'));
    });
    bool? result;
    unawaited(h.container.read(favoritesProvider.notifier).toggle(_aziza).then((v) => result = v));
    await settle(t);
    expect(h.api.called('PUT', Endpoints.consumerFavorite(3)), isTrue);
    expect(result, isFalse);
    expect(h.container.read(favoritesProvider).contains(3), isFalse);
    expect(h.container.read(favoritesProvider).cards.any((c) => c.id == 3), isFalse);
    expect(find.text('Serverda xatolik.'), findsOneWidget);
  });

  testWidgets('FavoriteButton signed out opens the login with from', (t) async {
    final router = GoRouter(
      initialLocation: '/b/aziza-tortlari',
      routes: [
        GoRoute(
          path: '/b/:slug',
          builder: (_, _) => Scaffold(body: Center(child: FavoriteButton(businessId: 3, card: _aziza))),
        ),
        GoRoute(path: '/login', builder: (_, s) => Scaffold(body: Text('login ${s.uri.queryParameters['from']}'))),
      ],
    );
    addTearDown(router.dispose);
    await pumpInApp(t, const SizedBox(), router: router);
    await t.tap(find.byType(FavoriteButton));
    await settle(t);
    expect(find.text('login /b/aziza-tortlari'), findsOneWidget);
  });

  testWidgets('FavoriteButton signed in toggles through the controller', (t) async {
    final app = await pumpInApp(
      t,
      FavoriteButton(businessId: 3, card: _aziza),
      signedIn: true,
      setup: (api) => api.on('PUT', Endpoints.consumerFavorite(3), status: 204),
    );
    await settle(t);
    expect(find.byIcon(BzIcons.heart), findsOneWidget);
    await t.tap(find.byType(FavoriteButton));
    await settle(t);
    expect(app.api.called('PUT', Endpoints.consumerFavorite(3)), isTrue);
    expect(find.byIcon(BzIcons.heartBold), findsOneWidget);
    expect(find.byTooltip('Sevimlilardan olib tashlash'), findsOneWidget);
  });

  testWidgets('FavoriteButton signed out shows the heart off', (t) async {
    await pumpInApp(t, const FavoriteButton(businessId: 3, initial: true));
    // Signed out: favorites are "loaded" and empty, so the heart is off.
    expect(find.byIcon(BzIcons.heart), findsOneWidget);
    expect(find.byTooltip("Sevimlilarga qo'shish"), findsOneWidget);
  });
}
