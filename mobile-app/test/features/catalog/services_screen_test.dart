import 'package:flutter_test/flutter_test.dart';
import 'package:tizbiz_biznes/features/catalog/services_screen.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

void main() {
  test('groupServices: category order, Kategoriyasiz last, inactive hidden', () {
    final sections = groupServices(
      [
        fxService(),
        fxService(id: 12, name: 'Manikyur', categoryId: null),
        fxService(id: 13, name: 'Eski', isActive: false),
        fxService(id: 14, name: 'Yetim', categoryId: 99),
        fxService(id: 15, name: 'Massaj', categoryId: 6),
      ],
      [fxCategory(id: 6, name: 'Spa', sort: 0), fxCategory(), fxCategory(id: 7, name: "Bo'sh", sort: 3)],
    );
    expect([for (final s in sections) s.title], ['Spa', 'Soch', 'Kategoriyasiz']);
    expect([for (final s in sections.last.items) s.id], [12, 14]);
    expect(groupServices([fxService(id: 13, isActive: false)], const [], showInactive: true).single.items.single.id, 13);
  });

  testWidgets('grouped sections render', (tester) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.services,
          body: envelope([jService(), jService(id: 12, name: 'Manikyur', categoryId: null, onlineBookable: false, depositTiyin: null)]))
      ..on('GET', Endpoints.serviceCategories, body: envelope([jCategory()]));
    await pumpScreen(tester, const ServicesScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Xizmatlar'), findsOneWidget);
    expect(find.text('Soch · 1'), findsOneWidget);
    expect(find.text('Kategoriyasiz · 1'), findsOneWidget);
    expect(find.text('Soch olish + soqol'), findsOneWidget);
    expect(find.text('Faqat admin'), findsOneWidget);
    expect(find.textContaining('Depozit'), findsOneWidget);
  });

  testWidgets('empty list', (tester) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.services, body: envelope(<Object>[]))
      ..on('GET', Endpoints.serviceCategories, body: envelope(<Object>[]));
    await pumpScreen(tester, const ServicesScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Hali xizmatlar yo'q"), findsOneWidget);
  });

  testWidgets('offline', (tester) async {
    final http = FakeHttp()
      ..onNetworkError('GET', Endpoints.services)
      ..on('GET', Endpoints.serviceCategories, body: envelope(<Object>[]));
    await pumpScreen(tester, const ServicesScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });
}
