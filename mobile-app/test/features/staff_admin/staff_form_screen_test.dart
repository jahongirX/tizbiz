import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('create posts the exact body and opens the hours tab', (tester) async {
    final http = FakeHttp()
      ..on('POST', Endpoints.staff, status: 201, body: envelope(jStaff(id: 9, name: 'Ali', specialization: null, userId: null)))
      ..on('GET', Endpoints.staff, body: envelope([jStaff(id: 9, name: 'Ali', specialization: null, userId: null)]))
      ..on('GET', Endpoints.workingHours(9), body: envelope(<Object>[]))
      ..on('GET', Endpoints.timeOff(9), body: envelope(<Object>[]));
    await pumpRouterAt(tester, Routes.staffNew, http: http);
    expect(find.text('Yangi xodim'), findsOneWidget);

    await tester.tap(find.text("Qo'shish").last);
    await tester.pump();
    expect(find.text('Ismni kiriting'), findsOneWidget);
    expect(http.calls(Endpoints.staff, method: 'POST'), isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, 'Ism'), 'Ali');
    await tester.enterText(find.widgetWithText(TextFormField, 'Komissiya %'), '35');
    await tester.tap(find.text("Qo'shish").last);
    await settleRoutes(tester);

    expect(http.calls(Endpoints.staff, method: 'POST').single.body,
        {'name': 'Ali', 'specialization': null, 'is_active': true, 'commission_percent': 35});
    expect(currentLocation(), Routes.staffDetail(9, tab: 1));
    expect(find.text('Dushanba'), findsOneWidget);
  });

  testWidgets('422 field error is shown on the field', (tester) async {
    final http = FakeHttp()
      ..on('POST', Endpoints.staff, status: 422, body: apiError(422, 'Ism juda uzun', pointer: 'name'));
    await pumpRouterAt(tester, Routes.staffNew, http: http);
    await tester.enterText(find.widgetWithText(TextFormField, 'Ism'), 'Ali');
    await tester.tap(find.text("Qo'shish").last);
    await settleRoutes(tester);
    expect(find.text('Ism juda uzun'), findsOneWidget);
  });
}
