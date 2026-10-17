import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Team mutations (owner only: team.manage). Every call bumps the staff revision, because team
/// links change `staff.user_id`.
class TeamActions {
  TeamActions(this._ref);

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  /// POST /v1/team {"phone","name","role","password"?,"staff_id"?} -> 201 TeamMember.
  Future<TeamMember> add(TeamMemberInput input) async {
    final m = await _api.post<TeamMember>(Endpoints.team,
        body: input.toJson(), decode: (d) => TeamMember.fromJson(JsonRead.object(d)));
    bump(_ref, staffRevisionProvider);
    return m;
  }

  /// PATCH /v1/team/{userId} {"role"?, "staff_id"?} -> partial TeamMember (user_id, role, staff_id).
  Future<TeamMember> patch(int userId, TeamMemberPatch p) async {
    final m = await _api.patch<TeamMember>(Endpoints.teamMember(userId),
        body: p.toJson(), decode: (d) => TeamMember.fromJson(JsonRead.object(d)));
    bump(_ref, staffRevisionProvider);
    return m;
  }

  /// DELETE /v1/team/{userId} -> 204.
  Future<void> remove(int userId) async {
    await _api.delete<Object?>(Endpoints.teamMember(userId));
    bump(_ref, staffRevisionProvider);
  }
}

final teamActionsProvider = Provider<TeamActions>(TeamActions.new);
