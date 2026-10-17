import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/orders/actions.dart';
import 'package:tizbiz_biznes/features/orders/orders_board_screen.dart';
import 'package:tizbiz_biznes/features/orders/providers.dart';
import 'package:tizbiz_biznes/features/orders/widgets/order_card.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

class FakeOrderActions implements OrderActions {
  final calls = <(int, OrderStatus)>[];
  Completer<Order>? pending;
  ApiException? error;

  @override
  Ref get ref => throw UnimplementedError();

  @override
  Future<Order> setStatus(int id, OrderStatus s) async {
    calls.add((id, s));
    final p = pending;
    if (p != null) return p.future;
    final e = error;
    if (e != null) throw e;
    return fxOrder(id: id, status: s);
  }
}

void main() {
  late FakeOrderActions actions;
  setUp(() => actions = FakeOrderActions());

  final orders = [
    fxOrder(id: 702),
    fxOrder(id: 701, customerName: 'Bobur Aliyev'),
    fxOrder(id: 690, status: OrderStatus.delivered),
  ];

  Future<void> pump(WidgetTester t, {List<Order>? list, FakeHttp? http}) async {
    await pumpScreen(
      t,
      const OrdersBoardScreen(),
      engine: Engine.catalog,
      http: http,
      overrides: [
        orderActionsProvider.overrideWithValue(actions),
        if (http == null) ordersListProvider.overrideWith((ref, r) async => list ?? orders),
      ],
    );
    await _settle(t);
  }

  Finder tab(String label) => find.descendant(of: find.byType(Tab), matching: find.text(label));
  Finder countIn(String label, String count) => find.descendant(
    of: find.ancestor(of: tab(label), matching: find.byType(Tab)),
    matching: find.text(count),
  );

  testWidgets('tabs show counts and the new tab lists its orders', (t) async {
    await pump(t);
    expect(countIn('Yangi', '2'), findsOneWidget);
    expect(countIn('Topshirildi', '1'), findsOneWidget);
    expect(countIn('Tasdiqlangan', '0'), findsOneWidget);
    expect(find.text('#702'), findsOneWidget);
    expect(find.text('Bobur Aliyev'), findsOneWidget);
    expect(find.text('#690'), findsNothing);
    expect(find.text('Jami: ${Money.format(45000000)}'), findsOneWidget);
    expect(find.text('Napoleon torti (1 kg) ×1'), findsNWidgets(2));
  });

  testWidgets('Tasdiqlash calls setStatus(confirmed) and moves the order', (t) async {
    await pump(t);
    await t.tap(find.descendant(of: find.widgetWithText(OrderCard, '#702'), matching: find.text('Tasdiqlash')));
    await _settle(t);
    expect(actions.calls, [(702, OrderStatus.confirmed)]);
    expect(find.text('#702'), findsNothing);
    expect(countIn('Yangi', '1'), findsOneWidget);
    expect(countIn('Tasdiqlangan', '1'), findsOneWidget);
    await t.tap(tab('Tasdiqlangan'));
    await t.pump(const Duration(milliseconds: 500));
    await _settle(t);
    expect(find.text('#702'), findsOneWidget);
  });

  testWidgets('a failed change reverts and shows the error', (t) async {
    actions.error = ApiException.fromResponse(403, apiError(403, "Bu amal uchun ruxsatingiz yo'q."), const {});
    await pump(t);
    await t.tap(find.descendant(of: find.widgetWithText(OrderCard, '#702'), matching: find.text('Tasdiqlash')));
    await _settle(t);
    expect(find.text('#702'), findsOneWidget);
    expect(countIn('Yangi', '2'), findsOneWidget);
    expect(find.text("Bu amal uchun ruxsatingiz yo'q."), findsOneWidget);
  });

  testWidgets('empty range shows the empty view', (t) async {
    await pump(t, list: const []);
    expect(find.text("Bu davrda buyurtmalar yo'q"), findsOneWidget);
  });

  testWidgets('offline shows the offline error; the query is unix seconds', (t) async {
    final http = FakeHttp()..onNetworkError('GET', Endpoints.orders);
    await pump(t, http: http);
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
    final q = http.calls(Endpoints.orders).first.query;
    // last7 = 11..17 Oct, Tashkent midnight in UTC.
    expect(q['from'], '${Dates.toUnix(DateTime.utc(2026, 10, 10, 19))}');
    expect(q['to'], '${Dates.toUnix(DateTime.utc(2026, 10, 17, 19))}');
  });

  test('searchOrders matches #id, name and phone digits', () {
    expect(searchOrders(orders, '#701').single.id, 701);
    expect(searchOrders(orders, 'bobur').single.id, 701);
    expect(searchOrders(orders, '900000001').length, 3);
  });
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
}
