import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/booking_flow.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/data/directory_providers.dart';
import 'package:bizcat/data/storefront_providers.dart';
import 'package:bizcat/features/business/providers.dart';
import 'package:bizcat/features/business/widgets/business_header.dart';
import 'package:bizcat/features/business/widgets/business_tabs.dart';
import 'package:bizcat/shared/widgets/bottom_bar.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/favorite_button.dart';
import 'package:bizcat/shared/widgets/nav.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The business page: cover, header, actions, address, hours and the three tabs
/// (offerings / reviews / info) with the booking CTA at the bottom.
class BusinessScreen extends ConsumerWidget {
  const BusinessScreen({super.key, required this.slug, this.tab});

  final String slug;
  final String? tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(businessPageProvider(slug));
    void retry() => ref.invalidate(businessPageProvider(slug));

    if (page.hasValue) {
      return _BusinessView(slug: slug, tab: tab, page: page.requireValue);
    }

    final Widget body;
    if (page.hasError && !page.isLoading) {
      final e = page.error!;
      if (e is ApiException && e.isNotFound) {
        body = EmptyState(
          icon: BzIcons.shop,
          title: 'Biznes topilmadi',
          message: "Bu sahifa o'chirilgan yoki manzil noto'g'ri.",
          actionLabel: 'Katalogga qaytish',
          onAction: () => context.go(AppRoutes.explore),
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
        leading: BackButton(onPressed: () => popOrGo(context)),
        title: const Text('Biznes'),
      ),
      body: body,
    );
  }
}

class _BusinessView extends ConsumerStatefulWidget {
  const _BusinessView({required this.slug, required this.tab, required this.page});

  final String slug;
  final String? tab;
  final BusinessPage page;

  @override
  ConsumerState<_BusinessView> createState() => _BusinessViewState();
}

class _BusinessViewState extends ConsumerState<_BusinessView> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: businessTabIndex(widget.tab));

  @override
  void didUpdateWidget(_BusinessView old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) _tabs.animateTo(businessTabIndex(widget.tab));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(storefrontProvider(widget.slug))
      ..invalidate(businessPageProvider(widget.slug));
    try {
      await ref.read(businessPageProvider(widget.slug).future);
    } on Object {
      // The error is shown by the page itself.
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final card = page.business.card;
    final storefront = ref.watch(storefrontProvider(widget.slug));
    final engine = storefront.value?.engine ?? card.engine;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            backgroundColor: scheme.surface,
            surfaceTintColor: scheme.surface,
            automaticallyImplyLeading: false,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: CoverIconButton(icon: BzIcons.back, tooltip: 'Orqaga', onPressed: () => popOrGo(context)),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FavoriteButton(businessId: card.id, initial: page.isFavorite, card: card, onImage: true),
              ),
            ],
            flexibleSpace: BusinessCoverSpace(business: page.business),
          ),
          SliverToBoxAdapter(
            child: BusinessHeaderBlock(
              page: page,
              onRatingTap: () => _tabs.animateTo(1),
              onBranchesTap: () => _tabs.animateTo(2),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: BusinessTabBarDelegate(
              TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: engine.servicesTerm),
                  const Tab(text: 'Sharhlar'),
                  const Tab(text: "Ma'lumot"),
                ],
              ),
              background: scheme.surface,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            OfferingsTab(slug: widget.slug, onRefresh: _refresh),
            ReviewsPreviewTab(slug: widget.slug, page: page, onRefresh: _refresh),
            InfoTab(page: page, onRefresh: _refresh),
          ],
        ),
      ),
      bottomNavigationBar: _BookingBar(slug: widget.slug, page: page, storefront: storefront),
    );
  }
}

/// The CTA bar: `ctaLabelFor(flow, engine)` or, when online booking is closed, the muted note
/// plus a call button.
class _BookingBar extends ConsumerWidget {
  const _BookingBar({required this.slug, required this.page, required this.storefront});

  final String slug;
  final BusinessPage page;
  final AsyncValue<StorefrontData> storefront;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final card = page.business.card;
    final data = storefront.value;

    if (data == null) {
      final flow = bookingFlowForEngine(card.engine);
      final failed = storefront.hasError && !storefront.isLoading;
      return BottomActionBar(
        child: CtaButton(
          label: ctaLabelFor(flow, card.engine),
          loading: !failed,
          // The flow screens load the storefront themselves and show their own errors.
          onPressed: failed ? () => unawaited(context.push(bookingEntryPath(slug, flow))) : null,
        ),
      );
    }

    if (!canBookOnline(data)) {
      final phone = data.business.phone ?? page.business.phone;
      final hasPhone = Phone.telUri(phone) != null;
      return BottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              card.isClaimed ? 'Onlayn yozilish vaqtincha yopiq' : "Bu biznes hali onlayn bron qabul qilmaydi",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (hasPhone) ...[
              const SizedBox(height: 8),
              PrimaryButton(
                label: "Qo'ng'iroq qilish",
                icon: BzIcons.call,
                onPressed: () => unawaited(callPhone(ref, phone)),
              ),
            ],
          ],
        ),
      );
    }

    final flow = bookingFlowFor(data);
    return BottomActionBar(
      child: CtaButton(
        label: ctaLabelFor(flow, data.engine),
        onPressed: () => unawaited(context.push(bookingEntryPath(slug, flow))),
      ),
    );
  }
}
