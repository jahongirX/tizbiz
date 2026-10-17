import 'package:bizcat/features/map/map_screen.dart';
import 'package:bizcat/features/map/providers.dart';
import 'package:bizcat/features/map/widgets/map_business_card.dart';
import 'package:bizcat/features/map/widgets/map_pin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';
import '../../support/pump.dart';

const _path = '/v1/directory/map';

void main() {
  group('MapQuery', () {
    test('drops blank values and keeps the bbox', () {
      const q = MapQuery(q: '  ', category: 'barber', bbox: '69.1,41.2,69.3,41.4');
      expect(q.toQuery(), {'category': 'barber', 'bbox': '69.1,41.2,69.3,41.4'});
    });

    test('copyWith clears with null and keeps by default', () {
      const q = MapQuery(q: 'shox', category: 'barber', bbox: 'x');
      expect(q.copyWith(bbox: null), const MapQuery(q: 'shox', category: 'barber'));
      expect(q.copyWith(), q);
    });

    test('bboxParam rounds to 4 decimals in west,south,east,north order', () {
      expect(bboxParam(west: 69.123456, south: 41.2, east: 69.3, north: 41.45678), '69.1235,41.2000,69.3000,41.4568');
    });

    test('distanceLabel', () {
      expect(distanceLabel(843), '840 m');
      expect(distanceLabel(3421), '3.4 km');
    });
  });

  testWidgets('home map button opens the map with a pin and a card per business', (t) async {
    final h = await pumpBizcat(t, location: '/home', setup: (api) => api.on('GET', _path, body: Fx.cards));
    await t.tap(find.byKey(const Key('home-map')));
    await settle(t);
    expect(h.location, '/map');
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(MapPin), findsNWidgets(2));
    expect(find.byType(MapBusinessCard), findsWidgets);
    expect(find.text('Shox Barber'), findsOneWidget);
  });

  testWidgets('a pin tap selects it, a second tap opens the business', (t) async {
    final h = await pumpBizcat(t, location: '/map', setup: (api) => api.on('GET', _path, body: Fx.cards));
    final pin = find.byKey(const ValueKey('pin-aziza-tortlari'));
    expect(t.widget<MapPin>(find.descendant(of: pin, matching: find.byType(MapPin))).selected, isFalse);
    await t.tap(pin);
    await settle(t);
    expect(t.widget<MapPin>(find.descendant(of: pin, matching: find.byType(MapPin))).selected, isTrue);
    expect(h.location, '/map');
    await t.tap(pin);
    await settle(t);
    expect(h.location, '/b/aziza-tortlari');
  });

  testWidgets('a card tap opens the business', (t) async {
    final h = await pumpBizcat(t, location: '/map', setup: (api) => api.on('GET', _path, body: Fx.cards));
    await t.tap(find.byKey(const ValueKey('map-card-shox-barber')));
    await settle(t);
    expect(h.location, '/b/shox-barber');
  });

  testWidgets('search and category chips go to the request; typing searches everywhere', (t) async {
    final h = await pumpBizcat(t, location: '/map?category=barber', setup: (api) => api.on('GET', _path, body: Fx.cards));
    expect(h.api.last('GET', _path).query['category'], 'barber');

    await t.enterText(find.byKey(const Key('map-search')), 'Shox');
    await t.pump(const Duration(milliseconds: 450));
    await settle(t);
    final q = h.api.last('GET', _path).query;
    expect(q['q'], 'Shox');
    expect(q['category'], 'barber');
    expect(q.containsKey('bbox'), isFalse);
  });

  testWidgets('no results shows the empty pill', (t) async {
    await pumpBizcat(t, location: '/map?q=zzz', setup: (api) => api.on('GET', _path, body: Fx.emptyList));
    expect(find.byKey(const Key('map-empty')), findsOneWidget);
    expect(find.byType(MapPin), findsNothing);
  });

  testWidgets('directory app bar has a map button carrying the filter', (t) async {
    final h = await pumpBizcat(t, location: '/explore?category=barber', setup: (api) => api.on('GET', _path, body: Fx.cards));
    await t.tap(find.byKey(const Key('directory-map')));
    await settle(t);
    expect(h.location, '/map?category=barber');
  });
}
