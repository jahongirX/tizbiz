import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/features/orders/providers.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Order mutations (BIZNES-SPEC §9.5). The server has no transition rules.
class OrderActions {
  OrderActions(this.ref);

  final Ref ref;

  /// PATCH /v1/orders/{id} {"status": s} ('cancelled' with two l's); bumps orders.
  Future<Order> setStatus(int id, OrderStatus s) async {
    final saved = await ref
        .read(apiClientProvider)
        .patch<Order>(Endpoints.order(id), body: {'status': s.wire}, decode: (d) => Order.fromJson(JsonRead.object(d)));
    bump(ref, ordersRevisionProvider);
    return saved;
  }
}

final orderActionsProvider = Provider<OrderActions>(OrderActions.new);

/// Optimistic status change for the board: override first, PATCH, then the server row (keeping
/// the known items when the response has none); on error the override is reverted and the error
/// rethrown for the caller's snack.
Future<Order> applyOrderStatus(WidgetRef ref, Order order, OrderStatus next) async {
  final overrides = ref.read(orderOverridesProvider.notifier);
  overrides.begin(order.copyWith(status: next));
  try {
    final saved = await ref.read(orderActionsProvider).setStatus(order.id, next);
    final merged = saved.items.isEmpty && order.items.isNotEmpty ? order.copyWith(status: saved.status) : saved;
    overrides.succeed(merged);
    return merged;
  } catch (_) {
    overrides.fail(order.id);
    rethrow;
  }
}
