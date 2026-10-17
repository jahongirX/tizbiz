import 'package:meta/meta.dart';

import '../util/json_read.dart';
import 'enums.dart';

/// GET /v1/team item, POST response, PATCH response (BP 4.2). PATCH returns only user_id, role,
/// staff_id.
@immutable
final class TeamMember {
  const TeamMember({required this.userId, this.name, this.phone, this.role = BizRole.unknown, this.staffId});

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        userId: JsonRead.integer(json['user_id']),
        name: JsonRead.stringOrNull(json['name']),
        phone: JsonRead.stringOrNull(json['phone']),
        role: BizRole.fromWire(JsonRead.stringOrNull(json['role'])),
        staffId: JsonRead.integerOrNull(json['staff_id']),
      );

  final int userId;
  final String? name;
  final String? phone;
  final BizRole role;
  final int? staffId;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'phone': phone,
        'role': role.wire,
        'staff_id': staffId,
      };
}
