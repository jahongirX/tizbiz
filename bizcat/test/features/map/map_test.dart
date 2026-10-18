import 'package:bizcat/features/map/map_screen.dart';
import 'package:bizcat/features/map/providers.dart';
import 'package:bizcat/features/map/widgets/map_business_card.dart';
import 'package:bizcat/features/map/widgets/map_pin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/fixtures.dart';
import '../../support/pump.dart';

const _path = '/v1/directory/map';

void main() {
  group('MapQuery', () {
    test('drops blank values and keeps the bbox and rating', () {
      const q = MapQuery(q: '  ', category: 'barber', bbox: '69.1,41.2,69.3,41.4', minRating: 4.5);
      expect(q.toQuery(), {'category': 'barber', 'bbox': '69.1,41.2,69.3,41.4', 'min_rating': '4.5'});
    });

    test('copyWith clears with null and keeps by default', () {
      const q = MapQuery(q: 'shox', category: 'barber', bbox: 'x', minRating: 4.5);
      expect(q.copyWith(bbox: null, minRating: null), const MapQuery(q: 'shox', category: 'barber'));
      expect(q.copyWith(), q);
    });

    test('bboxParam rounds to 4 decimals in west,south,east,north order', () {
      expect(bboxParam(west: 69.123456, south: 41.2, east: 69.3, north: 41.45678), '69.1235,41.2000,69.3000,41.4568');
    });

    test('labels', () {
      expect(distanceLabel(843), '840 m');
      expect(distanceLabel(3421), '3.4 km');
      expect(pinRatingLabel(BusinessCard.fromJson(Fx.shoxCard)), '4.7 (15)');
      expect(pinRatingLabel(BusinessCard.fromJson({...Fx.shoxCard, 'rating_count': 0})), 'Yangi');
    });
  });

  testWidgets('the round map button in the bottom bar opens the map with rated placemarks', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/home',
      setup: (api) => api.on('GET', _path, body: Fx.cards),
    );
    await t.tap(find.byKey(const Key('tab-map')));
    await settle(t);
    expect(h.location, '/map');
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(MapPin), findsNWidgets(2));
    expect(find.text('4.7 (15)'), findsOneWidget);
    expect(find.text('2 ta biznes'), findsOneWidget);
  });

  testWidgets('a placemark opens the card in a sheet; closing removes it at once', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/map',
      setup: (api) => api.on('GET', _path, body: Fx.cards),
    );
    await t.tap(find.byKey(const ValueKey('pin-shox-barber')));
    await settle(t);
    expect(find.byType(MapBusinessSheet), findsOneWidget);
    expect(find.text('· 15 ta sharh'), findsOneWidget);
    final pin = find.descendant(of: find.byKey(const ValueKey('pin-shox-barber')), matching: find.byType(MapPin));
    expect(t.widget<MapPin>(pin).selected, isTrue);

    await t.tap(find.byKey(const Key('map-sheet-close')));
    await t.pump();
    await t.pump();
    expect(find.byType(MapBusinessSheet), findsNothing);
    expect(t.widget<MapPin>(pin).selected, isFalse);
    expect(h.location, '/map');
  });

  testWidgets('Batafsil opens the business page', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/map',
      setup: (api) => api.on('GET', _path, body: Fx.cards),
    );
    await t.tap(find.byKey(const ValueKey('pin-aziza-tortlari')));
    await settle(t);
    await t.tap(find.byKey(const Key('map-sheet-open')));
    await settle(t);
    expect(h.location, '/b/aziza-tortlari');
  });

  testWidgets('service search, category and rating filters go to the request', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/map?category=barber',
      setup: (api) => api.on('GET', _path, body: Fx.cards),
    );
    expect(h.api.last('GET', _path).query['category'], 'barber');

    await t.enterText(find.byKey(const Key('map-search')), 'soch olish');
    await t.pump(const Duration(milliseconds: 450));
    await settle(t);
    var q = h.api.last('GET', _path).query;
    expect(q['q'], 'soch olish');
    expect(q['category'], 'barber');
    expect(q.containsKey('bbox'), isFalse);

    await t.tap(find.byKey(const Key('map-rating')));
    await settle(t);
    q = h.api.last('GET', _path).query;
    expect(q['min_rating'], '4.5');
  });

  testWidgets('no results shows the empty pill', (t) async {
    await pumpBizcat(
      t,
      location: '/map?q=zzz',
      setup: (api) => api.on('GET', _path, body: Fx.emptyList),
    );
    expect(find.byKey(const Key('map-empty')), findsOneWidget);
    expect(find.byType(MapPin), findsNothing);
  });

  testWidgets('home and the catalog app bar also open the map', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/home',
      setup: (api) => api.on('GET', _path, body: Fx.cards),
    );
    await t.tap(find.byKey(const Key('home-map')));
    await settle(t);
    expect(h.location, '/map');

    final h2 = await pumpBizcat(
      t,
      location: '/explore?category=barber',
      setup: (api) => api.on('GET', _path, body: Fx.cards),
    );
    await t.tap(find.byKey(const Key('directory-map')));
    await settle(t);
    expect(h2.location, '/map?category=barber');
  });
}
