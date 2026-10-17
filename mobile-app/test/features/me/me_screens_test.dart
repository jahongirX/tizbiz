import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/me/my_schedule_screen.dart';
import 'package:tizbiz_biznes/features/me/my_stats_screen.dart';
import 'package:tizbiz_biznes/features/me/profile_screen.dart';
import 'package:tizbiz_biznes/features/me/widgets/earnings_chart.dart';
import 'package:tizbiz_biznes/features/me/widgets/week_hours_table.dart';
import 'package:tizbiz_biznes/shared/widgets/staff_not_linked_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  test('weekday intervals join and sort; missing day is null', () {
    final hours = [
      fxWorkingHours(id: 2, weekday: 1, start: '14:00:00', end: '20:00:00'),
      fxWorkingHours(id: 1, weekday: 1, start: '09:00:00', end: '13:00:00'),
    ];
    expect(weekdayIntervals(hours, 1), '09:00 – 13:00, 14:00 – 20:00');
    expect(weekdayIntervals(hours, 7), isNull);
    expect(isSeriesEmpty(const []), isTrue);
  });

  testWidgets('stats: KPIs from the fixture, month range query', (t) async {
    final http = FakeHttp()..on('GET', Endpoints.meStats, body: envelope(jMeStats()));
    await pumpScreen(t, const MyStatsScreen(), role: BizRole.staff, staffId: 2, http: http);
    await _settle(t);
    expect(find.text('52'), findsWidgets);
    expect(find.text(Money.format(416000000)), findsOneWidget);
    expect(find.text(Money.format(166400000)), findsOneWidget);
    expect(find.text('komissiya 40%'), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    expect(http.requests.single.query, {'from': '2026-10-01', 'to': '2026-10-17'});
  });

  testWidgets('stats: not linked makes no request', (t) async {
    await pumpScreen(t, const MyStatsScreen(), role: BizRole.staff);
    await _settle(t);
    expect(find.byType(StaffNotLinkedView), findsOneWidget);
    expect(lastFakeHttp.requests, isEmpty);
  });

  testWidgets('stats: offline', (t) async {
    await pumpScreen(t, const MyStatsScreen(),
        role: BizRole.staff, staffId: 2, http: FakeHttp()..onNetworkError('GET', Endpoints.meStats));
    await _settle(t);
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });

  testWidgets('schedule: Dam olish kuni for a missing weekday, weekday 7 is Yakshanba', (t) async {
    final http = FakeHttp()..on('GET', Endpoints.meSchedule, body: envelope(jMeSchedule()));
    await pumpScreen(t, const MyScheduleScreen(), role: BizRole.staff, staffId: 2, http: http);
    await _settle(t);
    expect(find.text('Dushanba'), findsOneWidget);
    expect(find.text('09:00 – 20:00'), findsOneWidget);
    expect(find.text('Yakshanba'), findsOneWidget);
    expect(find.text('Dam olish kuni'), findsNWidgets(6));
    expect(http.requests.single.query, {'from': '2026-10-17', 'to': '2026-12-16'});
    await t.scrollUntilVisible(find.text("Kun bo'yi"), 200,
        scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
    expect(find.text('Dam olish'), findsOneWidget);
  });

  testWidgets('profile: staff card and logout calls the session', (t) async {
    final http = FakeHttp()..on('GET', Endpoints.meStaff, body: envelope(jMeStaff()));
    final s = await pumpScreen(t, const ProfileScreen(), role: BizRole.staff, staffId: 2, http: http);
    await _settle(t);
    expect(find.text('Sartarosh'), findsOneWidget);
    expect(find.text('Komissiya 40%'), findsOneWidget);
    final logout = find.widgetWithText(OutlinedButton, 'Chiqish');
    await t.scrollUntilVisible(logout, 200,
        scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
    await t.ensureVisible(logout);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(logout);
    await _settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Chiqish'));
    await _settle(t);
    expect(s.logoutCount, 1);
  });
}
