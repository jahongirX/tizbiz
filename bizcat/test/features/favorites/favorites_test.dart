import 'package:bizcat/core/favorites.dart';
import 'package:bizcat/shared/widgets/business_cards.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';
import '../../support/pump.dart';

void main() {
  testWidgets('renders both favorites; the heart removes the first with a DELETE', (t) async {
    t.view.physicalSize = const Size(420, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await pumpBizcat(
      t,
      location: '/favorites',
      signedIn: true,
      setup: (api) => api
        ..on('GET', '/v1/consumer/favorites', body: {'data': Fx.items(Fx.cards)})
        ..on('DELETE', '/v1/consumer/favorites/2', status: 204, body: null),
    );
    h.container.read(favoritesProvider);
    await settle(t);
    expect(find.byType(BusinessCardTile), findsNWidgets(2));

    await t.tap(find.descendant(of: find.byKey(const ValueKey('fav-2')), matching: find.byIcon(Icons.favorite)));
    await settle(t);
    expect(h.api.called('DELETE', '/v1/consumer/favorites/2'), isTrue);
    expect(find.byKey(const ValueKey('fav-2')), findsNothing);
    expect(find.byType(BusinessCardTile), findsOneWidget);
    expect(find.text('Sevimlilardan olib tashlandi'), findsOneWidget);
  });

  testWidgets('empty list shows the empty state', (t) async {
    await pumpBizcat(t, location: '/favorites', signedIn: true);
    await settle(t);
    expect(find.text("Sevimlilar ro'yxati bo'sh"), findsOneWidget);
  });

  testWidgets('signed out shows the login prompt', (t) async {
    await pumpBizcat(t, location: '/favorites');
    expect(find.text('Sevimli joylaringiz'), findsOneWidget);
    expect(find.text('Kirish'), findsOneWidget);
  });
}
