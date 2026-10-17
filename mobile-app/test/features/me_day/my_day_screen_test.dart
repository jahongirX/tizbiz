import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/me_day/actions.dart';
import 'package:tizbiz_biznes/features/me_day/my_appointment_detail_screen.dart';
import 'package:tizbiz_biznes/features/me_day/my_day_screen.dart';
import 'package:tizbiz_biznes/features/me_day/not_linked.dart';
import 'package:tizbiz_biznes/features/me_day/providers.dart';
import 'package:tizbiz_biznes/shared/widgets/staff_not_linked_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

class _FakeActions implements MyAppointmentActions {
  final calls = <(int, AppointmentStatus)>[];
  Object? error;

  @override
  Future<Appointment> setStatus(int id, AppointmentStatus next) async {
    calls.add((id, next));
    if (error != null) throw error!;
    return fxAppointment(id: id, status: next);
  }
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

FakeHttp _http({List<Map<String, dynamic>>? items}) => FakeHttp()
  ..on('GET', Endpoints.meAppointments, body: envelope(items ?? [jAppointment()]))
  ..on('GET', Endpoints.meStats, body: envelope(jMeStats()));

void main() {
  test('week range is today..today+6', () {
    const today = LocalDate(2026, 10, 17);
    expect(myDayRangeFor(MyDayView.week, today), (from: today, to: const LocalDate(2026, 10, 23)));
    expect(myDayRangeFor(MyDayView.tomorrow, today).from, const LocalDate(2026, 10, 18));
  });

  testWidgets('not-linked staff renders StaffNotLinkedView and makes no request', (t) async {
    await pumpScreen(t, const MyDayScreen(), role: BizRole.staff);
    await _settle(t);
    expect(find.byType(StaffNotLinkedView), findsOneWidget);
    expect(lastFakeHttp.requests, isEmpty);
  });

  testWidgets('confirmed card shows the staff actions and never a cancel button', (t) async {
    final http = _http();
    await pumpScreen(t, const MyDayScreen(), role: BizRole.staff, staffId: 2, http: http);
    await _settle(t);
    expect(find.text('Aziza Karimova'), findsOneWidget);
    expect(find.text('10:00 – 10:40'), findsOneWidget);
    expect(find.text('6 ta'), findsOneWidget);
    expect(find.text('Keyingi: 14:30'), findsOneWidget);
    expect(find.text('Keldi'), findsWidgets);
    expect(find.text('Yakunlash'), findsOneWidget);
    expect(find.text('Kelmadi'), findsOneWidget);
    expect(find.text('Bekor qilish'), findsNothing);
    final q = http.requests.firstWhere((r) => r.path == Endpoints.meAppointments).query;
    expect(q, {'from': '2026-10-17', 'to': '2026-10-17'});
  });

  testWidgets('tapping Keldi calls setStatus(id, arrived)', (t) async {
    final fake = _FakeActions();
    await pumpScreen(t, const MyDayScreen(),
        role: BizRole.staff, staffId: 2, http: _http(), overrides: [myAppointmentActionsProvider.overrideWithValue(fake)]);
    await _settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Keldi'));
    await _settle(t);
    expect(fake.calls, [(5012, AppointmentStatus.arrived)]);
  });

  testWidgets('empty day', (t) async {
    await pumpScreen(t, const MyDayScreen(), role: BizRole.staff, staffId: 2, http: _http(items: const []));
    await _settle(t);
    expect(find.text("Bugun yozuvlar yo'q"), findsOneWidget);
  });

  testWidgets('offline state', (t) async {
    await pumpScreen(t, const MyDayScreen(),
        role: BizRole.staff, staffId: 2, http: FakeHttp()..onNetworkError('GET', Endpoints.meAppointments));
    await _settle(t);
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });

  testWidgets('a not-linked 404 renders StaffNotLinkedView and refreshes the session', (t) async {
    final http = FakeHttp()..on('GET', Endpoints.meAppointments, status: 404, body: apiError(404, kNotLinkedDetail));
    final s = await pumpScreen(t, const MyDayScreen(), role: BizRole.staff, staffId: 2, http: http);
    await _settle(t);
    expect(find.byType(StaffNotLinkedView), findsOneWidget);
    expect(s.forbiddenCount, greaterThanOrEqualTo(1));
  });

  testWidgets('detail shows the booking; terminal status has no buttons', (t) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.meAppointment(5012), body: envelope(jAppointment(status: AppointmentStatus.completed)));
    await pumpScreen(t, const MyAppointmentDetailScreen(appointmentId: 5012), role: BizRole.staff, staffId: 2, http: http);
    await _settle(t);
    expect(find.text('Yozuv #5012'), findsOneWidget);
    expect(find.text('Soch olish + soqol'), findsOneWidget);
    expect(find.text('Bu yozuv yakunlangan'), findsOneWidget);
    expect(find.text('Keldi'), findsNothing);
  });
}
