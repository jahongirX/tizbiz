import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/money/finance_screen.dart';
import 'package:tizbiz_biznes/features/money/widgets/transaction_tile.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

Map<String, Object?> _meta({int page = 1, int pages = 1, int total = 1}) =>
    {'page': page, 'per_page': 20, 'total': total, 'pages': pages};

void main() {
  testWidgets('renders KPIs, providers and a paged list; loads page 2', (tester) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.financeSummary, body: envelope(jFinanceSummary()))
      ..on('GET', Endpoints.financeTransactions, body: envelope([jTransaction()], meta: _meta(pages: 2, total: 2)))
      ..on('GET', Endpoints.financeTransactions,
          body: envelope([jTransaction(id: 302)..['client_name'] = 'Bobur Aliyev'], meta: _meta(page: 2, pages: 2, total: 2)));
    await pumpScreen(tester, const FinanceScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Kirim'), findsOneWidget);
    expect(find.text('Qaytarishlar'), findsOneWidget);
    expect(find.text('Tranzaksiyalar'), findsOneWidget);
    expect(find.text('Payme'), findsOneWidget);
    expect(find.text('Aziza Karimova'), findsOneWidget);
    expect(find.textContaining('Depozit'), findsOneWidget);
    expect(find.text("To'langan"), findsOneWidget);

    final first = http.calls(Endpoints.financeTransactions).first;
    expect(first.query, {'from': '2026-09-18', 'to': '2026-10-17', 'page': '1', 'per_page': '20'});
    expect(http.calls(Endpoints.financeSummary).single.query, {'from': '2026-09-18', 'to': '2026-10-17'});

    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(http.calls(Endpoints.financeTransactions).last.query['page'], '2');
    expect(find.text('Bobur Aliyev'), findsOneWidget);
    expect(find.byType(TransactionTile), findsNWidgets(2));
  });

  testWidgets('empty period shows the empty text', (tester) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.financeSummary, body: envelope(const FinanceSummary().toJson()))
      ..on('GET', Endpoints.financeTransactions, body: envelope(<Object>[], meta: _meta(total: 0, pages: 0)));
    await pumpScreen(tester, const FinanceScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Bu davrda to'lovlar yo'q"), findsOneWidget);
  });

  testWidgets('offline shows the offline view', (tester) async {
    await pumpScreen(tester, const FinanceScreen(), http: FakeHttp()..offline = true);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });

  test('refund amounts are negative', () {
    expect(transactionAmount(const FinanceTransaction(id: 1, type: 'refund', amountTiyin: 2000000)),
        startsWith('−'));
    expect(transactionAmount(const FinanceTransaction(id: 1, type: 'deposit', amountTiyin: 2000000)),
        Money.format(2000000));
  });
}
