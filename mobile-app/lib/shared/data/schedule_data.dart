import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Manager only. GET /v1/staff/{staffId}/working-hours.
final workingHoursProvider = FutureProvider.autoDispose.family<List<WorkingHours>, int>((ref, staffId) async {
  requireActive(ref);
  ref.watch(scheduleRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref
      .watch(apiClientProvider)
      .getList(Endpoints.workingHours(staffId), WorkingHours.fromJson, cancelToken: cancel);
});

/// Manager only. GET /v1/staff/{staffId}/time-off.
final timeOffProvider = FutureProvider.autoDispose.family<List<TimeOff>, int>((ref, staffId) async {
  requireActive(ref);
  ref.watch(scheduleRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).getList(Endpoints.timeOff(staffId), TimeOff.fromJson, cancelToken: cancel);
});
