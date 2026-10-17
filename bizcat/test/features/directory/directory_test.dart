import 'package:bizcat/core/prefs.dart';
import 'package:bizcat/shared/widgets/business_cards.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';
import '../../support/pump.dart';

const _path = '/v1/directory/businesses';

void main() {
  testWidgets('renders the fixture cards and the count', (t) async {
    t.view.physicalSize = const Size(400, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpBizcat(t, location: '/explore');
    expect(find.byType(BusinessCardTile), findsNWidgets(2));
    expect(find.text('2 ta biznes'), findsOneWidget);
  });

  testWidgets('category chip and sort sheet change the request', (t) async {
    final h = await pumpBizcat(t, location: '/explore');
    final chip = find.widgetWithText(ChoiceChip, 'Klinika');
    await t.ensureVisible(chip);
    await t.pump();
    await t.tap(chip);
    await settle(t);
    expect(h.api.last('GET', _path).query['category'], 'clinic');

    await t.ensureVisible(find.byKey(const ValueKey('dir-sort')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('dir-sort')));
    await settle(t);
    await t.tap(find.text("Reyting bo'yicha"));
    await settle(t);
    final q = h.api.last('GET', _path).query;
    expect(q['sort'], 'rating');
    expect(q['category'], 'clinic');
  });

  testWidgets('route params seed the filter; typing is debounced', (t) async {
    final h = await pumpBizcat(t, location: '/explore?category=barber&sort=name');
    var q = h.api.last('GET', _path).query;
    expect(q['category'], 'barber');
    expect(q['sort'], 'name');

    await t.enterText(find.byKey(const Key('directory-search')), 'S');
    await t.pump(const Duration(milliseconds: 400));
    expect(h.api.last('GET', _path).query.containsKey('q'), isFalse);

    await t.enterText(find.byKey(const Key('directory-search')), 'Shox');
    await t.pump(const Duration(milliseconds: 100));
    expect(h.api.last('GET', _path).query.containsKey('q'), isFalse);
    await t.pump(const Duration(milliseconds: 300));
    await settle(t);
    q = h.api.last('GET', _path).query;
    expect(q['q'], 'Shox');

    await t.testTextInput.receiveAction(TextInputAction.search);
    await settle(t);
    expect(h.container.read(appPrefsProvider).recentSearches, ['Shox']);
  });

  testWidgets('an empty response shows the empty state; reset clears filters', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/explore?category=clinic',
      prefs: {AppPrefs.kCity: 'Termiz'},
      setup: (api) => api.on('GET', _path, body: Fx.emptyPage),
    );
    expect(find.text('Hech narsa topilmadi'), findsOneWidget);
    expect(find.text('Barcha shaharlarda'), findsOneWidget);
    await t.tap(find.text('Filtrlarni tozalash'));
    await settle(t);
    final q = h.api.last('GET', _path).query;
    expect(q.containsKey('category'), isFalse);
    expect(q['city'], 'Termiz');
  });

  testWidgets('scrolling to the end loads page 2', (t) async {
    final cards = Fx.items(Fx.cards);
    final h = await pumpBizcat(
      t,
      location: '/explore',
      setup: (api) => api
        ..on('GET', _path, body: Fx.page(cards, total: 4, pages: 2))
        ..on('GET', _path, body: Fx.page(cards, page: 2, total: 4, pages: 2), when: (q) => q['page'] == '2'),
    );
    await t.drag(find.byKey(const Key('directory-list')), const Offset(0, -2000));
    await settle(t);
    expect(h.api.all('GET', _path).any((r) => r.query['page'] == '2'), isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
