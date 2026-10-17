import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Filter of the appointments list (BIZNES-SPEC §9.4).
@immutable
final class AppointmentsFilter {
  const AppointmentsFilter({required this.from, required this.to, this.staffId, this.status, this.text = ''});

  final LocalDate from;
  final LocalDate to;
  final int? staffId;
  final AppointmentStatus? status;

  /// Client-side match on client name, phone and service name.
  final String text;

  /// Family key of [appointmentsListProvider].
  AppointmentsQuery get query => (from: from, to: to, staffId: staffId, status: status);

  AppointmentsFilter copyWith({LocalDate? from, LocalDate? to, String? text}) => AppointmentsFilter(
    from: from ?? this.from,
    to: to ?? this.to,
    staffId: staffId,
    status: status,
    text: text ?? this.text,
  );

  AppointmentsFilter withStaff(int? id) =>
      AppointmentsFilter(from: from, to: to, staffId: id, status: status, text: text);

  AppointmentsFilter withStatus(AppointmentStatus? s) =>
      AppointmentsFilter(from: from, to: to, staffId: staffId, status: s, text: text);

  @override
  bool operator ==(Object other) =>
      other is AppointmentsFilter &&
      other.from == from &&
      other.to == to &&
      other.staffId == staffId &&
      other.status == status &&
      other.text == text;

  @override
  int get hashCode => Object.hash(from, to, staffId, status, text);
}

typedef AppointmentsQuery = ({LocalDate from, LocalDate to, int? staffId, AppointmentStatus? status});

/// Max days of the list range picker.
const kAppointmentsMaxDays = 62;

final class AppointmentsFilterNotifier extends Notifier<AppointmentsFilter> {
  @override
  AppointmentsFilter build() {
    final a = ref.watch(activeBusinessProvider);
    final today = bizToday(ref.read(clockProvider), a);
    return AppointmentsFilter(from: today, to: today.addDays(7));
  }

  void setRange(LocalDate from, LocalDate to) => state = state.copyWith(from: from, to: to);
  void setStaff(int? staffId) => state = state.withStaff(staffId);
  void setStatus(AppointmentStatus? status) => state = state.withStatus(status);
  void setText(String text) => state = state.copyWith(text: text);
}

final appointmentsFilterProvider = NotifierProvider.autoDispose<AppointmentsFilterNotifier, AppointmentsFilter>(
  AppointmentsFilterNotifier.new,
);

/// GET /v1/appointments for a range (business shape: client_name, client_phone, service_name, ...).
final appointmentsListProvider = FutureProvider.autoDispose.family<List<Appointment>, AppointmentsQuery>((
  ref,
  q,
) async {
  final a = requireActive(ref);
  ref.watch(appointmentsRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final list = await ref
      .watch(apiClientProvider)
      .getList(
        Endpoints.appointments,
        Appointment.fromJson,
        query: ApiQuery.appointments(
          from: q.from,
          to: q.to,
          timezone: a.timezone,
          staffId: q.staffId,
          status: q.status,
        ),
        cancelToken: cancel,
      );
  return [...list]..sort((x, y) => x.startsAt.compareTo(y.startsAt));
});

/// GET /v1/appointments/{id}.
final appointmentDetailProvider = FutureProvider.autoDispose.family<Appointment, int>((ref, id) async {
  requireActive(ref);
  ref.watch(appointmentsRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref
      .watch(apiClientProvider)
      .get<Appointment>(
        Endpoints.appointment(id),
        decode: (d) => Appointment.fromJson(JsonRead.object(d)),
        cancelToken: cancel,
      );
});

typedef AvailabilityKey = ({int staffId, int serviceId, LocalDate date});

/// GET /v1/staff/{id}/availability (public, no token).
final availabilityProvider = FutureProvider.autoDispose.family<Availability, AvailabilityKey>((ref, k) async {
  requireActive(ref);
  ref.watch(appointmentsRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref
      .watch(apiClientProvider)
      .get<Availability>(
        Endpoints.availability(k.staffId),
        query: ApiQuery.availability(date: k.date, serviceId: k.serviceId),
        decode: (d) => Availability.fromJson(JsonRead.object(d)),
        auth: RequestAuth.none,
        cancelToken: cancel,
      );
});

/// GET /v1/site/{slug}/booked-days for today .. today+120 (public, no token).
final bookedDaysProvider = FutureProvider.autoDispose.family<BookedDays, String>((ref, slug) async {
  final a = requireActive(ref);
  ref.watch(appointmentsRevisionProvider);
  final today = bizToday(ref.read(clockProvider), a);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref
      .watch(apiClientProvider)
      .get<BookedDays>(
        Endpoints.siteBookedDays(slug),
        query: ApiQuery.localDays(from: today, to: today.addDays(120)),
        decode: (d) => BookedDays.fromJson(JsonRead.object(d)),
        auth: RequestAuth.none,
        cancelToken: cancel,
      );
});

/// GET /v1/clients?search=q&per_page=8; an empty query lists the 6 most recent clients.
final clientSearchProvider = FutureProvider.autoDispose.family<List<Client>, String>((ref, q) async {
  requireActive(ref);
  ref.watch(clientsRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final text = q.trim();
  final page = await ref
      .watch(apiClientProvider)
      .getPage(
        Endpoints.clients,
        Client.fromJson,
        query: text.isEmpty ? {'per_page': 6} : {'search': text, 'per_page': 8},
        cancelToken: cancel,
      );
  return page.items;
});

/// GET /v1/clients/{id} -> the client of `initialClientId`.
final initialClientProvider = FutureProvider.autoDispose.family<Client, int>((ref, id) async {
  requireActive(ref);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref
      .watch(apiClientProvider)
      .get<Client>(
        Endpoints.client(id),
        decode: (d) => ClientDetail.fromJson(JsonRead.object(d)).client,
        cancelToken: cancel,
      );
});

/// Appointments of [list] matching [text] (client name, phone, service name), case-insensitive.
List<Appointment> filterAppointmentsByText(List<Appointment> list, String text) {
  final q = text.trim().toLowerCase();
  if (q.isEmpty) return list;
  final digits = q.replaceAll(RegExp(r'\D'), '');
  return [
    for (final a in list)
      if ((a.clientName ?? '').toLowerCase().contains(q) ||
          (a.serviceName ?? '').toLowerCase().contains(q) ||
          (a.clientPhone ?? '').toLowerCase().contains(q) ||
          (digits.length >= 3 && (a.clientPhone ?? '').replaceAll(RegExp(r'\D'), '').contains(digits)))
        a,
  ];
}

/// Groups [list] (sorted by start) by business-local day.
List<({LocalDate day, List<Appointment> items})> groupAppointmentsByDay(List<Appointment> list, String timezone) {
  final out = <({LocalDate day, List<Appointment> items})>[];
  for (final a in list) {
    final d = Dates.localDateOf(a.startsAt, timezone);
    if (out.isNotEmpty && out.last.day == d) {
      out.last.items.add(a);
    } else {
      out.add((day: d, items: [a]));
    }
  }
  return out;
}
