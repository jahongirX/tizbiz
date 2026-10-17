import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/features/bookings/providers.dart';
import 'package:bizcat/features/bookings/widgets.dart';
import 'package:bizcat/shared/widgets/login_prompt.dart';
import 'package:bizcat/shared/widgets/poller.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Bronlarim": appointments (upcoming / past) and orders (active / history).
class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key, this.tab});

  /// `orders` opens the orders segment; anything else the appointments.
  final String? tab;

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  late bool _orders = widget.tab == 'orders';

  @override
  void didUpdateWidget(MyBookingsScreen old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) _orders = widget.tab == 'orders';
  }

  void _refreshAll() {
    for (final s in ApptScope.values) {
      ref.invalidate(myAppointmentsProvider(s));
    }
    for (final s in OrderScope.values) {
      ref.invalidate(myOrdersProvider(s));
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(isSignedInProvider);
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bronlarim')),
        body: const LoginPromptView(
          icon: Icons.event_note_outlined,
          title: 'Bronlaringiz shu yerda',
          message: "Navbat va buyurtmalaringizni ko'rish uchun kiring.",
          from: AppRoutes.bookings,
        ),
      );
    }

    return Poller(
      interval: const Duration(minutes: 5),
      refreshOnResume: true,
      onTick: _refreshAll,
      child: Scaffold(
        appBar: AppBar(title: const Text('Bronlarim')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.s, BzSpace.gutter, 0),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Bronlar'), icon: Icon(Icons.event_outlined)),
                    ButtonSegment(value: true, label: Text('Buyurtmalar'), icon: Icon(Icons.receipt_long_outlined)),
                  ],
                  selected: {_orders},
                  onSelectionChanged: (v) => setState(() => _orders = v.first),
                ),
              ),
            ),
            Expanded(
              child: _orders
                  ? const _ScopedTabs(
                      key: ValueKey('orders'),
                      labels: ['Faol', 'Tarix'],
                      children: [_OrdersList(OrderScope.active), _OrdersList(OrderScope.past)],
                    )
                  : const _ScopedTabs(
                      key: ValueKey('appointments'),
                      labels: ['Kelgusi', "O'tgan"],
                      children: [_AppointmentsList(ApptScope.upcoming), _AppointmentsList(ApptScope.past)],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopedTabs extends StatelessWidget {
  const _ScopedTabs({super.key, required this.labels, required this.children});

  final List<String> labels;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: labels.length,
    child: Column(
      children: [
        TabBar(tabs: [for (final l in labels) Tab(text: l)]),
        Expanded(child: TabBarView(children: children)),
      ],
    ),
  );
}

/// A paged, pull-to-refreshable list with its loading / error / empty states.
class _PagedList<T> extends StatelessWidget {
  const _PagedList({
    required this.value,
    required this.onRefresh,
    required this.onRetry,
    required this.onLoadMore,
    required this.empty,
    required this.itemBuilder,
  });

  final AsyncValue<PagedState<T>> value;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final Widget empty;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final data = value.value;
    final List<Widget> children;
    if (data != null) {
      children = data.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.only(top: BzSpace.xxl),
                child: empty,
              ),
            ]
          : [
              for (final item in data.items) ...[itemBuilder(item), const SizedBox(height: BzSpace.m)],
              if (data.loadingMore)
                const Padding(
                  padding: EdgeInsets.all(BzSpace.l),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (data.moreError != null)
                Column(
                  children: [
                    Text(errorText(data.moreError!), textAlign: TextAlign.center),
                    TextButton(onPressed: onLoadMore, child: const Text('Qayta urinish')),
                  ],
                ),
            ];
    } else if (value.hasError && !value.isLoading) {
      final e = value.error!;
      children = [isOffline(e) ? OfflineState(onRetry: onRetry) : ErrorState(message: errorText(e), onRetry: onRetry)];
    } else {
      children = const [LoadingView(kind: LoadingKind.cards, rows: 3)];
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (data != null && data.hasMore && data.moreError == null && n.metrics.extentAfter < 400) onLoadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.l, BzSpace.gutter, BzSpace.xxl),
          children: children,
        ),
      ),
    );
  }
}

class _AppointmentsList extends ConsumerWidget {
  const _AppointmentsList(this.scope);

  final ApptScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = myAppointmentsProvider(scope);
    final past = scope == ApptScope.past;
    return _PagedList<Appointment>(
      value: ref.watch(provider),
      onRefresh: () async {
        ref.invalidate(provider);
        try {
          await ref.read(provider.future);
        } on Object {
          // Shown by the list.
        }
      },
      onRetry: () => ref.invalidate(provider),
      onLoadMore: () => unawaited(ref.read(provider.notifier).loadMore()),
      empty: past
          ? const EmptyState(icon: Icons.history, title: "O'tgan bronlar yo'q")
          : EmptyState(
              icon: Icons.event_available,
              title: "Kelgusi bronlar yo'q",
              message: 'Katalogdan biznes tanlab, navbatga yoziling.',
              actionLabel: 'Katalogni ochish',
              onAction: () => context.go(AppRoutes.explore),
            ),
      itemBuilder: (a) => AppointmentCard(appointment: a, past: past),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList(this.scope);

  final OrderScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = myOrdersProvider(scope);
    final past = scope == OrderScope.past;
    return _PagedList<Order>(
      value: ref.watch(provider),
      onRefresh: () async {
        ref.invalidate(provider);
        try {
          await ref.read(provider.future);
        } on Object {
          // Shown by the list.
        }
      },
      onRetry: () => ref.invalidate(provider),
      onLoadMore: () => unawaited(ref.read(provider.notifier).loadMore()),
      empty: past
          ? const EmptyState(icon: Icons.receipt_long_outlined, title: "Buyurtmalar tarixi bo'sh")
          : const EmptyState(icon: Icons.shopping_bag_outlined, title: "Faol buyurtmalar yo'q"),
      itemBuilder: (o) => OrderCard(order: o, past: past),
    );
  }
}
