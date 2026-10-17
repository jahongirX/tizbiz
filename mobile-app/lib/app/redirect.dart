import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/core/session/session_state.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Permission / engine guard of one route (BIZNES-SPEC §6.2).
final class RouteGuard {
  const RouteGuard({this.permission, this.engine});

  /// `ActiveBusiness.can(permission)` must hold.
  final String? permission;

  /// Extra engine condition.
  final bool Function(ActiveBusiness a)? engine;

  bool allows(ActiveBusiness a) =>
      (permission == null || a.can(permission!)) && (engine == null || engine!(a));
}

bool _hasTimetable(ActiveBusiness a) => a.engine.hasTimetable;
bool _isStorefront(ActiveBusiness a) => a.engine.isCatalogStorefront;
bool _notCatalog(ActiveBusiness a) => a.engine != Engine.catalog;

const _none = RouteGuard();
const _catalogManage = RouteGuard(permission: Permissions.catalogManage);
const _clients = RouteGuard(permission: Permissions.clients);

/// Path patterns (no query) -> guard. Unlisted paths have no guard (unknown paths render
/// NotFoundScreen through the router's errorBuilder).
final List<(RegExp, RouteGuard)> _guards = [
  (RegExp(r'^/o/dashboard$'), const RouteGuard(permission: Permissions.analytics)),
  (RegExp(r'^/o/timetable$'), const RouteGuard(permission: Permissions.appointmentsAll, engine: _hasTimetable)),
  (RegExp(r'^/o/appointments$'), const RouteGuard(permission: Permissions.appointmentsAll, engine: _hasTimetable)),
  (RegExp(r'^/o/orders$'), const RouteGuard(permission: Permissions.orders, engine: _isStorefront)),
  (RegExp(r'^/o/clients$'), _clients),
  (RegExp(r'^/o/more$'), _none),
  (RegExp(r'^/o/more/services(/[^/]+)?$'), _catalogManage),
  (RegExp(r'^/o/more/service-categories$'), _catalogManage),
  (RegExp(r'^/o/more/staff(/[^/]+)?$'), _catalogManage),
  (RegExp(r'^/o/more/finance$'), const RouteGuard(permission: Permissions.finance)),
  (RegExp(r'^/o/more/payroll$'), const RouteGuard(permission: Permissions.payroll, engine: _notCatalog)),
  (RegExp(r'^/o/more/reviews$'), const RouteGuard(permission: Permissions.reviews)),
  (RegExp(r'^/o/more/settings$'), const RouteGuard(permission: Permissions.settingsManage)),
  (RegExp(r'^/o/more/team$'), const RouteGuard(permission: Permissions.teamRead)),
  (RegExp(r'^/appointment/new$'), const RouteGuard(permission: Permissions.appointmentsManage, engine: _hasTimetable)),
  (RegExp(r'^/appointment/[^/]+$'), const RouteGuard(permission: Permissions.appointmentsAll)),
  (RegExp(r'^/client/new$'), _clients),
  (RegExp(r'^/client/[^/]+(/edit)?$'), _clients),
  (RegExp(r'^/s/today$'), const RouteGuard(engine: _hasTimetable)),
  (RegExp(r'^/s/stats$'), const RouteGuard(engine: _hasTimetable)),
  (RegExp(r'^/s/schedule$'), _none),
  (RegExp(r'^/s/orders$'), const RouteGuard(permission: Permissions.orders, engine: _isStorefront)),
  (RegExp(r'^/s/profile$'), _none),
  (RegExp(r'^/s/appointment/[^/]+$'), _none),
];

/// The guard of [path] (null: no guard / unknown path).
RouteGuard? guardFor(String path) {
  for (final (pattern, guard) in _guards) {
    if (pattern.hasMatch(path)) return guard;
  }
  return null;
}

/// Whether [a] may open [path] (role shell + permission + engine). Used by the redirect and by
/// the "Ko'proq" menu to show only reachable rows.
bool canOpen(ActiveBusiness a, String path) {
  final p = _normalize(path);
  if (_isManagerPath(p) && !a.isManager) return false;
  if (_isStaffPath(p) && !a.isStaff) return false;
  return guardFor(p)?.allows(a) ?? true;
}

String _normalize(String path) {
  final q = path.indexOf('?');
  var p = q >= 0 ? path.substring(0, q) : path;
  if (p.isEmpty) p = '/';
  if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
  return p;
}

bool _under(String p, String prefix) => p == prefix || p.startsWith('$prefix/');

bool _isManagerPath(String p) => _under(p, '/o') || _under(p, '/appointment') || _under(p, '/client');

bool _isStaffPath(String p) => _under(p, '/s');

/// Returns the location to go to, or null to stay (BIZNES-SPEC §6.3). Pure.
String? computeRedirect({required SessionState session, required ActiveBusiness? active, required Uri location}) {
  final path = _normalize(location.path);
  String? go(String target) => _normalize(target) == path ? null : target;

  // 1. booting
  if (session is SessionBooting) return go(Routes.splash);

  // 2. signed out
  if (session is SessionSignedOut) return go(Routes.login);

  final signedIn = session as SessionSignedIn;

  // 3. no business at all
  if (signedIn.session.businesses.isEmpty) return go(Routes.noBusiness);

  // 4. no active business, or a fresh multi-business login
  if (active == null || signedIn.needsPicker) return go(Routes.pickBusiness);
  if (path == Routes.pickBusiness) return null; // the business switcher stays reachable

  // 5. unknown role
  if (active.role == BizRole.unknown) return go(Routes.noBusiness);

  final home = Routes.homeFor(active);

  // 6. entry points
  if (path == '/' || path == Routes.splash || path == Routes.login || path == Routes.noBusiness) {
    return go(home);
  }

  // 7. the other role's shell
  if (active.isManager && _isStaffPath(path)) return go(home);
  if (!active.isManager && _isManagerPath(path)) return go(home);

  // 8. permission / engine guards
  final guard = guardFor(path);
  if (guard != null && !guard.allows(active)) return go(home);

  return null;
}
