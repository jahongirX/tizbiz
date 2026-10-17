import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/money/payroll_screen.dart';
import 'package:tizbiz_biznes/features/money/widgets/commission_dialog.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('commission dialog rejects 101 and sends {"commission_percent": 40}', (tester) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.payroll, body: envelope(jPayroll()))
      ..on('PATCH', Endpoints.staffById(2), body: envelope(jStaff()));
    await pumpScreen(tester, const PayrollScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Usta Jahongir'), findsOneWidget);
    expect(find.text('Jami ish haqi'), findsOneWidget);
    expect(find.textContaining('6 ta yakunlangan'), findsOneWidget);
    expect(http.calls(Endpoints.payroll).single.query, {'from': '2026-10-01', 'to': '2026-10-17'});

    await tester.tap(find.text('Komissiya 40%'));
    await tester.pumpAndSettle();
    expect(find.byType(CommissionDialog), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '101');
    await tester.tap(find.text('Saqlash'));
    await tester.pump();
    expect(find.text('0 dan 100 gacha butun son kiriting'), findsOneWidget);
    expect(http.calls(Endpoints.staffById(2)), isEmpty);

    await tester.enterText(find.byType(TextFormField), '40');
    await tester.tap(find.text('Saqlash'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    final patch = http.calls(Endpoints.staffById(2), method: 'PATCH').single;
    expect(patch.body, {'commission_percent': 40});
    expect(find.byType(CommissionDialog), findsNothing);
    expect(find.text('Komissiya saqlandi'), findsOneWidget);
    expect(http.calls(Endpoints.payroll).length, 2); // staff revision bump refetches
  });

  testWidgets('422 on commission_percent shows on the field', (tester) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.payroll, body: envelope(jPayroll()))
      ..on('PATCH', Endpoints.staffById(2), status: 422, body: {
        'errors': [
          {'status': '422', 'title': 'Validation', 'detail': "Komissiya noto'g'ri.", 'source': {'pointer': 'commission_percent'}},
        ],
      });
    await pumpScreen(tester, const PayrollScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Komissiya 40%'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saqlash'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Komissiya noto'g'ri."), findsOneWidget);
    expect(find.byType(CommissionDialog), findsOneWidget);
  });

  testWidgets('no staff shows the empty text', (tester) async {
    final http = FakeHttp()..on('GET', Endpoints.payroll, body: envelope(const PayrollReport().toJson()));
    await pumpScreen(tester, const PayrollScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Faol xodimlar yo'q"), findsOneWidget);
  });

  testWidgets('offline shows the offline view', (tester) async {
    await pumpScreen(tester, const PayrollScreen(), http: FakeHttp()..offline = true);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });

  test('validateCommission', () {
    expect(validateCommission(''), isNotNull);
    expect(validateCommission('101'), isNotNull);
    expect(validateCommission('0'), isNull);
    expect(validateCommission('100'), isNull);
  });
}
