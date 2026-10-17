import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/staff_admin/staff_detail_screen.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

FakeHttp _http() => FakeHttp()
  ..on('GET', Endpoints.staff, body: envelope([jStaff()]))
  ..on('GET', Endpoints.workingHours(2), body: envelope([
        jWorkingHours(weekday: 1, start: '09:00:00', end: '18:00:00'),
        jWorkingHours(id: 22, weekday: 7, start: '10:00:00', end: '15:00:00'),
      ]))
  ..on('GET', Endpoints.timeOff(2), body: envelope([jTimeOff()]));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('info tab shows fields and link status', (tester) async {
    await pumpScreen(tester, const StaffDetailScreen(staffId: 2), http: _http());
    await _settle(tester);
    expect(find.text('Usta Jahongir'), findsWidgets);
    expect(find.text("Tizimga kirish hisobi: bog'langan"), findsOneWidget);
  });

  testWidgets('editor renders 7 rows from fixture hours and saves the week', (tester) async {
    final http = _http()
      ..on('PUT', Endpoints.workingHours(2), body: envelope([jWorkingHours(weekday: 1, start: '09:00:00', end: '18:00:00')]));
    await pumpScreen(tester, const StaffDetailScreen(staffId: 2, initialTab: 1), http: http);
    await _settle(tester);
    for (final d in UzDates.weekdaysLong) {
      await tester.scrollUntilVisible(find.text(d), 100, scrollable: find.byType(Scrollable).last);
      expect(find.text(d), findsOneWidget);
    }
    expect(find.text('10:00'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Saqlash'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Saqlash'));
    await _settle(tester);
    expect(http.calls(Endpoints.workingHours(2), method: 'PUT').single.body, {
      'items': [
        {'weekday': 1, 'start_time': '09:00:00', 'end_time': '18:00:00'},
        {'weekday': 7, 'start_time': '10:00:00', 'end_time': '15:00:00'},
      ],
    });
  });

  testWidgets('time-off dialog requires a date', (tester) async {
    final http = _http();
    await pumpScreen(tester, const StaffDetailScreen(staffId: 2, initialTab: 2), http: http);
    await _settle(tester);
    expect(find.text('Dam olish'), findsWidgets); // tab + reason
    expect(find.text('Yakshanba, 25 oktabr'), findsOneWidget);

    await tester.tap(find.text("Dam olish qo'shish"));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pump();
    expect(find.text('Sanani tanlang'), findsOneWidget);
    expect(http.calls(Endpoints.timeOff(2), method: 'POST'), isEmpty);
  });
}
