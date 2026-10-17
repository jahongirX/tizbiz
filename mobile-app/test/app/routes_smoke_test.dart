import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/more/more_menu_screen.dart';
import 'package:tizbiz_biznes/app/not_found_screen.dart';
import 'package:tizbiz_biznes/app/shells/manager_shell.dart';
import 'package:tizbiz_biznes/app/shells/staff_shell.dart';
import 'package:tizbiz_biznes/app/splash_screen.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/features/appointments/appointment_create_screen.dart';
import 'package:tizbiz_biznes/features/appointments/appointment_detail_screen.dart';
import 'package:tizbiz_biznes/features/appointments/appointments_screen.dart';
import 'package:tizbiz_biznes/features/auth/business_picker_screen.dart';
import 'package:tizbiz_biznes/features/auth/login_screen.dart';
import 'package:tizbiz_biznes/features/auth/no_business_screen.dart';
import 'package:tizbiz_biznes/features/catalog/service_categories_screen.dart';
import 'package:tizbiz_biznes/features/catalog/service_form_screen.dart';
import 'package:tizbiz_biznes/features/catalog/services_screen.dart';
import 'package:tizbiz_biznes/features/clients/client_detail_screen.dart';
import 'package:tizbiz_biznes/features/clients/client_form_screen.dart';
import 'package:tizbiz_biznes/features/clients/clients_screen.dart';
import 'package:tizbiz_biznes/features/dashboard/dashboard_screen.dart';
import 'package:tizbiz_biznes/features/me/my_schedule_screen.dart';
import 'package:tizbiz_biznes/features/me/my_stats_screen.dart';
import 'package:tizbiz_biznes/features/me/profile_screen.dart';
import 'package:tizbiz_biznes/features/me_day/my_appointment_detail_screen.dart';
import 'package:tizbiz_biznes/features/me_day/my_day_screen.dart';
import 'package:tizbiz_biznes/features/money/finance_screen.dart';
import 'package:tizbiz_biznes/features/money/payroll_screen.dart';
import 'package:tizbiz_biznes/features/orders/orders_board_screen.dart';
import 'package:tizbiz_biznes/features/reviews/reviews_screen.dart';
import 'package:tizbiz_biznes/features/settings/booking_settings_screen.dart';
import 'package:tizbiz_biznes/features/staff_admin/staff_detail_screen.dart';
import 'package:tizbiz_biznes/features/staff_admin/staff_form_screen.dart';
import 'package:tizbiz_biznes/features/staff_admin/staff_list_screen.dart';
import 'package:tizbiz_biznes/features/team/team_screen.dart';
import 'package:tizbiz_biznes/features/timetable/timetable_screen.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/test_app.dart';

/// Opens [location] and expects the screen [type] (and the final location [expectLocation]).
Future<void> _expectRoute(
  WidgetTester tester,
  String location,
  Type type, {
  BizRole role = BizRole.owner,
  Engine engine = Engine.slot,
  int? staffId,
  SessionState? session,
  String? expectLocation,
}) async {
  await pumpRouterAt(tester, location, role: role, engine: engine, staffId: staffId, session: session);
  expect(find.byType(type), findsOneWidget, reason: '$location -> $type (at ${currentLocation()})');
  expect(currentLocation(), expectLocation ?? location);
}

void main() {
  group('flat routes', () {
    testWidgets('booting shows the splash', (tester) async {
      await pumpRouterAt(tester, '/o/dashboard', session: const SessionBooting());
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(currentLocation(), '/splash');
    });

    testWidgets('signed out shows the login', (tester) async {
      await _expectRoute(tester, '/o/clients', LoginScreen,
          session: const SessionSignedOut(), expectLocation: '/login');
    });

    testWidgets('pick-business', (tester) async {
      await _expectRoute(tester, '/o/dashboard', BusinessPickerScreen,
          session: fxSignedIn(needsPicker: true), expectLocation: '/pick-business');
    });

    testWidgets('no-business', (tester) async {
      await _expectRoute(tester, '/o/dashboard', NoBusinessScreen,
          session: fxSignedIn(businesses: const []), expectLocation: '/no-business');
    });
  });

  group('manager shell (slot owner)', () {
    final routes = <(String, Type)>[
      ('/o/dashboard', DashboardScreen),
      ('/o/timetable', TimetableScreen),
      ('/o/appointments', AppointmentsScreen),
      ('/o/clients', ClientsScreen),
      ('/o/more', MoreMenuScreen),
      ('/o/more/services', ServicesScreen),
      ('/o/more/services/new', ServiceFormScreen),
      ('/o/more/services/11', ServiceFormScreen),
      ('/o/more/service-categories', ServiceCategoriesScreen),
      ('/o/more/staff', StaffListScreen),
      ('/o/more/staff/new', StaffFormScreen),
      ('/o/more/staff/2?tab=1', StaffDetailScreen),
      ('/o/more/finance', FinanceScreen),
      ('/o/more/payroll', PayrollScreen),
      ('/o/more/reviews', ReviewsScreen),
      ('/o/more/settings', BookingSettingsScreen),
      ('/o/more/team', TeamScreen),
    ];
    for (final (location, type) in routes) {
      testWidgets(location, (tester) async {
        await _expectRoute(tester, location, type);
        expect(find.byType(ManagerShell), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
      });
    }

    testWidgets('literal "new" routes do not hit the :id parser', (tester) async {
      await _expectRoute(tester, '/o/more/services/new', ServiceFormScreen);
      expect(tester.widget<ServiceFormScreen>(find.byType(ServiceFormScreen)).serviceId, isNull);
      await _expectRoute(tester, '/o/more/staff/new', StaffFormScreen);
      await _expectRoute(tester, '/appointment/new', AppointmentCreateScreen);
      await _expectRoute(tester, '/client/new', ClientFormScreen);
      expect(tester.widget<ClientFormScreen>(find.byType(ClientFormScreen)).clientId, isNull);
    });

    testWidgets('params reach the constructors', (tester) async {
      await _expectRoute(tester, '/o/more/services/11', ServiceFormScreen);
      expect(tester.widget<ServiceFormScreen>(find.byType(ServiceFormScreen)).serviceId, 11);

      await _expectRoute(tester, '/o/more/staff/2?tab=1', StaffDetailScreen);
      final staff = tester.widget<StaffDetailScreen>(find.byType(StaffDetailScreen));
      expect((staff.staffId, staff.initialTab), (2, 1));

      await _expectRoute(tester, '/o/appointments?staff=2', AppointmentsScreen);
      expect(tester.widget<AppointmentsScreen>(find.byType(AppointmentsScreen)).initialStaffId, 2);

      await _expectRoute(tester, '/appointment/new?staff=2&date=2026-10-17&time=10:30&client=881', AppointmentCreateScreen);
      final create = tester.widget<AppointmentCreateScreen>(find.byType(AppointmentCreateScreen));
      expect(create.initialStaffId, 2);
      expect(create.initialDate, const LocalDate(2026, 10, 17));
      expect(create.initialTime, const HmTime(10, 30));
      expect(create.initialClientId, 881);
    });

    testWidgets('root detail routes have no bottom bar', (tester) async {
      for (final (location, type) in <(String, Type)>[
        ('/appointment/5012', AppointmentDetailScreen),
        ('/client/881', ClientDetailScreen),
        ('/client/881/edit', ClientFormScreen),
      ]) {
        await _expectRoute(tester, location, type);
        expect(find.byType(NavigationBar), findsNothing, reason: location);
      }
      expect(tester.widget<ClientFormScreen>(find.byType(ClientFormScreen)).clientId, 881);
    });

    testWidgets('bad params render NotFoundScreen', (tester) async {
      for (final location in [
        '/appointment/abc',
        '/client/x1',
        '/o/more/services/abc',
        '/o/more/staff/2?tab=x',
        '/appointment/new?date=2026-13-40',
        '/appointment/new?time=25:00',
        '/nope',
      ]) {
        await pumpRouterAt(tester, location);
        expect(find.byType(NotFoundScreen), findsOneWidget, reason: location);
      }
      expect(find.text('Sahifa topilmadi'), findsOneWidget);
    });
  });

  group('engine variants', () {
    testWidgets('catalog owner: orders board, no timetable', (tester) async {
      await _expectRoute(tester, '/o/orders', OrdersBoardScreen, engine: Engine.catalog);
      await _expectRoute(tester, '/o/timetable', OrdersBoardScreen, engine: Engine.catalog, expectLocation: '/o/orders');
      expect(find.text('Jadval'), findsNothing);
    });

    testWidgets('medical owner: orders and appointments', (tester) async {
      await _expectRoute(tester, '/o/orders', OrdersBoardScreen, engine: Engine.medical);
      await _expectRoute(tester, '/o/appointments', AppointmentsScreen, engine: Engine.medical);
      await _expectRoute(tester, '/o/clients', ClientsScreen, engine: Engine.medical);
    });
  });

  group('staff shell', () {
    final routes = <(String, Type)>[
      ('/s/today', MyDayScreen),
      ('/s/stats', MyStatsScreen),
      ('/s/schedule', MyScheduleScreen),
      ('/s/profile', ProfileScreen),
    ];
    for (final (location, type) in routes) {
      testWidgets(location, (tester) async {
        await _expectRoute(tester, location, type, role: BizRole.staff, staffId: 2);
        expect(find.byType(StaffShell), findsOneWidget);
      });
    }

    testWidgets('/s/orders (medical staff)', (tester) async {
      await _expectRoute(tester, '/s/orders', OrdersBoardScreen, role: BizRole.staff, engine: Engine.medical, staffId: 3);
      expect(find.byType(StaffShell), findsOneWidget);
    });

    testWidgets('/s/appointment/:id is full screen', (tester) async {
      await _expectRoute(tester, '/s/appointment/5012', MyAppointmentDetailScreen, role: BizRole.staff, staffId: 2);
      expect(tester.widget<MyAppointmentDetailScreen>(find.byType(MyAppointmentDetailScreen)).appointmentId, 5012);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('staff never reach a manager screen', (tester) async {
      await _expectRoute(tester, '/o/more/team', MyDayScreen, role: BizRole.staff, staffId: 2, expectLocation: '/s/today');
      await _expectRoute(tester, '/client/881', MyDayScreen, role: BizRole.staff, staffId: 2, expectLocation: '/s/today');
    });

    testWidgets('catalog staff land on the orders board', (tester) async {
      await _expectRoute(tester, '/', OrdersBoardScreen, role: BizRole.staff, engine: Engine.catalog, expectLocation: '/s/orders');
      expect(find.text('Mening kunim'), findsNothing);
      expect(find.text('Jadvalim'), findsOneWidget);
    });
  });

  testWidgets('bottom bar switches branches', (tester) async {
    await pumpRouterAt(tester, '/o/dashboard');
    await tester.tap(find.text('Mijozlar'));
    await tester.pumpAndSettle();
    expect(currentLocation(), '/o/clients');
    expect(find.byType(ClientsScreen), findsOneWidget);
    await tester.tap(find.text("Ko'proq"));
    await tester.pumpAndSettle();
    expect(find.byType(MoreMenuScreen), findsOneWidget);
  });

  testWidgets('logout from the session moves to /login', (tester) async {
    final session = await pumpRouterAt(tester, '/o/dashboard');
    session.emit(const SessionSignedOut(message: kSessionExpiredMessage));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(currentLocation(), '/login');
  });
}
