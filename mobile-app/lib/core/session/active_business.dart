import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/app/theme/vertical.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The business the session acts on (BIZNES-SPEC §5.4).
@immutable
final class ActiveBusiness {
  const ActiveBusiness({
    required this.businessId,
    required this.name,
    required this.slug,
    this.category,
    this.logo,
    required this.engine,
    required this.role,
    this.staffId,
    required this.permissions,
    this.timezone = Dates.defaultTimezone,
    required this.vertical,
  });

  /// null when the session has no `active.business_id`, or that id is not one of
  /// `session.businesses` (then the business picker is shown).
  static ActiveBusiness? fromSession(AuthSession session) {
    final id = session.active.businessId;
    if (id == null) return null;
    final m = session.activeBusiness;
    if (m == null) return null;
    final role = session.active.role ?? m.role;
    final engine = m.engine;
    final perms = session.active.permissions.isNotEmpty
        ? session.active.permissions
        : Permissions.forRole(role == BizRole.unknown ? null : role.wire);
    return ActiveBusiness(
      businessId: id,
      name: m.name,
      slug: m.slug,
      category: m.category,
      logo: m.logo,
      engine: engine,
      role: role,
      staffId: session.active.staffId,
      permissions: List.unmodifiable(perms),
      vertical: Vertical.of(category: m.category, engine: engine),
    );
  }

  /// active.business_id.
  final int businessId;
  final String name;
  final String slug;
  final String? category;
  final String? logo;
  final Engine engine;

  /// active.role.
  final BizRole role;

  /// active.staff_id.
  final int? staffId;

  /// active.permissions (fallback Permissions.forRole).
  final List<String> permissions;

  /// No endpoint exposes the zone to managers; all businesses are Asia/Tashkent.
  final String timezone;
  final Vertical vertical;

  bool get isManager => role.isManager;
  bool get isStaff => role == BizRole.staff;
  bool get isOwner => role == BizRole.owner;
  bool get hasStaffProfile => staffId != null;
  bool can(String permission) => permissions.contains(permission);

  /// catalog, medical.
  bool get hasOrders => engine.isCatalogStorefront;

  /// slot, medical, rental.
  bool get hasAppointments => engine.hasTimetable;

  /// Navbatlar | Qabullar | Ijaralar.
  String get appointmentsTerm => engine.appointmentsTerm;

  @override
  bool operator ==(Object other) =>
      other is ActiveBusiness &&
      other.businessId == businessId &&
      other.name == name &&
      other.slug == slug &&
      other.category == category &&
      other.logo == logo &&
      other.engine == engine &&
      other.role == role &&
      other.staffId == staffId &&
      other.timezone == timezone &&
      other.vertical == vertical &&
      listEquals(other.permissions, permissions);

  @override
  int get hashCode => Object.hash(businessId, name, slug, category, logo, engine, role, staffId, timezone,
      vertical, Object.hashAll(permissions));

  @override
  String toString() => 'ActiveBusiness($businessId $slug ${engine.wire} ${role.wire} staff=$staffId)';
}

/// null unless signed in with `active.business_id` set.
final activeBusinessProvider = Provider<ActiveBusiness?>((ref) {
  final s = ref.watch(sessionProvider);
  return s is SessionSignedIn ? ActiveBusiness.fromSession(s.session) : null;
});

/// Tenant key: every tenant data provider watches it first, so a switch refetches everything.
final tenantKeyProvider = Provider<int?>((ref) => ref.watch(activeBusinessProvider.select((a) => a?.businessId)));

/// For data providers: watches [tenantKeyProvider] + [activeBusinessProvider]; throws
/// [StateError] when there is no active business.
ActiveBusiness requireActive(Ref ref) {
  ref.watch(tenantKeyProvider);
  final a = ref.watch(activeBusinessProvider);
  if (a == null) throw StateError('No active business');
  return a;
}
