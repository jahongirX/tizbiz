import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/appointments/appointments_screen.dart';
import 'package:tizbiz_biznes/features/appointments/providers.dart';
import 'package:tizbiz_biznes/shared/data/catalog_data.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

void main() {
  final list = [
    fxAppointment(),
    fxAppointment(
      id: 5020,
      status: AppointmentStatus.pending,
      startsAt: '2026-10-18 06:00:00',
      endsAt: '2026-10-18 06:40:00',
      clientName: 'Bobur Aliyev',
      serviceName: 'Soqol olish',
    ),
  ];

  testWidgets('renders tiles grouped by day and filters by text', (t) async {
    await pumpScreen(
      t,
      const AppointmentsScreen(),
      overrides: [
        appointmentsListProvider.overrideWith((ref, q) async => list),
        activeStaffProvider.overrideWithValue(AsyncData([fxStaff()])),
      ],
    );
    await _settle(t);
    expect(find.text('Navbatlar'), findsOneWidget);
    expect(find.text('Aziza Karimova'), findsOneWidget);
    expect(find.text('Bobur Aliyev'), findsOneWidget);
    const today = LocalDate(2026, 10, 17);
    expect(find.text('${UzDates.dayLabel(today, today: today)} · 1'), findsOneWidget);
    expect(find.text('${UzDates.dayLabel(today.addDays(1), today: today)} · 1'), findsOneWidget);
    expect(find.text('10:00 – 10:40'), findsOneWidget);
    expect(find.text('Yangi'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'bobur');
    await _settle(t);
    expect(find.text('Aziza Karimova'), findsNothing);
    expect(find.text('Bobur Aliyev'), findsOneWidget);
  });

  testWidgets('empty range shows the empty view', (t) async {
    await pumpScreen(
      t,
      const AppointmentsScreen(),
      overrides: [
        appointmentsListProvider.overrideWith((ref, q) async => const <Appointment>[]),
        activeStaffProvider.overrideWithValue(const AsyncData(<Staff>[])),
      ],
    );
    await _settle(t);
    expect(find.text("Bu davrda yozuvlar yo'q"), findsOneWidget);
    expect(find.text('Yangi yozuv'), findsOneWidget);
  });

  testWidgets('offline shows the offline error', (t) async {
    await pumpScreen(t, const AppointmentsScreen(), http: FakeHttp()..offline = true);
    await _settle(t);
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });

  testWidgets('initialStaffId seeds the staff filter and the query', (t) async {
    final queries = <AppointmentsQuery>[];
    await pumpScreen(
      t,
      const AppointmentsScreen(initialStaffId: 2),
      overrides: [
        appointmentsListProvider.overrideWith((ref, q) async {
          queries.add(q);
          return list;
        }),
        activeStaffProvider.overrideWithValue(AsyncData([fxStaff()])),
      ],
    );
    await _settle(t);
    expect(queries, isNotEmpty);
    expect(queries.every((q) => q.staffId == 2), isTrue);
    expect(find.text('Usta Jahongir'), findsWidgets);
  });

  test('filterAppointmentsByText matches phone digits', () {
    expect(filterAppointmentsByText(list, '90 000 00 01').length, 2);
    expect(filterAppointmentsByText(list, 'soqol olish').single.id, 5020);
  });
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
}
