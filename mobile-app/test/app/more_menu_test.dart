import 'package:flutter_test/flutter_test.dart';
import 'package:tizbiz_biznes/app/more/more_menu_screen.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/test_app.dart';

List<String> _rows(ActiveBusiness a) => [for (final e in moreMenuEntries(a)) e.label];

ActiveBusiness _a({Engine engine = Engine.slot, BizRole role = BizRole.owner, int? staffId, List<String>? permissions}) =>
    ActiveBusiness.fromSession(fxAuthSession(engine: engine, role: role, staffId: staffId, permissions: permissions))!;

void main() {
  test('slot owner rows', () {
    expect(_rows(_a()), [
      'Xizmatlar',
      'Ustalar',
      'Moliya',
      'Ish haqi',
      'Sharhlar',
      'Onlayn-yozuv sozlamalari',
      'Jamoa',
    ]);
  });

  test('owner with a staff profile gets "Mening navbatlarim" first', () {
    final rows = moreMenuEntries(_a(staffId: 2));
    expect(rows.first.label, 'Mening navbatlarim');
    expect(rows.first.location, '/o/appointments?staff=2');
  });

  test('catalog: Menyu / Xodimlar, no Ish haqi', () {
    final rows = _rows(_a(engine: Engine.catalog));
    expect(rows, containsAllInOrder(['Menyu', 'Xodimlar', 'Moliya']));
    expect(rows, isNot(contains('Ish haqi')));
  });

  test('medical: Mijozlar in the menu, Shifokorlar', () {
    final rows = _rows(_a(engine: Engine.medical));
    expect(rows.first, 'Mijozlar');
    expect(rows, contains('Shifokorlar'));
  });

  test('rental: Buyumlar', () {
    expect(_rows(_a(engine: Engine.rental)).first, 'Buyumlar');
  });

  test('rows follow permissions', () {
    final rows = _rows(_a(role: BizRole.admin, permissions: const [Permissions.reviews, Permissions.teamRead]));
    expect(rows, ['Sharhlar', 'Jamoa']);
  });

  testWidgets('header, theme selector and logout', (tester) async {
    final session = await pumpScreen(
      tester,
      const MoreMenuScreen(),
      session: fxSignedIn(businesses: [
        fxMembership(),
        fxMembership(engine: Engine.catalog),
      ]),
    );
    expect(find.text('Shox Barber'), findsOneWidget);
    expect(find.text('Barber · Egasi'), findsOneWidget);
    expect(find.text('Biznesni almashtirish'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tizim'), 200);
    expect(find.text('Tizim'), findsOneWidget);
    expect(find.text("Yorug'"), findsOneWidget);
    expect(find.text("Qorong'i"), findsOneWidget);

    await tester.scrollUntilVisible(find.text('+998 90 111 11 11'), 200);
    expect(find.text('+998 90 111 11 11'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Chiqish'), -100);
    await tester.tap(find.text('Chiqish'));
    await tester.pumpAndSettle();
    expect(find.text('Hisobdan chiqasizmi?'), findsOneWidget);
    await tester.tap(find.text('Chiqish').last);
    await tester.pumpAndSettle();
    expect(session.logoutCount, 1);
  });

  testWidgets('single business: no switch button', (tester) async {
    await pumpScreen(tester, const MoreMenuScreen());
    expect(find.text('Biznesni almashtirish'), findsNothing);
  });
}
