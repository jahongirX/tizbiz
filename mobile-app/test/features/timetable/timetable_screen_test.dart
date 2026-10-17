import 'package:flutter_test/flutter_test.dart';
import 'package:tizbiz_biznes/features/timetable/timetable_screen.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  FakeHttp withStaff() => FakeHttp()
    ..on('GET', Endpoints.staff, body: envelope([jStaff(), jStaff(id: 3, name: 'Usta Bobur', specialization: 'Barber')]))
    ..on('GET', Endpoints.workingHours(2), body: envelope([jWorkingHours(weekday: 6)]))
    ..on('GET', Endpoints.workingHours(3), body: envelope(<Object>[]))
    ..on('GET', Endpoints.timeOff(2), body: envelope(<Object>[]))
    ..on('GET', Endpoints.timeOff(3), body: envelope([jTimeOff(id: 9, staffId: 3, date: '2026-10-17', reason: 'Kasal')]));

  testWidgets('two staff columns render names and a block', (tester) async {
    final http = withStaff()
      ..on('GET', Endpoints.appointments,
          body: envelope([jAppointment(startsAt: '2026-10-17 04:00:00', endsAt: '2026-10-17 04:40:00', serviceName: 'Soch olish')]));
    await pumpScreen(tester, const TimetableScreen(), http: http);
    await settle(tester);

    expect(find.text('Jadval'), findsOneWidget);
    expect(find.text('Usta Jahongir'), findsNWidgets(2)); // chip + header
    expect(find.text('Usta Bobur'), findsNWidgets(2));
    expect(find.text('09:00 Soch olish'), findsOneWidget);
    expect(find.text('Kasal'), findsOneWidget);
    final q = http.calls(Endpoints.appointments).single.query;
    expect(q['from'], '2026-10-16 19:00:00');
    expect(q['to'], '2026-10-17 18:59:59');
  });

  testWidgets('no appointments still shows the grid with a hint', (tester) async {
    final http = withStaff()..on('GET', Endpoints.appointments, body: envelope(<Object>[]));
    await pumpScreen(tester, const TimetableScreen(), http: http);
    await settle(tester);
    expect(find.text("Bu kunda yozuvlar yo'q"), findsOneWidget);
    expect(find.text('Yangi yozuv'), findsOneWidget);
  });

  testWidgets('no active staff shows the empty view', (tester) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.staff, body: envelope([jStaff(isActive: false)]))
      ..on('GET', Endpoints.appointments, body: envelope(<Object>[]));
    await pumpScreen(tester, const TimetableScreen(), http: http);
    await settle(tester);
    expect(find.text("Hali xodim qo'shilmagan"), findsOneWidget);
    expect(find.text("Xodim qo'shish"), findsOneWidget);
  });

  testWidgets('offline shows the network error', (tester) async {
    final http = FakeHttp()..onNetworkError('GET', Endpoints.staff);
    await pumpScreen(tester, const TimetableScreen(), http: http);
    await settle(tester);
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });
}
