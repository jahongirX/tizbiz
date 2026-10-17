import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/data/directory_providers.dart';
import 'package:bizcat/features/home/home_widgets.dart';
import 'package:bizcat/features/home/providers.dart';
import 'package:bizcat/shared/widgets/business_cards.dart';
import 'package:bizcat/shared/widgets/section_header.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The Asosiy tab (BIZCAT-SPEC §9.3).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Re-fetches every home section; individual failures stay on screen as their own states.
  static Future<void> refresh(WidgetRef ref) async {
    final city = ref.read(cityProvider);
    Future<void> quiet(Future<Object?> f) => f.then<void>((_) {}, onError: (Object _) {});
    await Future.wait([
      quiet(ref.refresh(categoriesProvider.future)),
      quiet(ref.refresh(businessListProvider(homeFeaturedQuery(city)).future)),
      quiet(ref.refresh(businessListProvider(homeTopRatedQuery(city)).future)),
      quiet(ref.refresh(nextAppointmentProvider.future)),
      quiet(ref.refresh(revisitProvider.future)),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(cityProvider);
    final consumer = ref.watch(currentConsumerProvider);
    final signedIn = consumer != null;
    final categories = ref.watch(categoriesProvider);
    final featured = ref.watch(homeFeaturedProvider);
    final topRated = ref.watch(homeTopRatedProvider);
    final nextAsync = ref.watch(nextAppointmentProvider);
    final revisitAsync = ref.watch(revisitProvider);

    bool offline(AsyncValue<Object?> v) => v.hasError && !v.hasValue && isOffline(v.error!);
    final allOffline = offline(categories) && offline(featured) && offline(topRated);

    final next = nextAsync.hasError ? null : nextAsync.value;
    final revisit = revisitAsync.hasError ? const <RevisitItem>[] : (revisitAsync.value ?? const <RevisitItem>[]);
    final featuredItems = featured.hasError ? null : featured.value?.items;
    final topItems = topRated.hasError ? null : topRated.value?.items;
    final noBusinesses = featuredItems != null && topItems != null && featuredItems.isEmpty && topItems.isEmpty;

    final slivers = <Widget>[
      SliverToBoxAdapter(child: HomeTopBar(city: city)),
      SliverToBoxAdapter(child: HomeGreeting(firstName: _firstName(consumer?.name))),
      const SliverToBoxAdapter(child: HomeSearchBar()),
      if (allOffline)
        SliverFillRemaining(
          hasScrollBody: false,
          child: OfflineState(onRetry: () => unawaited(refresh(ref))),
        )
      else ...[
        if (signedIn && next != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.xl, BzSpace.gutter, 0),
            sliver: SliverToBoxAdapter(child: NextBookingCard(appointment: next)),
          ),
        if (noBusinesses)
          SliverToBoxAdapter(child: _NoBusinesses(city: city))
        else ...[
          _section(const SectionHeader(title: 'Kategoriyalar')),
          _categories(context, ref, categories),
        ],
        if (signedIn && revisit.isNotEmpty) ...[
          _section(const SectionHeader(title: 'Siz borgan joylar')),
          SliverToBoxAdapter(
            child: HomeCarousel(
              equalHeight: true,
              children: [for (final r in revisit) RevisitCard(item: r)],
            ),
          ),
        ],
        if (!noBusinesses) ...[
          ..._featured(context, ref, featured),
          ..._topRated(context, ref, topRated),
        ],
        if (!signedIn)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.xxl, BzSpace.gutter, 0),
            sliver: SliverToBoxAdapter(
              child: HomeLoginCard(
                onLogin: () => unawaited(context.push(AppRoutes.loginWith(from: AppRoutes.home))),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: BzSpace.xxxl)),
      ],
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => refresh(ref),
          child: CustomScrollView(
            key: const Key('home-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: slivers,
          ),
        ),
      ),
    );
  }

  static String? _firstName(String? name) {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    return n.split(RegExp(r'\s+')).first;
  }

  static Widget _section(Widget header) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.xl, BzSpace.s, BzSpace.s),
        sliver: SliverToBoxAdapter(child: header),
      );

  /// A sliver: the grid, its skeleton (which brings its own gutter) or a compact error.
  Widget _categories(BuildContext context, WidgetRef ref, AsyncValue<List<Category>> async) {
    final all = async.hasError ? null : async.value;
    if (all == null && !async.hasError) {
      return const SliverToBoxAdapter(child: LoadingView(kind: LoadingKind.grid, rows: 6));
    }
    final theme = Theme.of(context);
    final Widget child;
    if (all == null) {
      child = HomeInlineError(
        message: errorText(async.error!),
        onRetry: () => ref.invalidate(categoriesProvider),
      );
    } else {
      final visible = HomeCategoryGrid.visible(all);
      child = visible.isEmpty
          ? Text(
              "Kategoriyalar hozircha yo'q.",
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          : HomeCategoryGrid(
              categories: visible,
              onTap: (c) => context.go(AppRoutes.exploreWith(category: c.key)),
            );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter),
      sliver: SliverToBoxAdapter(child: child),
    );
  }

  List<Widget> _featured(BuildContext context, WidgetRef ref, AsyncValue<Paged<BusinessCard>> async) {
    final items = async.hasError ? null : async.value?.items;
    if (items != null && items.isEmpty) return const [];
    final header = _section(SectionHeader(
      title: 'Tavsiya etilgan',
      actionLabel: 'Hammasi',
      onAction: () => context.go(AppRoutes.exploreWith(sort: 'featured')),
    ));
    final Widget body;
    if (async.hasError && !async.hasValue) {
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter),
        child: HomeInlineError(
          message: errorText(async.error!),
          onRetry: () => ref.invalidate(businessListProvider(homeFeaturedQuery(ref.read(cityProvider)))),
        ),
      );
    } else if (items == null) {
      body = const _CarouselSkeleton();
    } else {
      body = HomeCarousel(children: [for (final c in items) BusinessCardCompact(card: c)]);
    }
    return [header, SliverToBoxAdapter(child: body)];
  }

  List<Widget> _topRated(BuildContext context, WidgetRef ref, AsyncValue<Paged<BusinessCard>> async) {
    final items = async.hasError ? null : async.value?.items;
    if (items != null && items.isEmpty) return const [];
    final header = _section(SectionHeader(
      title: 'Eng yuqori baholangan',
      actionLabel: 'Hammasi',
      onAction: () => context.go(AppRoutes.exploreWith(sort: 'rating')),
    ));
    if (async.hasError && !async.hasValue) {
      return [
        header,
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter),
          sliver: SliverToBoxAdapter(
            child: HomeInlineError(
              message: errorText(async.error!),
              onRetry: () => ref.invalidate(businessListProvider(homeTopRatedQuery(ref.read(cityProvider)))),
            ),
          ),
        ),
      ];
    }
    if (items == null) {
      return [header, const SliverToBoxAdapter(child: LoadingView(kind: LoadingKind.cards, rows: 2))];
    }
    final shown = items.length > 5 ? items.sublist(0, 5) : items;
    return [
      header,
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter),
        sliver: SliverList.separated(
          itemCount: shown.length,
          itemBuilder: (_, i) => BusinessCardTile(card: shown[i]),
          separatorBuilder: (_, _) => const SizedBox(height: BzSpace.m),
        ),
      ),
    ];
  }
}

/// No business in the selected city.
class _NoBusinesses extends ConsumerWidget {
  const _NoBusinesses({required this.city});

  final String? city;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: BzSpace.l),
      child: EmptyState(
        icon: Icons.storefront_outlined,
        title: "Bu shaharda hali bizneslar yo'q",
        message: city == null ? "Tez orada yangi bizneslar qo'shiladi." : null,
        actionLabel: city == null ? null : "Barcha shaharlarda ko'rish",
        onAction: city == null ? null : () => unawaited(ref.read(cityProvider.notifier).set(null)),
      ),
    );
  }
}

/// Placeholder boxes in the featured carousel's shape.
class _CarouselSkeleton extends StatelessWidget {
  const _CarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: NeverScrollableScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 256, child: LoadingView(kind: LoadingKind.cards, rows: 1)),
          SizedBox(width: 256, child: LoadingView(kind: LoadingKind.cards, rows: 1)),
        ],
      ),
    );
  }
}
