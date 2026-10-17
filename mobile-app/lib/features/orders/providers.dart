import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/period_chips.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Presets of the board range (max [kOrdersMaxDays] days).
const kOrdersPresets = [PeriodPreset.today, PeriodPreset.last7, PeriodPreset.last30, PeriodPreset.custom];
const kOrdersMaxDays = 62;

final class OrdersRange extends Notifier<DateRangeValue> {
  @override
  DateRangeValue build() {
    final a = ref.watch(activeBusinessProvider);
    return PeriodPreset.last7.range(bizToday(ref.read(clockProvider), a));
  }

  void set(DateRangeValue v) => state = v;
}

final ordersRangeProvider = NotifierProvider.autoDispose<OrdersRange, DateRangeValue>(OrdersRange.new);

final class OrdersTab extends Notifier<OrderStatus> {
  @override
  OrderStatus build() => OrderStatus.newOrder;

  void set(OrderStatus s) => state = s;
}

final ordersTabProvider = NotifierProvider.autoDispose<OrdersTab, OrderStatus>(OrdersTab.new);

/// Client-side search of the board (#id, customer name, phone).
final class OrdersSearch extends Notifier<String> {
  @override
  String build() => '';

  void set(String v) => state = v;
}

final ordersSearchProvider = NotifierProvider.autoDispose<OrdersSearch, String>(OrdersSearch.new);

/// GET /v1/orders for a business-local range, newest first. Staff tokens may call it too.
final ordersListProvider = FutureProvider.autoDispose.family<List<Order>, ({LocalDate from, LocalDate to})>((
  ref,
  r,
) async {
  final a = requireActive(ref);
  ref.watch(ordersRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final list = await ref
      .watch(apiClientProvider)
      .getList(
        Endpoints.orders,
        Order.fromJson,
        query: ApiQuery.orders(from: r.from, to: r.to, timezone: a.timezone),
        cancelToken: cancel,
      );
  final epoch = DateTime.utc(1970);
  return [...list]..sort((x, y) {
    final c = (y.createdAt ?? epoch).compareTo(x.createdAt ?? epoch);
    return c != 0 ? c : y.id.compareTo(x.id);
  });
});

/// Optimistic status changes merged over the list. An entry stays while its PATCH runs; a
/// finished one (success: the server row) is dropped when the list refetches.
final class OrderOverrides extends Notifier<Map<int, Order>> {
  final Set<int> _pending = {};

  @override
  Map<int, Order> build() {
    requireActive(ref);
    return const {};
  }

  bool isPending(int id) => _pending.contains(id);

  void begin(Order optimistic) {
    _pending.add(optimistic.id);
    state = {...state, optimistic.id: optimistic};
  }

  void succeed(Order saved) {
    _pending.remove(saved.id);
    state = {...state, saved.id: saved};
  }

  void fail(int id) {
    _pending.remove(id);
    state = {...state}..remove(id);
  }

  /// After a refetch: keep only the in-flight overrides.
  void dropFinished() {
    if (state.keys.every(_pending.contains)) return;
    state = {
      for (final e in state.entries)
        if (_pending.contains(e.key)) e.key: e.value,
    };
  }
}

final orderOverridesProvider = NotifierProvider.autoDispose<OrderOverrides, Map<int, Order>>(OrderOverrides.new);

/// The board list of the current range with the overrides applied.
final boardOrdersProvider = Provider.autoDispose<AsyncValue<List<Order>>>((ref) {
  final range = ref.watch(ordersRangeProvider);
  final overrides = ref.watch(orderOverridesProvider);
  return ref
      .watch(ordersListProvider(range.key))
      .whenData((list) => overrides.isEmpty ? list : [for (final o in list) overrides[o.id] ?? o]);
});

/// Orders matching [q] on '#id' / id, customer name or phone (digits).
List<Order> searchOrders(List<Order> list, String q) {
  final text = q.trim().toLowerCase();
  if (text.isEmpty) return list;
  final idText = text.startsWith('#') ? text.substring(1) : text;
  final digits = text.replaceAll(RegExp(r'\D'), '');
  return [
    for (final o in list)
      if ('${o.id}' == idText ||
          (o.customerName ?? '').toLowerCase().contains(text) ||
          (digits.length >= 3 && (o.customerPhone ?? '').replaceAll(RegExp(r'\D'), '').contains(digits)))
        o,
  ];
}

/// Counts per board status.
Map<OrderStatus, int> countByStatus(List<Order> list) {
  final m = {for (final s in OrderStatus.board) s: 0};
  for (final o in list) {
    if (m.containsKey(o.status)) m[o.status] = m[o.status]! + 1;
  }
  return m;
}
