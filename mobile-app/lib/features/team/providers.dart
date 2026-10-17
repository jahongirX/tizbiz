import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// GET /v1/team -> [{user_id, name, phone, role, staff_id}] (owner/admin: team.read).
final teamProvider = FutureProvider.autoDispose<List<TeamMember>>((ref) async {
  requireActive(ref);
  ref.watch(staffRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).getList(Endpoints.team, TeamMember.fromJson, cancelToken: cancel);
});

/// The signed-in user's id (for the "Siz" chip and self-edit refresh).
final currentUserIdProvider = Provider.autoDispose<int?>((ref) {
  final s = ref.watch(sessionProvider);
  return s is SessionSignedIn ? s.session.user.id : null;
});
