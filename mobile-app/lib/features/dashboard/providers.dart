import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/period_chips.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

typedef DayRange = ({LocalDate from, LocalDate to});

/// The dashboard report period; defaults to the last 7 business-local days.
final class DashboardRange extends Notifier<DateRangeValue> {
  @override
  DateRangeValue build() {
    final a = ref.watch(activeBusinessProvider);
    return PeriodPreset.last7.range(bizToday(ref.read(clockProvider), a));
  }

  void set(DateRangeValue value) => state = value;
}

final dashboardRangeProvider = NotifierProvider.autoDispose<DashboardRange, DateRangeValue>(DashboardRange.new);

/// GET /v1/analytics/overview for UTC days [from..to].
final analyticsProvider = FutureProvider.autoDispose.family<AnalyticsOverview, DayRange>((ref, range) async {
  requireActive(ref);
  ref.watch(appointmentsRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).get(
        Endpoints.analyticsOverview,
        query: ApiQuery.utcDays(from: range.from, to: range.to),
        decode: (d) => AnalyticsOverview.fromJson(JsonRead.object(d)),
        cancelToken: cancel,
      );
});

/// Today's appointments (business-local day), any status.
final todayAppointmentsProvider = FutureProvider.autoDispose<List<Appointment>>((ref) async {
  final a = requireActive(ref);
  ref.watch(appointmentsRevisionProvider);
  final today = bizToday(ref.read(clockProvider), a);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).getList(
        Endpoints.appointments,
        Appointment.fromJson,
        query: ApiQuery.appointments(from: today, to: today, timezone: a.timezone),
        cancelToken: cancel,
      );
});

/// Order totals of a business-local range (catalog / medical engines).
final class OrdersSummary {
  const OrdersSummary({
    required this.count,
    required this.totalTiyin,
    required this.byStatus,
    required this.daily,
  });

  /// [orders] are bucketed by their business-local creation day; every day of [from..to] is present.
  factory OrdersSummary.from(List<Order> orders, {required LocalDate from, required LocalDate to, String? timezone}) {
    final byStatus = <OrderStatus, int>{};
    final sums = <LocalDate, int>{};
    var total = 0;
    for (final o in orders) {
      byStatus[o.status] = (byStatus[o.status] ?? 0) + 1;
      if (o.status == OrderStatus.cancelled) continue;
      total += o.totalTiyin;
      final at = o.createdAt;
      if (at == null) continue;
      final day = Dates.localDateOf(at, timezone);
      sums[day] = (sums[day] ?? 0) + o.totalTiyin;
    }
    final days = from.isAfter(to) ? 0 : from.daysUntil(to) + 1;
    return OrdersSummary(
      count: orders.length,
      totalTiyin: total,
      byStatus: Map.unmodifiable(byStatus),
      daily: [
        for (var i = 0; i < days; i++) (date: from.addDays(i), totalTiyin: sums[from.addDays(i)] ?? 0),
      ],
    );
  }

  final int count;

  /// Sum of every order except `cancelled`.
  final int totalTiyin;
  final Map<OrderStatus, int> byStatus;
  final List<({LocalDate date, int totalTiyin})> daily;

  int countOf(OrderStatus s) => byStatus[s] ?? 0;
}

final ordersSummaryProvider = FutureProvider.autoDispose.family<OrdersSummary, DayRange>((ref, range) async {
  final a = requireActive(ref);
  ref.watch(ordersRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final orders = await ref.watch(apiClientProvider).getList(
        Endpoints.orders,
        Order.fromJson,
        query: ApiQuery.orders(from: range.from, to: range.to, timezone: a.timezone),
        cancelToken: cancel,
      );
  return OrdersSummary.from(orders, from: range.from, to: range.to, timezone: a.timezone);
});
