import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../auth/jwt_claims.dart';
import '../auth/permissions.dart';
import '../time/dates.dart';
import '../util/json_read.dart';
import 'business.dart';
import 'enums.dart';

/// users row minus password_hash (live: id, phone, name, status, created_at, updated_at,
/// is_superadmin 0/1).
@immutable
final class BizUser {
  const BizUser({
    required this.id,
    required this.phone,
    required this.name,
    this.status = 10,
    this.isSuperadmin = false,
    this.createdAt,
    this.updatedAt,
  });

  factory BizUser.fromJson(Map<String, dynamic> json) => BizUser(
        id: JsonRead.integer(json['id']),
        phone: JsonRead.string(json['phone']),
        name: JsonRead.string(json['name']),
        status: JsonRead.integer(json['status'], 10),
        isSuperadmin: JsonRead.boolean(json['is_superadmin']),
        createdAt: JsonRead.unix(json['created_at']),
        updatedAt: JsonRead.unix(json['updated_at']),
      );

  final int id;
  final String phone;
  final String name;

  /// 10 active.
  final int status;

  /// 0/1 on the wire.
  final bool isSuperadmin;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'status': status,
        'is_superadmin': isSuperadmin,
        'created_at': createdAt == null ? null : Dates.toUnix(createdAt!),
        'updated_at': updatedAt == null ? null : Dates.toUnix(updatedAt!),
      };
}

/// `active` in login/me/switch (BP 4.1).
///
/// The business app's shell: manager shell when role is owner/admin; staff shell when role is
/// staff (staff without staffId sees the "profile not linked" screen + orders if permitted).
@immutable
final class ActiveContext {
  const ActiveContext({this.businessId, this.role, this.staffId, this.permissions = const []});

  factory ActiveContext.fromJson(Map<String, dynamic> json) {
    final rawRole = JsonRead.stringOrNull(json['role']);
    final role = rawRole == null ? null : BizRole.fromWire(rawRole);
    final rawPerms = json['permissions'];
    return ActiveContext(
      businessId: JsonRead.integerOrNull(json['business_id']),
      role: role,
      staffId: JsonRead.integerOrNull(json['staff_id']),
      permissions: rawPerms is List ? JsonRead.stringList(rawPerms) : Permissions.forRole(rawRole),
    );
  }

  final int? businessId;

  /// null when no active business.
  final BizRole? role;

  /// NEW; null if not linked.
  final int? staffId;

  /// NEW; missing -> Permissions.forRole(role).
  final List<String> permissions;

  bool get hasBusiness => businessId != null;
  bool get isOwner => role == BizRole.owner;
  bool get isAdmin => role == BizRole.admin;
  bool get isStaff => role == BizRole.staff;
  bool get isManager => role?.isManager ?? false;
  bool get hasStaffProfile => staffId != null;
  bool can(String permission) => permissions.contains(permission);

  Map<String, dynamic> toJson() => {
        'business_id': businessId,
        'role': role?.wire,
        'staff_id': staffId,
        'permissions': permissions,
      };
}

/// POST /v1/auth/login (BP 4.1).
@immutable
final class AuthSession {
  const AuthSession({
    required this.token,
    this.expiresAt,
    required this.user,
    this.businesses = const [],
    this.active = const ActiveContext(),
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = JsonRead.string(json['token']);
    return AuthSession(
      token: token,
      expiresAt: JsonRead.unix(json['expires_at']) ?? JwtClaims.tryParse(token)?.expiresAt,
      user: BizUser.fromJson(JsonRead.objectOrNull(json['user']) ?? const <String, dynamic>{}),
      businesses: JsonRead.list(json['businesses'], BusinessMembership.fromJson),
      active: ActiveContext.fromJson(JsonRead.objectOrNull(json['active']) ?? const <String, dynamic>{}),
    );
  }

  final String token;

  /// NEW; fallback JwtClaims.exp.
  final DateTime? expiresAt;
  final BizUser user;
  final List<BusinessMembership> businesses;
  final ActiveContext active;

  /// businesses.firstWhereOrNull(id == active.businessId).
  BusinessMembership? get activeBusiness =>
      active.businessId == null ? null : businesses.firstWhereOrNull((b) => b.id == active.businessId);

  /// Replaces user, businesses, active; keeps token.
  AuthSession withMe(AuthMe me) =>
      AuthSession(token: token, expiresAt: expiresAt, user: me.user, businesses: me.businesses, active: me.active);

  /// Replaces token, expiresAt, active.
  AuthSession withSwitch(SwitchResult s) =>
      AuthSession(token: s.token, expiresAt: s.expiresAt, user: user, businesses: businesses, active: s.active);

  Map<String, dynamic> toJson() => {
        'token': token,
        'expires_at': expiresAt == null ? null : Dates.toUnix(expiresAt!),
        'user': user.toJson(),
        'businesses': [for (final b in businesses) b.toJson()],
        'active': active.toJson(),
      };
}

/// GET /v1/auth/me.
@immutable
final class AuthMe {
  const AuthMe({required this.user, this.active = const ActiveContext(), this.businesses = const []});

  factory AuthMe.fromJson(Map<String, dynamic> json) => AuthMe(
        user: BizUser.fromJson(JsonRead.objectOrNull(json['user']) ?? const <String, dynamic>{}),
        active: ActiveContext.fromJson(JsonRead.objectOrNull(json['active']) ?? const <String, dynamic>{}),
        businesses: JsonRead.list(json['businesses'], BusinessMembership.fromJson),
      );

  final BizUser user;
  final ActiveContext active;
  final List<BusinessMembership> businesses;

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'active': active.toJson(),
        'businesses': [for (final b in businesses) b.toJson()],
      };
}

/// POST /v1/auth/switch/{businessId}.
@immutable
final class SwitchResult {
  const SwitchResult({required this.token, this.expiresAt, this.active = const ActiveContext()});

  factory SwitchResult.fromJson(Map<String, dynamic> json) {
    final token = JsonRead.string(json['token']);
    return SwitchResult(
      token: token,
      expiresAt: JsonRead.unix(json['expires_at']) ?? JwtClaims.tryParse(token)?.expiresAt,
      active: ActiveContext.fromJson(JsonRead.objectOrNull(json['active']) ?? const <String, dynamic>{}),
    );
  }

  final String token;
  final DateTime? expiresAt;
  final ActiveContext active;

  Map<String, dynamic> toJson() => {
        'token': token,
        'expires_at': expiresAt == null ? null : Dates.toUnix(expiresAt!),
        'active': active.toJson(),
      };
}
