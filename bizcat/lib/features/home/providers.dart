import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/booking_flow.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/core/revisions.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/data/directory_providers.dart';
import 'package:bizcat/data/directory_query.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The featured carousel query for [city] (null = all cities).
DirectoryQuery homeFeaturedQuery(String? city) => DirectoryQuery(sort: 'featured', perPage: 10, city: city);

/// The top-rated list query for [city] (null = all cities).
DirectoryQuery homeTopRatedQuery(String? city) => DirectoryQuery(sort: 'rating', perPage: 5, city: city);

/// businessListProvider(DirectoryQuery(sort: 'featured', perPage: 10, city: ref.watch(cityProvider))).
final homeFeaturedProvider = Provider.autoDispose<AsyncValue<Paged<BusinessCard>>>(
  (ref) => ref.watch(businessListProvider(homeFeaturedQuery(ref.watch(cityProvider)))),
);

/// sort 'rating', perPage 5, same city.
final homeTopRatedProvider = Provider.autoDispose<AsyncValue<Paged<BusinessCard>>>(
  (ref) => ref.watch(businessListProvider(homeTopRatedQuery(ref.watch(cityProvider)))),
);

/// Signed in only (null otherwise). GET Endpoints.consumerAppointments
/// {scope: 'upcoming', page: 1, per_page: 1} -> the first item or null.
final nextAppointmentProvider = FutureProvider.autoDispose<Appointment?>((ref) async {
  final consumerId = ref.watch(consumerIdProvider);
  ref.watch(bookingsRevisionProvider);
  if (consumerId == null) return null;
  final page = await ref
      .read(apiProvider)
      .getPage(
        Endpoints.consumerAppointments,
        Appointment.fromJson,
        query: const {'scope': 'upcoming', 'page': 1, 'per_page': 1},
      );
  return page.items.isEmpty ? null : page.items.first;
});

/// A business the consumer visited (completed appointment) or ordered from (delivered order).
@immutable
final class RevisitItem {
  const RevisitItem({
    required this.business,
    required this.lastAt,
    required this.engine,
    this.serviceId,
    this.serviceName,
    this.staffId,
    this.staffName,
    this.orderId,
    this.orderSummary,
  });

  /// From a completed appointment; null when the payload has no business.
  static RevisitItem? fromAppointment(Appointment a) {
    final b = a.business;
    if (b == null || b.slug.isEmpty) return null;
    return RevisitItem(
      business: b,
      lastAt: a.startsAt,
      engine: b.engine,
      serviceId: a.serviceId > 0 ? a.serviceId : null,
      serviceName: a.serviceName,
      staffId: a.staffId > 0 ? a.staffId : null,
      staffName: a.staffName,
    );
  }

  /// From a delivered order; null when the payload has no business.
  static RevisitItem? fromOrder(Order o) {
    final b = o.business;
    if (b == null || b.slug.isEmpty) return null;
    return RevisitItem(
      business: b,
      lastAt: o.createdAt ?? DateTime.utc(1970),
      engine: b.engine,
      orderId: o.id,
      orderSummary: orderSummaryOf(o),
    );
  }

  final BusinessRef business;

  /// Appointment startsAt / order createdAt (UTC).
  final DateTime lastAt;

  /// business.engine.
  final Engine engine;
  final int? serviceId;
  final String? serviceName;
  final int? staffId;
  final String? staffName;
  final int? orderId;

  /// 'Napoleon torti ×2', plus ' va yana N ta' for more lines.
  final String? orderSummary;

  BookingFlow get flow => bookingFlowForEngine(engine);

  /// slot -> bookSlot(slug, serviceId, staffId); rental -> bookRental(slug);
  /// catalog -> menu(slug, reorder: orderId).
  String rebookPath() => switch (flow) {
    BookingFlow.slot => AppRoutes.bookSlot(business.slug, serviceId: serviceId, staffId: staffId),
    BookingFlow.rental => AppRoutes.bookRental(business.slug),
    BookingFlow.catalog => AppRoutes.menu(business.slug, reorder: orderId),
  };

  /// The card's button text.
  String get rebookLabel => switch (flow) {
    BookingFlow.slot => 'Qayta yozilish',
    BookingFlow.rental => 'Yana bron qilish',
    BookingFlow.catalog => orderId == null ? 'Qayta yozilish' : 'Qayta buyurtma',
  };
}

/// 'Napoleon torti (1 kg) ×2' / 'Napoleon torti (1 kg)' / '... va yana 2 ta'. null without items.
String? orderSummaryOf(Order o) {
  if (o.items.isEmpty) return null;
  final first = o.items.first;
  final head = first.qty > 1 ? '${first.name} ×${first.qty}' : first.name;
  final more = (o.itemsCount > o.items.length ? o.itemsCount : o.items.length) - 1;
  return more > 0 ? '$head va yana $more ta' : head;
}

/// Groups by business id (the most recent visit wins), newest first, at most [limit].
List<RevisitItem> buildRevisitItems(List<Appointment> appointments, List<Order> orders, {int limit = 10}) {
  final byBusiness = <int, RevisitItem>{};
  void add(RevisitItem? item) {
    if (item == null) return;
    final current = byBusiness[item.business.id];
    if (current == null || item.lastAt.isAfter(current.lastAt)) byBusiness[item.business.id] = item;
  }

  for (final a in appointments) {
    if (a.status == AppointmentStatus.completed) add(RevisitItem.fromAppointment(a));
  }
  for (final o in orders) {
    if (o.status == OrderStatus.delivered) add(RevisitItem.fromOrder(o));
  }
  final list = byBusiness.values.toList()..sort((a, b) => b.lastAt.compareTo(a.lastAt));
  return list.length > limit ? list.sublist(0, limit) : list;
}

/// Signed in only ([] otherwise). Past appointments (completed) and past orders (delivered) are
/// fetched in parallel; when only one of them fails the other still fills the list.
final revisitProvider = FutureProvider.autoDispose<List<RevisitItem>>((ref) async {
  final consumerId = ref.watch(consumerIdProvider);
  ref.watch(bookingsRevisionProvider);
  if (consumerId == null) return const [];
  final api = ref.read(apiProvider);

  Future<(List<T>, Object?)> safe<T>(Future<Paged<T>> f) async {
    try {
      return ((await f).items, null);
    } on Object catch (e) {
      return (<T>[], e);
    }
  }

  final results = await (
    safe(
      api.getPage(
        Endpoints.consumerAppointments,
        Appointment.fromJson,
        query: const {'scope': 'past', 'page': 1, 'per_page': 50},
      ),
    ),
    safe(
      api.getPage(Endpoints.consumerOrders, Order.fromJson, query: const {'scope': 'past', 'page': 1, 'per_page': 50}),
    ),
  ).wait;
  final (appointments, appointmentsError) = results.$1;
  final (orders, ordersError) = results.$2;
  if (appointmentsError != null && ordersError != null) throw appointmentsError;
  return buildRevisitItems(appointments, orders);
});
