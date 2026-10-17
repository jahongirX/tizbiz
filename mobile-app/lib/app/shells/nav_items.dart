import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// One bottom-bar destination; [branch] is the StatefulShellRoute branch index.
@immutable
final class NavItem {
  const NavItem({required this.branch, required this.label, required this.icon, required this.selectedIcon});

  final int branch;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  @override
  String toString() => 'NavItem($branch $label)';
}

/// Manager branches: 0 dashboard, 1 timetable, 2 appointments, 3 orders, 4 clients, 5 more.
abstract final class ManagerBranch {
  static const dashboard = 0, timetable = 1, appointments = 2, orders = 3, clients = 4, more = 5;
}

/// Staff branches: 0 today, 1 stats, 2 schedule, 3 orders, 4 profile.
abstract final class StaffBranch {
  static const today = 0, stats = 1, schedule = 2, orders = 3, profile = 4;
}

const _dashboard = NavItem(
  branch: ManagerBranch.dashboard,
  label: 'Bosh sahifa',
  icon: Icons.space_dashboard_outlined,
  selectedIcon: Icons.space_dashboard,
);
const _timetable = NavItem(
  branch: ManagerBranch.timetable,
  label: 'Jadval',
  icon: Icons.calendar_view_day_outlined,
  selectedIcon: Icons.calendar_view_day,
);
const _orders = NavItem(
  branch: ManagerBranch.orders,
  label: 'Buyurtmalar',
  icon: Icons.receipt_long_outlined,
  selectedIcon: Icons.receipt_long,
);
const _clients = NavItem(
  branch: ManagerBranch.clients,
  label: 'Mijozlar',
  icon: Icons.people_outline,
  selectedIcon: Icons.people,
);
const _more = NavItem(branch: ManagerBranch.more, label: "Ko'proq", icon: Icons.menu, selectedIcon: Icons.menu);

NavItem _appointments(String label) => NavItem(
      branch: ManagerBranch.appointments,
      label: label,
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note,
    );

/// Manager bar per engine (BIZNES-SPEC §6.5).
List<NavItem> managerNavItems(ActiveBusiness a) => switch (a.engine) {
      Engine.slot || Engine.rental => [_dashboard, _timetable, _appointments(a.appointmentsTerm), _clients, _more],
      Engine.medical => [_dashboard, _timetable, _appointments(a.appointmentsTerm), _orders, _more],
      Engine.catalog => [_dashboard, _orders, _clients, _more],
    };

/// Staff bar: Mening kunim + Statistikam (with appointments), Jadvalim, Buyurtmalar (with orders),
/// Profil.
List<NavItem> staffNavItems(ActiveBusiness a) => [
      if (a.hasAppointments) ...const [
        NavItem(
          branch: StaffBranch.today,
          label: 'Mening kunim',
          icon: Icons.today_outlined,
          selectedIcon: Icons.today,
        ),
        NavItem(
          branch: StaffBranch.stats,
          label: 'Statistikam',
          icon: Icons.insights_outlined,
          selectedIcon: Icons.insights,
        ),
      ],
      const NavItem(
        branch: StaffBranch.schedule,
        label: 'Jadvalim',
        icon: Icons.schedule_outlined,
        selectedIcon: Icons.schedule,
      ),
      if (a.hasOrders)
        const NavItem(
          branch: StaffBranch.orders,
          label: 'Buyurtmalar',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
        ),
      const NavItem(
        branch: StaffBranch.profile,
        label: 'Profil',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
      ),
    ];

/// Index of the bar item for [currentBranch]; when the branch is not in the bar (e.g. Mijozlar on
/// medical) the [fallbackBranch] item (Ko'proq / Profil) is highlighted.
int selectedNavIndex(List<NavItem> items, int currentBranch, {required int fallbackBranch}) {
  final i = items.indexWhere((n) => n.branch == currentBranch);
  if (i >= 0) return i;
  final f = items.indexWhere((n) => n.branch == fallbackBranch);
  return f >= 0 ? f : 0;
}
