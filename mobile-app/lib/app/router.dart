import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/more/more_menu_screen.dart';
import 'package:tizbiz_biznes/app/not_found_screen.dart';
import 'package:tizbiz_biznes/app/redirect.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/shells/manager_shell.dart';
import 'package:tizbiz_biznes/app/shells/staff_shell.dart';
import 'package:tizbiz_biznes/app/splash_screen.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
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

/// Navigator of full-screen routes (detail screens without the bottom bar).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Session epoch the router is built for: -2 booting, -1 signed out, else the signed-in epoch.
int _routerEpoch(SessionState s) => switch (s) {
      SessionSignedIn(:final epoch) => epoch,
      SessionBooting() => -2,
      SessionSignedOut() => -1,
    };

/// Notifies the router on any session / active-business change (role, needsPicker, staff link).
final class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
    ref.listen(activeBusinessProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  // Rebuilt when the epoch changes (login, switch, logout): resets every branch stack of both shells.
  ref.watch(sessionProvider.select(_routerEpoch));
  final refresh = _SessionListenable(ref);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => computeRedirect(
      session: ref.read(sessionProvider),
      active: ref.read(activeBusinessProvider),
      location: state.uri,
    ),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: buildRoutes(),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

// ------------------------------------------------------------------ params

int? _int(String? s) => s == null ? null : int.tryParse(s);

/// Path parameter `id` as int, or null (-> NotFoundScreen).
int? _pathId(GoRouterState s) => _int(s.pathParameters['id']);

/// Optional query int: absent -> (ok, null); present but invalid -> (bad).
({bool ok, int? value}) _queryInt(GoRouterState s, String key) {
  final raw = s.uri.queryParameters[key];
  if (raw == null || raw.isEmpty) return (ok: true, value: null);
  final v = int.tryParse(raw);
  return (ok: v != null, value: v);
}

Widget _withId(GoRouterState s, Widget Function(int id) build) {
  final id = _pathId(s);
  return id == null ? const NotFoundScreen() : build(id);
}

Widget _appointmentNew(GoRouterState s) {
  final staff = _queryInt(s, 'staff');
  final client = _queryInt(s, 'client');
  final q = s.uri.queryParameters;
  final rawDate = q['date'];
  final rawTime = q['time'];
  final date = (rawDate == null || rawDate.isEmpty) ? null : LocalDate.tryParse(rawDate);
  final time = (rawTime == null || rawTime.isEmpty) ? null : HmTime.tryParse(rawTime);
  final badDate = rawDate != null && rawDate.isNotEmpty && (date == null || rawDate.trim().length != 10);
  final badTime = rawTime != null && rawTime.isNotEmpty && time == null;
  if (!staff.ok || !client.ok || badDate || badTime) return const NotFoundScreen();
  return AppointmentCreateScreen(
    initialStaffId: staff.value,
    initialDate: date,
    initialTime: time,
    initialClientId: client.value,
  );
}

Widget _staffDetail(GoRouterState s) {
  final id = _pathId(s);
  final tab = _queryInt(s, 'tab');
  if (id == null || !tab.ok) return const NotFoundScreen();
  final t = tab.value ?? 0;
  return StaffDetailScreen(staffId: id, initialTab: t < 0 || t > 2 ? 0 : t);
}

// ------------------------------------------------------------------ table

/// Every route of BIZNES-SPEC §6.2. Literal `new` routes are registered before their `:id`
/// siblings (go_router matches in list order).
List<RouteBase> buildRoutes() => [
      // 1-4: flat
      GoRoute(path: Routes.splash, name: 'splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: Routes.login, name: 'login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: Routes.pickBusiness, name: 'pick-business', builder: (c, s) => const BusinessPickerScreen()),
      GoRoute(path: Routes.noBusiness, name: 'no-business', builder: (c, s) => const NoBusinessScreen()),

      // 5-22: manager shell
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => ManagerShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.dashboard, name: 'dashboard', builder: (c, s) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.timetable, name: 'timetable', builder: (c, s) => const TimetableScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.appointments,
              name: 'appointments',
              builder: (c, s) {
                final staff = _queryInt(s, 'staff');
                return staff.ok ? AppointmentsScreen(initialStaffId: staff.value) : const NotFoundScreen();
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.orders, name: 'orders', builder: (c, s) => const OrdersBoardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.clients, name: 'clients', builder: (c, s) => const ClientsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.more,
              name: 'more',
              builder: (c, s) => const MoreMenuScreen(),
              routes: [
                GoRoute(
                  path: 'services',
                  name: 'services',
                  builder: (c, s) => const ServicesScreen(),
                  routes: [
                    GoRoute(path: 'new', name: 'service-new', builder: (c, s) => const ServiceFormScreen()),
                    GoRoute(
                      path: ':id',
                      name: 'service',
                      builder: (c, s) => _withId(s, (id) => ServiceFormScreen(serviceId: id)),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'service-categories',
                  name: 'service-categories',
                  builder: (c, s) => const ServiceCategoriesScreen(),
                ),
                GoRoute(
                  path: 'staff',
                  name: 'staff',
                  builder: (c, s) => const StaffListScreen(),
                  routes: [
                    GoRoute(path: 'new', name: 'staff-new', builder: (c, s) => const StaffFormScreen()),
                    GoRoute(path: ':id', name: 'staff-detail', builder: (c, s) => _staffDetail(s)),
                  ],
                ),
                GoRoute(path: 'finance', name: 'finance', builder: (c, s) => const FinanceScreen()),
                GoRoute(path: 'payroll', name: 'payroll', builder: (c, s) => const PayrollScreen()),
                GoRoute(path: 'reviews', name: 'reviews', builder: (c, s) => const ReviewsScreen()),
                GoRoute(path: 'settings', name: 'settings', builder: (c, s) => const BookingSettingsScreen()),
                GoRoute(path: 'team', name: 'team', builder: (c, s) => const TeamScreen()),
              ],
            ),
          ]),
        ],
      ),

      // 28-32: staff shell
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => StaffShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.myDay, name: 'my-day', builder: (c, s) => const MyDayScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.myStats, name: 'my-stats', builder: (c, s) => const MyStatsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.mySchedule, name: 'my-schedule', builder: (c, s) => const MyScheduleScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.myOrders, name: 'my-orders', builder: (c, s) => const OrdersBoardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.profile, name: 'profile', builder: (c, s) => const ProfileScreen()),
          ]),
        ],
      ),

      // 23-27, 33: full-screen detail routes (no bottom bar)
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.appointmentNewPath,
        name: 'appointment-new',
        builder: (c, s) => _appointmentNew(s),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/appointment/:id',
        name: 'appointment',
        builder: (c, s) => _withId(s, (id) => AppointmentDetailScreen(appointmentId: id)),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.clientNew,
        name: 'client-new',
        builder: (c, s) => const ClientFormScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/client/:id',
        name: 'client',
        builder: (c, s) => _withId(s, (id) => ClientDetailScreen(clientId: id)),
        routes: [
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: 'edit',
            name: 'client-edit',
            builder: (c, s) => _withId(s, (id) => ClientFormScreen(clientId: id)),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/s/appointment/:id',
        name: 'my-appointment',
        builder: (c, s) => _withId(s, (id) => MyAppointmentDetailScreen(appointmentId: id)),
      ),
    ];
