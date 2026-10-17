import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

enum MyDayView { today, tomorrow, week }

/// Bugun / Ertaga / Hafta.
class MyDayRange extends Notifier<MyDayView> {
  @override
  MyDayView build() => MyDayView.today;

  void set(MyDayView v) => state = v;
}

final myDayRangeProvider = NotifierProvider.autoDispose<MyDayRange, MyDayView>(MyDayRange.new);

/// Business-local day range of a view; week = today..today+6.
({LocalDate from, LocalDate to}) myDayRangeFor(MyDayView v, LocalDate today) => switch (v) {
      MyDayView.today => (from: today, to: today),
      MyDayView.tomorrow => (from: today.addDays(1), to: today.addDays(1)),
      MyDayView.week => (from: today, to: today.addDays(6)),
    };

/// Business-local today of the active business.
final myTodayProvider = Provider.autoDispose<LocalDate>((ref) {
  final a = requireActive(ref);
  return bizToday(ref.read(clockProvider), a);
});

/// GET /v1/me/appointments?from&to (local days) -> own bookings, starts_at ASC.
final myAppointmentsProvider =
    FutureProvider.autoDispose.family<List<Appointment>, ({LocalDate from, LocalDate to})>((ref, r) async {
  requireActive(ref);
  ref.watch(appointmentsRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).getList(Endpoints.meAppointments, Appointment.fromJson,
      query: ApiQuery.localDays(from: r.from, to: r.to), cancelToken: cancel);
});

/// GET /v1/me/stats for today only (header counters).
final myTodayStatsProvider = FutureProvider.autoDispose<MeStats>((ref) async {
  requireActive(ref);
  ref.watch(appointmentsRevisionProvider);
  final today = ref.watch(myTodayProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).get<MeStats>(Endpoints.meStats,
      query: ApiQuery.localDays(from: today, to: today),
      decode: (d) => MeStats.fromJson(JsonRead.object(d)),
      cancelToken: cancel);
});

/// GET /v1/me/appointments/{id} (404 'Bron topilmadi.' when not mine).
final myAppointmentProvider = FutureProvider.autoDispose.family<Appointment, int>((ref, id) async {
  requireActive(ref);
  ref.watch(appointmentsRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).get<Appointment>(Endpoints.meAppointment(id),
      decode: (d) => Appointment.fromJson(JsonRead.object(d)), cancelToken: cancel);
});
