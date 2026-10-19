import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/shared/widgets/rating.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_api.dart';
import '../../support/fixtures.dart';
import '../../support/pump.dart';

Map<String, dynamic> _copy(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

void _shox(FakeApi api, {Map<String, dynamic>? site}) => api
  ..on('GET', '/v1/directory/businesses/shox-barber', body: Fx.detail)
  ..on('GET', '/v1/site/shox-barber', body: site ?? Fx.siteSlot);

/// A tall phone (432x960 logical) so the tabs below the header are built.
void _tallPhone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('business page renders header, services tab and the CTA', (t) async {
    _tallPhone(t);
    await pumpBizcat(t, location: AppRoutes.business('shox-barber'), setup: _shox);

    expect(find.text('Shox Barber'), findsWidgets);
    expect(find.bySemanticsLabel('★ 4,7 (15)'), findsWidgets);
    expect(find.text('Xizmatlar'), findsOneWidget);
    expect(find.text('Soch olish + soqol'), findsOneWidget);
    expect(find.text('Navbatga yozilish'), findsOneWidget);
  });

  testWidgets('Xarita opens the business map url', (t) async {
    _tallPhone(t);
    final h = await pumpBizcat(t, location: AppRoutes.business('shox-barber'), setup: _shox);

    await t.tap(find.text('Xarita'));
    await settle(t);

    expect(h.opener.last, Uri.parse('https://yandex.uz/maps/-/CDabc'));
  });

  testWidgets('a catalog storefront shows the order CTA', (t) async {
    _tallPhone(t);
    await pumpBizcat(
      t,
      location: AppRoutes.business('aziza-tortlari'),
      setup: (api) => api
        ..on('GET', '/v1/directory/businesses/aziza-tortlari', body: Fx.detail)
        ..on('GET', '/v1/site/aziza-tortlari', body: Fx.siteCatalog),
    );

    expect(find.text('Buyurtma berish'), findsOneWidget);
    expect(find.text('Napoleon torti (1 kg)'), findsOneWidget);
  });

  testWidgets('online booking off shows the closed note and a call button', (t) async {
    final site = _copy(Fx.siteSlot);
    (site['data'] as Map)['business']['online_booking_enabled'] = false;
    await pumpBizcat(
      t,
      location: AppRoutes.business('shox-barber'),
      setup: (api) => _shox(api, site: site),
    );

    expect(find.text('Onlayn yozilish vaqtincha yopiq'), findsOneWidget);
    expect(find.text("Qo'ng'iroq qilish"), findsOneWidget);
    expect(find.text('Navbatga yozilish'), findsNothing);
  });

  testWidgets('a missing business shows the not-found state', (t) async {
    await pumpBizcat(
      t,
      location: AppRoutes.business('yoq'),
      setup: (api) => api.on('GET', '/v1/directory/businesses/yoq', status: 404, body: Fx.error(404, 'Topilmadi.')),
    );

    expect(find.text('Biznes topilmadi'), findsOneWidget);
    expect(find.text('Katalogga qaytish'), findsOneWidget);
  });

  testWidgets('reviews screen lists reviews and filters by rating', (t) async {
    final h = await pumpBizcat(
      t,
      location: AppRoutes.businessReviews('shox-barber'),
      setup: (api) => api.on('GET', '/v1/directory/businesses/shox-barber/reviews', body: Fx.reviews),
    );

    expect(find.text('Sharhlar'), findsOneWidget);
    expect(find.text("Usta juda e'tiborli, soch ajoyib chiqdi!"), findsOneWidget);
    expect(h.api.last('GET', '/v1/directory/businesses/shox-barber/reviews').query.containsKey('rating'), isFalse);

    await t.tap(find.text('5★'));
    await settle(t);

    final q = h.api.last('GET', '/v1/directory/businesses/shox-barber/reviews').query;
    expect(q['rating'], '5');
    expect(q['per_page'], '20');
  });

  testWidgets('reviews screen: an empty filter shows its empty copy', (t) async {
    await pumpBizcat(
      t,
      location: AppRoutes.businessReviews('shox-barber'),
      setup: (api) => api
        ..on('GET', '/v1/directory/businesses/shox-barber/reviews', body: Fx.reviews, when: (q) => q['rating'] == null)
        ..on(
          'GET',
          '/v1/directory/businesses/shox-barber/reviews',
          body: Fx.emptyPage,
          when: (q) => q['rating'] == '1',
        ),
    );

    await t.tap(find.text('1★'));
    await settle(t);

    expect(find.text("Bu baho bilan sharhlar yo'q."), findsOneWidget);
  });

  testWidgets('rating badge switches to the reviews tab', (t) async {
    // The larger type pushes the first review below a phone-height fold.
    t.view.physicalSize = const Size(1080, 3400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await pumpBizcat(t, location: AppRoutes.business('shox-barber'), setup: _shox);

    await t.tap(find.bySemanticsLabel('★ 4,7 (15)').first);
    await settle(t);

    expect(find.byType(RatingSummaryView), findsOneWidget);
    expect(find.text("Usta juda e'tiborli, soch ajoyib chiqdi!"), findsOneWidget);
  });

  testWidgets('an unclaimed listing shows the note and no booking CTA; branches are listed', (t) async {
    t.view.physicalSize = const Size(1080, 4000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final detail = _copy(Fx.detail);
    final business = (detail['data'] as Map<String, dynamic>)['business'] as Map<String, dynamic>;
    business['is_claimed'] = false;
    business['online_booking_enabled'] = false;
    business['branches'] = [
      {'id': 1, 'name': 'Shox Markaz', 'address': "At-Termiziy 18", 'lat': 37.24, 'lng': 67.28},
      {'id': 2, 'name': 'Shox Yangi', 'address': 'Navoiy 34', 'lat': 37.23, 'lng': 67.28},
    ];
    final site = _copy(Fx.siteSlot);
    ((site['data'] as Map<String, dynamic>)['business'] as Map<String, dynamic>)['online_booking_enabled'] = false;
    await pumpBizcat(
      t,
      location: AppRoutes.business('shox-barber'),
      setup: (api) => api
        ..on('GET', '/v1/directory/businesses/shox-barber', body: detail)
        ..on('GET', '/v1/site/shox-barber', body: site),
    );
    expect(find.byKey(const Key('business-unclaimed')), findsOneWidget);
    expect(find.text('Bu biznes hali onlayn bron qabul qilmaydi'), findsOneWidget);
    expect(find.text('2 ta filial'), findsOneWidget);

    await t.tap(find.byKey(const Key('business-branches-chip')));
    await settle(t);
    expect(find.text('Filiallar (2)'), findsOneWidget);
    expect(find.text('Shox Yangi'), findsOneWidget);
  });
}
