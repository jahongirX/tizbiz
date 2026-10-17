import 'package:flutter_test/flutter_test.dart';
import 'package:tizbiz_biznes/app/redirect.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';

String? _redirect(SessionState s, String location) => computeRedirect(
      session: s,
      active: s is SessionSignedIn ? ActiveBusiness.fromSession(s.session) : null,
      location: Uri.parse(location),
    );

void main() {
  final owner = fxSignedIn();
  final admin = fxSignedIn(role: BizRole.admin);
  final catalogOwner = fxSignedIn(engine: Engine.catalog);
  final staff = fxSignedIn(role: BizRole.staff, staffId: 2);
  final catalogStaffUnlinked = fxSignedIn(role: BizRole.staff, engine: Engine.catalog);
  final catalogStaffLinked = fxSignedIn(role: BizRole.staff, engine: Engine.catalog, staffId: 12);

  final cases = <(String, SessionState, String, String?)>[
    ('booting -> /splash', const SessionBooting(), '/o/clients', Routes.splash),
    ('booting on /splash stays', const SessionBooting(), '/splash', null),
    ('signed out on /o/clients -> /login', const SessionSignedOut(), '/o/clients', Routes.login),
    ('signed out on /login stays', const SessionSignedOut(message: 'x'), '/login', null),
    ('no businesses -> /no-business', fxSignedIn(businesses: const []), '/o/dashboard', Routes.noBusiness),
    ('no businesses on /no-business stays', fxSignedIn(businesses: const []), '/no-business', null),
    ('needsPicker -> /pick-business', fxSignedIn(needsPicker: true), '/o/dashboard', Routes.pickBusiness),
    ('no active business -> /pick-business', fxSignedIn(activeBusinessId: 999), '/o/dashboard', null),
    ('owner on / -> /o/dashboard', owner, '/', Routes.dashboard),
    ('owner on /splash -> /o/dashboard', owner, '/splash', Routes.dashboard),
    ('owner on /login -> /o/dashboard', owner, '/login', Routes.dashboard),
    ('owner on /pick-business stays (switcher)', owner, '/pick-business', null),
    ('catalog owner on / -> /o/orders', catalogOwner, '/', Routes.orders),
    ('catalog owner on /o/timetable -> /o/orders', catalogOwner, '/o/timetable', Routes.orders),
    ('catalog owner on /o/more/payroll -> /o/orders', catalogOwner, '/o/more/payroll', Routes.orders),
    ('slot owner on /o/orders -> /o/dashboard', owner, '/o/orders', Routes.dashboard),
    ('owner on /o/more/team stays', owner, '/o/more/team', null),
    ('admin on /o/more/team stays (team.read)', admin, '/o/more/team', null),
    ('owner on /appointment/new?staff=2 stays', owner, '/appointment/new?staff=2', null),
    ('owner on /client/881/edit stays', owner, '/client/881/edit', null),
    ('staff on /o/dashboard -> /s/today', staff, '/o/dashboard', Routes.myDay),
    ('staff on / -> /s/today', staff, '/', Routes.myDay),
    ('staff on /s/stats stays', staff, '/s/stats', null),
    ('slot staff on /s/orders -> /s/today', staff, '/s/orders', Routes.myDay),
    ('staff without staff_id in catalog on / -> /s/orders', catalogStaffUnlinked, '/', Routes.myOrders),
    ('linked staff in catalog on / -> /s/orders', catalogStaffLinked, '/', Routes.myOrders),
    ('linked catalog staff on /s/today -> /s/orders', catalogStaffLinked, '/s/today', Routes.myOrders),
    ('staff on /appointment/5 -> /s/today', staff, '/appointment/5', Routes.myDay),
    ('staff on /client/881 -> /s/today', staff, '/client/881', Routes.myDay),
    ('staff on /s/appointment/5 stays', staff, '/s/appointment/5', null),
    ('owner on /s/today -> /o/dashboard', owner, '/s/today', Routes.dashboard),
    (
      'manager without finance on /o/more/finance -> home',
      fxSignedIn(role: BizRole.admin, permissions: [for (final p in Permissions.all) if (p != Permissions.finance) p]),
      '/o/more/finance',
      Routes.dashboard,
    ),
    (
      'unknown role -> /no-business',
      fxSignedIn(role: BizRole.unknown),
      '/o/dashboard',
      Routes.noBusiness,
    ),
    ('unknown path is left to the errorBuilder', owner, '/nope', null),
  ];

  for (final (name, state, location, expected) in cases) {
    test(name, () {
      if (name.startsWith('no active business')) {
        expect(_redirect(state, location), Routes.pickBusiness);
        expect(_redirect(state, Routes.pickBusiness), isNull);
        return;
      }
      expect(_redirect(state, location), expected);
    });
  }

  test('home never redirects to itself (no loops)', () {
    for (final s in [owner, admin, catalogOwner, staff, catalogStaffUnlinked, catalogStaffLinked]) {
      final a = ActiveBusiness.fromSession(s.session)!;
      expect(_redirect(s, Routes.homeFor(a)), isNull, reason: '$a');
    }
    for (final e in Engine.values) {
      final s = fxSignedIn(engine: e);
      expect(_redirect(s, Routes.homeFor(ActiveBusiness.fromSession(s.session)!)), isNull);
      final st = fxSignedIn(engine: e, role: BizRole.staff, staffId: 2);
      expect(_redirect(st, Routes.homeFor(ActiveBusiness.fromSession(st.session)!)), isNull);
    }
  });

  test('Routes builders', () {
    expect(Routes.staffDetail(3, tab: 1), '/o/more/staff/3?tab=1');
    expect(Routes.appointmentsFor(staffId: 2), '/o/appointments?staff=2');
    expect(Routes.appointmentsFor(), '/o/appointments');
    expect(Routes.appointmentNew(), '/appointment/new');
    expect(
      Routes.appointmentNew(staffId: 2, date: const LocalDate(2026, 10, 17), time: const HmTime(10, 30), clientId: 881),
      '/appointment/new?staff=2&date=2026-10-17&time=10%3A30&client=881',
    );
    expect(Routes.clientEdit(5), '/client/5/edit');
    expect(Routes.myAppointment(7), '/s/appointment/7');
  });

  test('canOpen follows role, permission and engine', () {
    final o = ActiveBusiness.fromSession(owner.session)!;
    final s = ActiveBusiness.fromSession(staff.session)!;
    final c = ActiveBusiness.fromSession(catalogOwner.session)!;
    expect(canOpen(o, Routes.team), isTrue);
    expect(canOpen(o, Routes.myDay), isFalse);
    expect(canOpen(s, Routes.dashboard), isFalse);
    expect(canOpen(s, Routes.mySchedule), isTrue);
    expect(canOpen(c, Routes.payroll), isFalse);
    expect(canOpen(c, Routes.timetable), isFalse);
    expect(canOpen(c, Routes.orders), isTrue);
  });
}
