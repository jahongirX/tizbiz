import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/orders/actions.dart';
import 'package:tizbiz_biznes/features/orders/providers.dart';
import 'package:tizbiz_biznes/features/orders/widgets/order_card.dart';
import 'package:tizbiz_biznes/features/orders/widgets/order_detail_sheet.dart';
import 'package:tizbiz_biznes/features/orders/widgets/status_picker_sheet.dart';
import 'package:tizbiz_biznes/shared/polling.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/loading_view.dart';
import 'package:tizbiz_biznes/shared/widgets/period_chips.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Buyurtmalar board (BIZNES-SPEC §9.5); the same widget in the manager and staff shells.
class OrdersBoardScreen extends ConsumerStatefulWidget {
  const OrdersBoardScreen({super.key});

  @override
  ConsumerState<OrdersBoardScreen> createState() => _OrdersBoardScreenState();
}

class _OrdersBoardScreenState extends ConsumerState<OrdersBoardScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: OrderStatus.board.length,
    vsync: this,
    initialIndex: OrderStatus.board.indexOf(ref.read(ordersTabProvider)).clamp(0, OrderStatus.board.length - 1),
  );
  final _search = TextEditingController();

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _change(Order order, OrderStatus next) async {
    try {
      await applyOrderStatus(ref, order, next);
      if (mounted) showAppSnack(context, 'Buyurtma #${order.id}: ${next.label}');
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _pick(Order order) async {
    final s = await showOrderStatusPicker(context, order.status);
    if (s != null) await _change(order, s);
  }

  void _openDetail(Order order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => OrderDetailSheet(initial: order, onStatus: _change),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(ordersRangeProvider);
    final tab = ref.watch(ordersTabProvider);
    final query = ref.watch(ordersSearchProvider);
    final value = ref.watch(boardOrdersProvider);
    ref.listen(ordersListProvider(range.key), (prev, next) {
      if (next.hasValue && !next.isLoading) ref.read(orderOverridesProvider.notifier).dropFinished();
    });
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final all = value.value;
    final searched = all == null ? null : searchOrders(all, query);
    final counts = searched == null ? null : countByStatus(searched);
    final inTab = searched == null
        ? null
        : [
            for (final o in searched)
              if (o.status == tab) o,
          ];
    final tabTotal = inTab?.fold<int>(0, (sum, o) => sum + o.totalTiyin);
    Future<void> refresh() => ref.refresh(ordersListProvider(range.key).future);

    return Scaffold(
      appBar: AppBar(title: const Text('Buyurtmalar')),
      body: PollWhileVisible(
        onTick: () => ref.invalidate(ordersListProvider(range.key)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            PeriodChips(
              value: range,
              presets: kOrdersPresets,
              maxDays: kOrdersMaxDays,
              onChanged: (v) => ref.read(ordersRangeProvider.notifier).set(v),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: '#raqam, mijoz yoki telefon',
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Tozalash',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            ref.read(ordersSearchProvider.notifier).set('');
                          },
                        ),
                ),
                onChanged: (v) => ref.read(ordersSearchProvider.notifier).set(v),
              ),
            ),
            TabBar(
              controller: _tabs,
              onTap: (i) => ref.read(ordersTabProvider.notifier).set(OrderStatus.board[i]),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (final s in OrderStatus.board)
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.label),
                        if (counts != null) ...[
                          const SizedBox(width: 6),
                          _CountBadge(count: counts[s] ?? 0, color: c.orderStatusColor(s)),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            if (tabTotal != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Jami: ${Money.format(tabTotal)}', style: t.labelLarge?.copyWith(color: c.textMuted)),
              ),
            Expanded(
              child: AsyncBody<List<Order>>(
                value: value,
                loading: const SkeletonList(),
                onRetry: () => ref.invalidate(ordersListProvider(range.key)),
                isEmpty: (list) => list.isEmpty,
                empty: _EmptyList(
                  onRefresh: refresh,
                  child: const EmptyView(icon: Icons.receipt_long_outlined, title: "Bu davrda buyurtmalar yo'q"),
                ),
                data: (_) {
                  final rows = inTab ?? const <Order>[];
                  if (rows.isEmpty) {
                    return _EmptyList(
                      onRefresh: refresh,
                      child: query.trim().isEmpty
                          ? const EmptyView(icon: Icons.inbox_outlined, title: "Bu bo'limda buyurtmalar yo'q")
                          : const EmptyView(icon: Icons.search_off, title: 'Hech narsa topilmadi'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final o = rows[i];
                        final next = o.status.next;
                        return OrderCard(
                          key: ValueKey(o.id),
                          order: o,
                          busy: ref.read(orderOverridesProvider.notifier).isPending(o.id),
                          onTap: () => _openDetail(o),
                          onNext: next == null ? () {} : () => _change(o, next),
                          onPickStatus: () => _pick(o),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [const SizedBox(height: 48), child]),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
    child: Text(
      '$count',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
    ),
  );
}
