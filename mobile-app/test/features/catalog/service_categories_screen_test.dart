import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/catalog/service_categories_screen.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

FakeHttp _http() => FakeHttp()
  ..on('GET', Endpoints.services, body: envelope([jService(), jService(id: 12)]))
  ..on('GET', Endpoints.serviceCategories, body: envelope([jCategory(), jCategory(id: 6, name: 'Spa', sort: 2)]));

void main() {
  testWidgets('renders categories with counts', (tester) async {
    await pumpScreen(tester, const ServiceCategoriesScreen(), http: _http());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Soch'), findsOneWidget);
    expect(find.text('2 ta xizmat'), findsOneWidget);
    expect(find.text('0 ta xizmat'), findsOneWidget);
  });

  testWidgets('add posts name and sort', (tester) async {
    final http = _http()..on('POST', Endpoints.serviceCategories, status: 201, body: envelope(jCategory(id: 8, name: 'Yuz', sort: 3)));
    await pumpScreen(tester, const ServiceCategoriesScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text("Qo'shish"));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.widgetWithText(TextFormField, 'Nomi'), 'Yuz');
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(http.calls(Endpoints.serviceCategories, method: 'POST').single.body, {'name': 'Yuz', 'sort': 3});
  });

  testWidgets('delete asks first', (tester) async {
    final http = _http()..on('DELETE', Endpoints.serviceCategory(6), body: envelope({'deleted': true}));
    await pumpScreen(tester, const ServiceCategoriesScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip("O'chirish").last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text("Kategoriya o'chirilsinmi? Undagi xizmatlar kategoriyasiz qoladi."), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, "O'chirish"));
    await tester.pump(const Duration(milliseconds: 300));
    expect(http.calls(Endpoints.serviceCategory(6), method: 'DELETE'), hasLength(1));
  });

  testWidgets('empty', (tester) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.serviceCategories, body: envelope(<Object>[]))
      ..on('GET', Endpoints.services, body: envelope(<Object>[]));
    await pumpScreen(tester, const ServiceCategoriesScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Hali kategoriyalar yo'q"), findsOneWidget);
  });

  testWidgets('offline', (tester) async {
    final off = FakeHttp()..onNetworkError('GET', Endpoints.serviceCategories);
    await pumpScreen(tester, const ServiceCategoriesScreen(), http: off);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });
}
