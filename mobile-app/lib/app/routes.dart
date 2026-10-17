import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Every location of the app. Features navigate only through these
/// (`context.go(Routes.clients)`, `context.push(Routes.appointment(id))`).
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const pickBusiness = '/pick-business';
  static const noBusiness = '/no-business';

  // ---- manager shell
  static const dashboard = '/o/dashboard';
  static const timetable = '/o/timetable';
  static const appointments = '/o/appointments';
  static const orders = '/o/orders';
  static const clients = '/o/clients';
  static const more = '/o/more';
  static const services = '/o/more/services';
  static const serviceNew = '/o/more/services/new';
  static const serviceCategories = '/o/more/service-categories';
  static const staff = '/o/more/staff';
  static const staffNew = '/o/more/staff/new';
  static const finance = '/o/more/finance';
  static const payroll = '/o/more/payroll';
  static const reviews = '/o/more/reviews';
  static const settings = '/o/more/settings';
  static const team = '/o/more/team';

  static String service(int id) => '/o/more/services/$id';

  /// tab: 0 Ma'lumot, 1 Ish vaqti, 2 Dam olish.
  static String staffDetail(int id, {int tab = 0}) => '/o/more/staff/$id?tab=$tab';

  static String appointmentsFor({int? staffId}) => staffId == null ? appointments : '$appointments?staff=$staffId';

  // ---- manager detail routes (root navigator, no bottom bar)
  static String appointment(int id) => '/appointment/$id';

  static const appointmentNewPath = '/appointment/new';

  /// '/appointment/new?staff=2&date=2026-10-17&time=10:30&client=881'.
  static String appointmentNew({int? staffId, LocalDate? date, HmTime? time, int? clientId}) {
    final q = <String, String>{
      if (staffId != null) 'staff': '$staffId',
      if (date != null) 'date': date.toIso(),
      if (time != null) 'time': time.format(),
      if (clientId != null) 'client': '$clientId',
    };
    return Uri(path: appointmentNewPath, queryParameters: q.isEmpty ? null : q).toString();
  }

  static String client(int id) => '/client/$id';
  static const clientNew = '/client/new';
  static String clientEdit(int id) => '/client/$id/edit';

  // ---- staff shell
  static const myDay = '/s/today';
  static const myStats = '/s/stats';
  static const mySchedule = '/s/schedule';
  static const myOrders = '/s/orders';
  static const profile = '/s/profile';
  static String myAppointment(int id) => '/s/appointment/$id';

  /// Home for a session:
  /// - manager: `/o/orders` when engine == catalog, else `/o/dashboard`;
  /// - staff: `/s/orders` when the business has orders and the member has no appointments
  ///   (no linked profile, or a catalog business), else `/s/today`.
  static String homeFor(ActiveBusiness a) {
    if (a.isStaff) {
      return a.hasOrders && (!a.hasStaffProfile || !a.hasAppointments) ? myOrders : myDay;
    }
    return a.engine == Engine.catalog ? orders : dashboard;
  }
}
