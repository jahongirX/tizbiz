import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

FakeHttp _http() => FakeHttp()
  ..on('GET', Endpoints.services, body: envelope([jService()]))
  ..on('GET', Endpoints.serviceCategories, body: envelope([jCategory()]));

final _list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;

void main() {
  testWidgets('create sends price_tiyin 15000000 for "150 000"', (tester) async {
    final http = _http()..on('POST', Endpoints.services, status: 201, body: envelope(jService(id: 40, name: 'Ukladka')));
    await pumpRouterAt(tester, Routes.serviceNew, http: http);
    expect(find.text('Yangi xizmat'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nomi'), 'Ukladka');
    await tester.enterText(find.widgetWithText(TextFormField, 'Narxi'), '150000');
    await tester.pump();
    final price = tester.widget<EditableText>(
        find.descendant(of: find.widgetWithText(TextFormField, 'Narxi'), matching: find.byType(EditableText)));
    expect(price.controller.text, Money.group(150000));
    await tester.scrollUntilVisible(find.widgetWithText(FilledButton, "Qo'shish"), 200, scrollable: _list);
    await tester.tap(find.widgetWithText(FilledButton, "Qo'shish"));
    await settleRoutes(tester);

    expect(http.calls(Endpoints.services, method: 'POST').single.body, {
      'name': 'Ukladka',
      'category_id': null,
      'duration_min': 30,
      'price_tiyin': 15000000,
      'deposit_tiyin': null,
      'is_active': true,
      'online_bookable': true,
      'image': null,
      'description': null,
      'gallery': <Object>[],
    });
  });

  testWidgets('required fields block the submit', (tester) async {
    final http = _http();
    await pumpRouterAt(tester, Routes.serviceNew, http: http);
    await tester.scrollUntilVisible(find.widgetWithText(FilledButton, "Qo'shish"), 200, scrollable: _list);
    await tester.tap(find.widgetWithText(FilledButton, "Qo'shish"));
    await tester.pump();
    expect(http.calls(Endpoints.services, method: 'POST'), isEmpty);
    await tester.scrollUntilVisible(find.text('Nomini kiriting'), -200, scrollable: _list);
    expect(find.text('Nomini kiriting'), findsOneWidget);
  });

  testWidgets('deactivate calls DELETE after confirm', (tester) async {
    final http = _http()..on('DELETE', Endpoints.service(11), body: envelope({'deleted': true}));
    await pumpRouterAt(tester, Routes.service(11), http: http);
    expect(find.widgetWithText(TextFormField, 'Nomi'), findsOneWidget);
    await tester.scrollUntilVisible(find.widgetWithText(OutlinedButton, 'Faolsizlantirish'), 200, scrollable: _list);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Faolsizlantirish'));
    await tester.pump();
    expect(find.text('Faolsizlantirilsinmi?'), findsOneWidget);
    expect(http.calls(Endpoints.service(11), method: 'DELETE'), isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Faolsizlantirish'));
    await settleRoutes(tester);
    expect(http.calls(Endpoints.service(11), method: 'DELETE'), hasLength(1));
  });

  testWidgets('422 pointer error lands on the field', (tester) async {
    final http = _http()
      ..on('PATCH', Endpoints.service(11), status: 422, body: apiError(422, 'Narx manfiy', pointer: 'price_tiyin'));
    await pumpRouterAt(tester, Routes.service(11), http: http);
    await tester.scrollUntilVisible(find.text('Saqlash'), 200, scrollable: _list);
    await tester.tap(find.text('Saqlash'));
    await settleRoutes(tester);
    expect(http.calls(Endpoints.service(11), method: 'PATCH'), hasLength(1));
    await tester.scrollUntilVisible(find.text('Narx manfiy'), -200, scrollable: _list);
    expect(find.text('Narx manfiy'), findsOneWidget);
  });
}
