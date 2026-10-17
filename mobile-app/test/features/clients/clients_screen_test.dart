import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/clients/clients_screen.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

void main() {
  Map<String, Object?> page(List<Map<String, dynamic>> rows, int page, int pages, int total) =>
      envelope(rows, meta: {'page': page, 'per_page': 20, 'total': total, 'pages': pages});

  testWidgets('renders the first page and loads more on scroll', (t) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.clients, body: page([jClient(), jClient(id: 882, name: 'Bobur Aliyev')], 1, 2, 3))
      ..on('GET', Endpoints.clients, body: page([jClient(id: 883, name: 'Dilnoza Rahimova')], 2, 2, 3));
    await pumpScreen(t, const ClientsScreen(), http: http);
    await _settle(t);
    expect(find.text('3 ta mijoz'), findsOneWidget);
    expect(find.text('Aziza Karimova'), findsOneWidget);
    expect(find.text(Phone.format('+998900000001')), findsWidgets);
    expect(find.text('5 tashrif · ${Money.compact(40000000)}'), findsWidgets);
    expect(find.text('VIP'), findsWidgets);
    expect(find.text('Dilnoza Rahimova'), findsNothing);

    await t.drag(find.byType(ListView), const Offset(0, -300));
    await _settle(t);
    expect(find.text('Dilnoza Rahimova'), findsOneWidget);
    final calls = http.calls(Endpoints.clients);
    expect(calls.first.query, {'page': '1', 'per_page': '20'});
    expect(calls.last.query, {'page': '2', 'per_page': '20'});
  });

  testWidgets('segment chip sends segment; empty filtered result', (t) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.clients, body: page([jClient()], 1, 1, 1))
      ..on('GET', Endpoints.clients, body: page([], 1, 0, 0));
    await pumpScreen(t, const ClientsScreen(), http: http);
    await _settle(t);
    await t.tap(find.text("Yo'qolgan"));
    await _settle(t);
    expect(http.calls(Endpoints.clients).last.query['segment'], 'lost');
    expect(find.text('Mijozlar topilmadi'), findsOneWidget);
  });

  testWidgets('no clients shows the empty view', (t) async {
    await pumpScreen(t, const ClientsScreen(), http: FakeHttp()..on('GET', Endpoints.clients, body: page([], 1, 0, 0)));
    await _settle(t);
    expect(find.text("Hali mijozlar yo'q"), findsOneWidget);
  });

  testWidgets('offline shows the offline error', (t) async {
    await pumpScreen(t, const ClientsScreen(), http: FakeHttp()..onNetworkError('GET', Endpoints.clients));
    await _settle(t);
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
}
