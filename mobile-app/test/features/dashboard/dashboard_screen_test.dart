import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/dashboard/dashboard_screen.dart';
import 'package:tizbiz_biznes/features/dashboard/providers.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

final _mainList = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;

void main() {
  testWidgets('slot: today card, KPIs and charts from fixture analytics', (tester) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.analyticsOverview, body: envelope(jAnalytics()))
      ..on('GET', Endpoints.appointments, body: envelope([
        jAppointment(),
        jAppointment(id: 5013, startsAt: '2026-10-17 08:00:00', endsAt: '2026-10-17 08:40:00', clientName: 'Bobur Aliyev'),
      ]));
    await pumpScreen(tester, const DashboardScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Shox Barber'), findsOneWidget);
    expect(find.text('Bugun'), findsWidgets);
    expect(find.text('Kutilayotgan'), findsOneWidget);
    expect(find.text('Bobur Aliyev'), findsOneWidget);
    expect(find.text('Aziza Karimova'), findsNothing); // ended at 10:40, not "next"
    expect(find.text('Daromad'), findsOneWidget);
    expect(find.text(Money.compact(48000000)), findsOneWidget);
    expect(find.text('0.0%'), findsOneWidget);
    expect(find.text('jami 120'), findsOneWidget);

    final analytics = http.calls(Endpoints.analyticsOverview).single;
    expect(analytics.query, {'from': '2026-10-11', 'to': '2026-10-17'});
    expect(http.calls(Endpoints.orders), isEmpty);

    await tester.scrollUntilVisible(find.byType(LineChart), 200, scrollable: _mainList);
    expect(find.byType(LineChart), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Xodimlar yuki'), 200, scrollable: _mainList);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Top xizmatlar'), findsOneWidget);
  });

  testWidgets('catalog: orders section, no analytics', (tester) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.orders, body: envelope([
        jOrder(),
        jOrder(id: 691, status: OrderStatus.cancelled, totalTiyin: 1000000),
      ]));
    await pumpScreen(tester, const DashboardScreen(), engine: Engine.catalog, http: http);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Buyurtmalar'), findsWidgets);
    expect(find.text('Buyurtmalar taxtasi'), findsOneWidget);
    expect(find.text('Bekor qilingan'), findsOneWidget);
    expect(find.text(Money.compact(22500000)), findsOneWidget);
    expect(find.text('Daromad'), findsNothing);
    expect(find.text('Kutilayotgan'), findsNothing);
    expect(http.calls(Endpoints.analyticsOverview), isEmpty);
    expect(http.calls(Endpoints.appointments), isEmpty);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('empty analytics shows the empty text', (tester) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.analyticsOverview, body: envelope(const AnalyticsOverview().toJson()))
      ..on('GET', Endpoints.appointments, body: envelope(<Object>[]));
    await pumpScreen(tester, const DashboardScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Bugun yozuvlar yo'q"), findsOneWidget);
    expect(find.text("Bu davrda ma'lumot yo'q"), findsOneWidget);
  });

  testWidgets('network error shows the offline view', (tester) async {
    final http = FakeHttp()..offline = true;
    await pumpScreen(tester, const DashboardScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Internet aloqasi yo'q"), findsWidgets);
  });

  test('OrdersSummary sums non-cancelled orders per local day', () {
    final orders = [
      Order.fromJson(jOrder(createdAt: 1792054800)), // 2026-10-15 09:00 UTC
      Order.fromJson(jOrder(id: 2, totalTiyin: 500000, createdAt: 1792054800 + 86400)),
      Order.fromJson(jOrder(id: 3, status: OrderStatus.cancelled, totalTiyin: 999, createdAt: 1792054800)),
    ];
    final s = OrdersSummary.from(orders,
        from: const LocalDate(2026, 10, 14), to: const LocalDate(2026, 10, 17), timezone: 'Asia/Tashkent');
    expect(s.count, 3);
    expect(s.totalTiyin, 22500000 + 500000);
    expect(s.countOf(OrderStatus.cancelled), 1);
    expect(s.countOf(OrderStatus.newOrder), 2);
    expect(s.daily.length, 4);
    expect(s.daily.map((d) => d.totalTiyin).toList(), [0, 22500000, 500000, 0]);
  });
}
