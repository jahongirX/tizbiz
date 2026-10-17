import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/features/bookings/providers.dart';
import 'package:bizcat/features/bookings/widgets.dart';
import 'package:bizcat/shared/widgets/bottom_bar.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/dialogs.dart';
import 'package:bizcat/shared/widgets/location_card.dart';
import 'package:bizcat/shared/widgets/nav.dart';
import 'package:bizcat/shared/widgets/poller.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/shared/widgets/status_chips.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The steps of the order progress.
const List<OrderStatus> kOrderSteps = [
  OrderStatus.newOrder,
  OrderStatus.confirmed,
  OrderStatus.preparing,
  OrderStatus.ready,
  OrderStatus.delivered,
];

/// One order: progress, lines, total, the business and the actions. Active orders are polled.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.id, this.justCreated = false});

  final int id;
  final bool justCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(orderDetailProvider(id));
    void retry() => ref.invalidate(orderDetailProvider(id));

    final Widget body;
    final o = value.value;
    if (o != null) {
      body = Poller(
        interval: const Duration(seconds: 30),
        enabled: isActiveOrder(o.status),
        refreshOnResume: true,
        onTick: () => unawaited(ref.read(orderDetailProvider(id).notifier).refresh()),
        child: _OrderBody(order: o, justCreated: justCreated),
      );
    } else if (value.hasError && !value.isLoading) {
      final e = value.error!;
      if (e is ApiException && e.isNotFound) {
        body = EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Buyurtma topilmadi',
          actionLabel: 'Bronlarim',
          onAction: () => context.go(AppRoutes.bookingsWith(tab: 'orders')),
        );
      } else if (isOffline(e)) {
        body = OfflineState(onRetry: retry);
      } else {
        body = ErrorState(message: errorText(e), onRetry: retry);
      }
    } else {
      // Scroll-wrapped so the skeleton never overflows short or wide screens.
      body = const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: LoadingView(kind: LoadingKind.detail, rows: 3),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => popOrGo(context, AppRoutes.bookingsWith(tab: 'orders'))),
        title: Text('Buyurtma #$id'),
      ),
      body: body,
      bottomNavigationBar: justCreated
          ? BottomActionBar(
              child: PrimaryButton(
                label: "Bronlarimga o'tish",
                onPressed: () => context.go(AppRoutes.bookingsWith(tab: 'orders')),
              ),
            )
          : null,
    );
  }
}

class _OrderBody extends ConsumerWidget {
  const _OrderBody({required this.order, required this.justCreated});

  final Order order;
  final bool justCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = order;
    final b = o.business;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ctrl = ref.read(orderDetailProvider(o.id).notifier);
    final note = o.note?.trim() ?? '';
    final medical = b?.engine == Engine.medical;

    return RefreshIndicator(
      onRefresh: () => ctrl.refresh(silent: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.l, BzSpace.gutter, BzSpace.xxl),
        children: [
          if (justCreated)
            SuccessHero(
              title: medical ? "So'rovingiz qabul qilindi!" : 'Buyurtmangiz qabul qilindi!',
              note: 'Biznes tez orada tasdiqlaydi.',
            ),
          if (o.status == OrderStatus.cancelled)
            const InfoLine(
              icon: Icons.block,
              text: 'Bekor qilingan',
              foreground: BzColors.neutral,
              background: BzColors.neutralBg,
            )
          else
            OrderProgress(status: o.status),
          const SizedBox(height: BzSpace.m),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(BzSpace.l),
              child: Column(
                children: [
                  for (final line in o.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: BzSpace.s),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text('${line.name} ×${line.qty}', style: theme.textTheme.bodyMedium)),
                          const SizedBox(width: BzSpace.m),
                          Text(Money.format(line.totalTiyin), style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(child: Text('Jami', style: theme.textTheme.titleMedium)),
                      Text(
                        Money.format(o.totalTiyin),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: BzSpace.m),
            SectionCard(
              title: 'Izoh',
              child: Text(note, style: theme.textTheme.bodyMedium),
            ),
          ],
          const SizedBox(height: BzSpace.m),
          BusinessBlock(business: b, chip: OrderStatusChip(o.status)),
          if (b != null) ...[
            const SizedBox(height: BzSpace.m),
            LocationCard(address: b.address, mapUrl: b.mapUrl, name: b.name, phone: b.phone),
          ],
          if (o.canReview ?? false) ...[
            const SizedBox(height: BzSpace.m),
            PrimaryButton(
              label: 'Sharh qoldirish',
              icon: Icons.rate_review_outlined,
              onPressed: () => unawaited(context.push(AppRoutes.reviewNew(orderId: o.id, businessName: b?.name))),
            ),
          ] else if (o.reviewId != null) ...[
            const SizedBox(height: BzSpace.m),
            SecondaryButton(
              label: 'Sharhim',
              icon: Icons.rate_review_outlined,
              onPressed: () => unawaited(context.push(AppRoutes.myReviews)),
            ),
          ],
          if (o.status == OrderStatus.delivered && b != null && b.slug.isNotEmpty) ...[
            const SizedBox(height: BzSpace.m),
            SecondaryButton(
              label: 'Qayta buyurtma',
              icon: Icons.replay,
              onPressed: () => unawaited(context.push(AppRoutes.menu(b.slug, reorder: o.id))),
            ),
          ],
          if (o.canCancel ?? false) ...[
            const SizedBox(height: BzSpace.l),
            Center(
              child: DangerTextButton(
                label: 'Buyurtmani bekor qilish',
                onPressed: () => unawaited(_cancel(context, ref, o.id)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _cancel(BuildContext context, WidgetRef ref, int id) async {
    final ok = await confirmDialog(
      context,
      title: 'Buyurtmani bekor qilish',
      message: 'Buyurtmani bekor qilmoqchimisiz?',
      confirmLabel: 'Bekor qilish',
      cancelLabel: 'Orqaga',
      danger: true,
    );
    if (!ok) return;
    if (await ref.read(orderDetailProvider(id).notifier).cancel()) showSnack('Buyurtma bekor qilindi.');
  }
}

/// `Yangi → Tasdiqlangan → Tayyorlanmoqda → Tayyor → Topshirildi`, the current step highlighted.
class OrderProgress extends StatelessWidget {
  const OrderProgress({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = kOrderSteps.indexOf(status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BzSpace.s, vertical: BzSpace.l),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < kOrderSteps.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current ? scheme.primary : scheme.surfaceContainerHighest,
                      ),
                      child: i < current
                          ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                          : i == current
                          ? Icon(Icons.circle, size: 8, color: scheme.onPrimary)
                          : null,
                    ),
                    const SizedBox(height: BzSpace.xs),
                    Text(
                      orderStatusLabel(kOrderSteps[i]),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: i <= current ? scheme.primary : scheme.onSurfaceVariant,
                        fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
