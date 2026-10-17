import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/clients/client_detail_screen.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

void main() {
  FakeHttp http0() => FakeHttp()
    ..on('GET', Endpoints.client(881), body: envelope(jClientDetail()))
    ..on(
      'GET',
      Endpoints.clientCategories,
      body: envelope([jClientCategory(), jClientCategory(id: 2, name: 'Doimiy', color: '#10B981', sort: 2)]),
    );

  void tall(WidgetTester t) {
    t.view.physicalSize = const Size(800, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('renders the card, loyalty and history', (t) async {
    tall(t);
    await pumpScreen(t, const ClientDetailScreen(clientId: 881), http: http0());
    await _settle(t);
    expect(find.text('Aziza Karimova'), findsWidgets);
    expect(find.text('Soqolni qisqa yoqtiradi'), findsOneWidget);
    expect(find.text("Tug'ilgan kun: 12 aprel 1996"), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text(Money.format(1500000)), findsOneWidget);
    expect(find.text('Soch olish + soqol'), findsOneWidget);
    expect(find.text('Yangi yozuv'), findsOneWidget);
  });

  testWidgets('toggling a category PUTs the full id list', (t) async {
    tall(t);
    final http = http0()
      ..on(
        'PUT',
        Endpoints.clientCategoriesOf(881),
        body: envelope([jClientCategory(), jClientCategory(id: 2, name: 'Doimiy', color: '#10B981', sort: 2)]),
      );
    await pumpScreen(t, const ClientDetailScreen(clientId: 881), http: http);
    await _settle(t);
    await t.tap(find.widgetWithText(FilterChip, 'Doimiy'));
    await _settle(t);
    expect(http.calls(Endpoints.clientCategoriesOf(881), method: 'PUT').single.body, {
      'category_ids': [1, 2],
    });
  });

  testWidgets('a failed category save reverts the chip', (t) async {
    tall(t);
    final http = http0()
      ..on('PUT', Endpoints.clientCategoriesOf(881), status: 422, body: apiError(422, 'Kategoriya topilmadi.'));
    await pumpScreen(t, const ClientDetailScreen(clientId: 881), http: http);
    await _settle(t);
    await t.tap(find.widgetWithText(FilterChip, 'Doimiy'));
    await _settle(t);
    expect(t.widget<FilterChip>(find.widgetWithText(FilterChip, 'Doimiy')).selected, isFalse);
    expect(find.text('Kategoriya topilmadi.'), findsOneWidget);
  });

  testWidgets('offline shows the offline error', (t) async {
    await pumpScreen(t, const ClientDetailScreen(clientId: 881), http: FakeHttp()..offline = true);
    await _settle(t);
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
}
