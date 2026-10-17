import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Selected day of the timetable; defaults to the business-local today.
final class TimetableDate extends Notifier<LocalDate> {
  @override
  LocalDate build() => bizToday(ref.read(clockProvider), ref.watch(activeBusinessProvider));

  void set(LocalDate day) => state = day;
}

final timetableDateProvider = NotifierProvider.autoDispose<TimetableDate, LocalDate>(TimetableDate.new);

/// null = all active staff.
final class StaffFilter extends Notifier<int?> {
  @override
  int? build() {
    ref.watch(tenantKeyProvider);
    return null;
  }

  void set(int? staffId) => state = staffId;
}

final timetableStaffFilterProvider = NotifierProvider.autoDispose<StaffFilter, int?>(StaffFilter.new);

/// All appointments of one business-local day (every staff; grouped client-side by staffId).
final dayAppointmentsProvider = FutureProvider.autoDispose.family<List<Appointment>, LocalDate>((ref, day) async {
  final a = requireActive(ref);
  ref.watch(appointmentsRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).getList(Endpoints.appointments, Appointment.fromJson,
      query: ApiQuery.appointments(from: day, to: day, timezone: a.timezone), cancelToken: cancel);
});
