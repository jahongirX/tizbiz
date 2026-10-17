import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/period_chips.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Business-local today of the active business.
final meTodayProvider = Provider.autoDispose<LocalDate>((ref) {
  final a = requireActive(ref);
  return bizToday(ref.read(clockProvider), a);
});

/// "Statistikam" period; default this month.
class MyStatsRange extends Notifier<DateRangeValue> {
  @override
  DateRangeValue build() => PeriodPreset.month.range(ref.watch(meTodayProvider));

  void set(DateRangeValue v) => state = v;
}

final myStatsRangeProvider = NotifierProvider.autoDispose<MyStatsRange, DateRangeValue>(MyStatsRange.new);

const kMyStatsPresets = [
  PeriodPreset.today, PeriodPreset.week, PeriodPreset.month, PeriodPreset.prevMonth, PeriodPreset.custom, //
];

/// GET /v1/me/stats?from&to (business-local days).
final myStatsProvider = FutureProvider.autoDispose.family<MeStats, ({LocalDate from, LocalDate to})>((ref, r) async {
  requireActive(ref);
  ref.watch(appointmentsRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).get<MeStats>(Endpoints.meStats,
      query: ApiQuery.localDays(from: r.from, to: r.to),
      decode: (d) => MeStats.fromJson(JsonRead.object(d)),
      cancelToken: cancel);
});

/// GET /v1/me/schedule?from=today&to=today+60 -> working_hours + time_off.
final myScheduleProvider = FutureProvider.autoDispose<MeSchedule>((ref) async {
  requireActive(ref);
  ref.watch(scheduleRevisionProvider);
  final today = ref.watch(meTodayProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).get<MeSchedule>(Endpoints.meSchedule,
      query: ApiQuery.localDays(from: today, to: today.addDays(60)),
      decode: (d) => MeSchedule.fromJson(JsonRead.object(d)),
      cancelToken: cancel);
});

/// GET /v1/me/staff -> own staff row (+ business).
final meStaffProvider = FutureProvider.autoDispose<Staff>((ref) async {
  requireActive(ref);
  ref.watch(staffRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).get<Staff>(Endpoints.meStaff,
      decode: (d) => Staff.fromJson(JsonRead.object(d)), cancelToken: cancel);
});
