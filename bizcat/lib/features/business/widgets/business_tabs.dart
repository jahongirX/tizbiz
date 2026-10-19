import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/booking_flow.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/core/rental_pricing.dart';
import 'package:bizcat/data/storefront_providers.dart';
import 'package:bizcat/features/business/providers.dart';
import 'package:bizcat/features/business/widgets/branches_card.dart';
import 'package:bizcat/features/business/widgets/business_header.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/shared/widgets/location_card.dart';
import 'package:bizcat/shared/widgets/rating.dart';
import 'package:bizcat/shared/widgets/review_tile.dart';
import 'package:bizcat/shared/widgets/section_header.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The pinned TabBar under the header.
class BusinessTabBarDelegate extends SliverPersistentHeaderDelegate {
  BusinessTabBarDelegate(this.tabBar, {required this.background});

  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: background, child: tabBar);

  @override
  bool shouldRebuild(BusinessTabBarDelegate old) => old.tabBar != tabBar || old.background != background;
}

/// A pull-to-refresh list with the page gutter, used by every tab.
class _TabList extends StatelessWidget {
  const _TabList({required this.storageKey, required this.onRefresh, required this.children});

  final String storageKey;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      key: PageStorageKey(storageKey),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.l, BzSpace.gutter, BzSpace.xxl),
      children: children,
    ),
  );
}

class _MutedNote extends StatelessWidget {
  const _MutedNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant));
  }
}

// ---------------------------------------------------------------------------------------------
// Offerings
// ---------------------------------------------------------------------------------------------

/// Services + staff (slot), the two sessions (rental) or the menu preview (catalog).
class OfferingsTab extends ConsumerWidget {
  const OfferingsTab({super.key, required this.slug, required this.onRefresh});

  final String slug;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storefront = ref.watch(storefrontProvider(slug));
    void retry() => ref.invalidate(storefrontProvider(slug));
    final data = storefront.value;
    final List<Widget> children;
    if (data != null) {
      children = switch (bookingFlowFor(data)) {
        BookingFlow.slot => _slot(context, data),
        BookingFlow.rental => _rental(context),
        BookingFlow.catalog => _catalog(context, data),
      };
    } else if (storefront.hasError && !storefront.isLoading) {
      final e = storefront.error!;
      children = [isOffline(e) ? OfflineState(onRetry: retry) : ErrorState(message: errorText(e), onRetry: retry)];
    } else {
      children = const [LoadingView(rows: 4)];
    }
    // States live inside the scrollable so they never overflow the short tab body.
    return _TabList(storageKey: 'offer', onRefresh: onRefresh, children: children);
  }

  List<Widget> _slot(BuildContext context, StorefrontData data) {
    final services = bookableServices(data);
    final staff = [
      for (final m in data.staff)
        if (m.isActive) m,
    ];
    return [
      if (services.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: BzSpace.xxl),
          child: _MutedNote("Hozircha onlayn yozilish uchun xizmatlar yo'q."),
        )
      else
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < services.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ServiceRow(
                  service: services[i],
                  onTap: () => unawaited(context.push(AppRoutes.bookSlot(slug, serviceId: services[i].id))),
                ),
              ],
            ],
          ),
        ),
      if (services.isNotEmpty && staff.isNotEmpty) ...[
        const SizedBox(height: BzSpace.xl),
        SectionHeader(title: data.engine.staffTerm),
        const SizedBox(height: BzSpace.s),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: staff.length,
            separatorBuilder: (_, _) => const SizedBox(width: BzSpace.m),
            itemBuilder: (context, i) => StaffAvatar(
              staff: staff[i],
              onTap: () => unawaited(context.push(AppRoutes.bookSlot(slug, staffId: staff[i].id))),
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _rental(BuildContext context) => [
    for (final s in RentalSession.values) ...[
      RentalSessionCard(session: s, onTap: () => unawaited(context.push(AppRoutes.bookRental(slug)))),
      const SizedBox(height: BzSpace.m),
    ],
    const _MutedNote('Narx taxminiy: yakuniy narx menyu va xizmatlarga qarab belgilanadi.'),
  ];

  List<Widget> _catalog(BuildContext context, StorefrontData data) {
    final all = catalogItems(data);
    if (all.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: BzSpace.xxl),
          child: _MutedNote('Menyu hali bo\'sh.'),
        ),
      ];
    }
    final groups = <(String?, List<Service>)>[
      for (final c in data.categories)
        if (c.items.isNotEmpty) (c.name, c.items),
    ];
    if (groups.isEmpty) groups.add((null, all));
    return [
      for (final (name, items) in groups) ...[
        if (name != null) ...[SectionHeader(title: name), const SizedBox(height: BzSpace.s)],
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length && i < 3; i++) ...[
                if (i > 0) const Divider(height: 1),
                CatalogItemRow(item: items[i], onTap: () => unawaited(context.push(AppRoutes.menu(slug)))),
              ],
            ],
          ),
        ),
        const SizedBox(height: BzSpace.l),
      ],
      SecondaryButton(
        label: "Hammasini ko'rish (${all.length})",
        icon: BzIcons.menuBoard,
        onPressed: () => unawaited(context.push(AppRoutes.menu(slug))),
      ),
    ];
  }
}

/// A bookable service: name, duration, price and the deposit chip.
class ServiceRow extends StatelessWidget {
  const ServiceRow({super.key, required this.service, required this.onTap});

  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = service;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(BzSpace.l),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    UzDates.duration(s.durationMin),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (s.requiresDeposit) ...[
                    const SizedBox(height: BzSpace.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: BzSpace.s, vertical: 2),
                      decoration: BoxDecoration(
                        color: BzColors.warningBg,
                        borderRadius: BorderRadius.circular(BzRadius.pill),
                      ),
                      child: Text(
                        "Oldindan to'lov: ${Money.format(s.depositTiyin)}",
                        style: theme.textTheme.labelSmall?.copyWith(color: BzColors.warning),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: BzSpace.m),
            Text(
              Money.format(s.priceTiyin),
              style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: BzSpace.xs),
            Icon(BzIcons.chevronRight, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// A staff member in the horizontal row.
class StaffAvatar extends StatelessWidget {
  const StaffAvatar({super.key, required this.staff, required this.onTap});

  final Staff staff;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BzRadius.m),
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            const SizedBox(height: BzSpace.xs),
            BizLogo(name: staff.name, size: 56),
            const SizedBox(height: BzSpace.s),
            Text(
              staff.name,
              style: theme.textTheme.labelLarge,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if ((staff.specialization ?? '').isNotEmpty)
              Text(
                staff.specialization!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

/// `Ertalab` / `Kechqurun` with the hours and the per-guest price.
class RentalSessionCard extends StatelessWidget {
  const RentalSessionCard({super.key, required this.session, required this.onTap});

  final RentalSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BzSpace.l),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(BzRadius.m),
                ),
                child: Icon(session == RentalSession.morning ? BzIcons.sun : BzIcons.moon, color: scheme.primary),
              ),
              const SizedBox(width: BzSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(RentalPricing.title(session), style: theme.textTheme.titleMedium),
                    Text(
                      RentalPricing.subtitle(session),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                '${Money.format(RentalPricing.perGuestTiyin(session))} / kishi',
                style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A catalog item row: 56 px image, name, price.
class CatalogItemRow extends StatelessWidget {
  const CatalogItemRow({super.key, required this.item, required this.onTap});

  final Service item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(BzSpace.m),
        child: Row(
          children: [
            NetImage(url: item.image, width: 56, height: 56, radius: BorderRadius.circular(BzRadius.s)),
            const SizedBox(width: BzSpace.m),
            Expanded(
              child: Text(item.name, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: BzSpace.s),
            Text(
              Money.format(item.priceTiyin),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Reviews preview
// ---------------------------------------------------------------------------------------------

const String _reviewHint = 'Sharhni tashrifdan keyin "Bronlarim" bo\'limidan qoldirishingiz mumkin.';

/// Rating summary, the first 3 reviews and the link to all of them.
class ReviewsPreviewTab extends StatelessWidget {
  const ReviewsPreviewTab({super.key, required this.slug, required this.page, required this.onRefresh});

  final String slug;
  final BusinessPage page;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final reviews = page.reviewsPreview;
    final count = page.rating.count > 0 ? page.rating.count : page.business.card.ratingCount;
    if (reviews.isEmpty && count == 0) {
      return _TabList(
        storageKey: 'reviews',
        onRefresh: onRefresh,
        children: const [
          EmptyState(icon: BzIcons.review, title: "Hali sharhlar yo'q"),
          SizedBox(height: BzSpace.s),
          Center(child: _MutedNote(_reviewHint)),
        ],
      );
    }
    return _TabList(
      storageKey: 'reviews',
      onRefresh: onRefresh,
      children: [
        RatingSummaryView(summary: page.rating),
        const SizedBox(height: BzSpace.l),
        for (final r in reviews.take(3)) ...[ReviewTile(review: r), const SizedBox(height: BzSpace.m)],
        PrimaryButton(
          label: 'Barcha sharhlar ($count)',
          onPressed: () => unawaited(context.push(AppRoutes.businessReviews(slug))),
        ),
        const SizedBox(height: BzSpace.m),
        const _MutedNote(_reviewHint),
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Info
// ---------------------------------------------------------------------------------------------

/// Description, location, phone and the weekly hours.
class InfoTab extends ConsumerWidget {
  const InfoTab({super.key, required this.page, required this.onRefresh});

  final BusinessPage page;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = page.business;
    final card = b.card;
    final description = b.description?.trim() ?? '';
    final hasPhone = Phone.telUri(b.phone) != null;
    return _TabList(
      storageKey: 'info',
      onRefresh: onRefresh,
      children: [
        if (description.isEmpty)
          const _MutedNote("Ma'lumot qo'shilmagan.")
        else
          Text(description, style: theme.textTheme.bodyMedium),
        const SizedBox(height: BzSpace.l),
        LocationCard(address: card.address, mapUrl: b.mapUrl, lat: card.lat, lng: card.lng, name: card.name),
        if (card.branches.isNotEmpty) ...[const SizedBox(height: BzSpace.m), BranchesCard(branches: card.branches)],
        if (hasPhone) ...[
          const SizedBox(height: BzSpace.m),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(BzIcons.call, color: scheme.primary),
              title: Text(Phone.format(b.phone)),
              subtitle: const Text('Telefon'),
              onTap: () => unawaited(callPhone(ref, b.phone)),
            ),
          ),
        ],
        if (b.hours.isNotEmpty) ...[
          const SizedBox(height: BzSpace.m),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(BzSpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ish vaqti', style: theme.textTheme.titleMedium),
                  const SizedBox(height: BzSpace.s),
                  WeeklyHoursTable(
                    hours: b.hours,
                    today: Dates.todayLocal(timezone: b.timezone).weekday,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
