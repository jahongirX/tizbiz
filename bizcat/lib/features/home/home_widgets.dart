import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/features/home/providers.dart';
import 'package:bizcat/shared/widgets/brand.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/category_icon.dart';
import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/shared/widgets/status_chips.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Brand logo left, the city pill right.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, required this.city});

  final String? city;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(BzSpace.xl, BzSpace.m, BzSpace.gutter, 0),
      child: Row(
        children: [
          const BrandLogo(width: 104),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Shahar: ${cityLabel(city)}',
            excludeSemantics: true,
            child: Material(
              color: scheme.surface,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('home-city-chip'),
                onTap: () => unawaited(context.push(AppRoutes.city)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(BzIcons.location, size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          cityLabel(city),
                          style: theme.textTheme.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(BzIcons.expandMore, size: 16, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `Salom, <firstName>!` / `Xush kelibsiz!` in a large title, plus the subtitle.
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key, required this.firstName, this.onTap});

  final String? firstName;

  /// Signed in: opens the profile (a chevron follows the name).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = firstName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(BzSpace.xl, BzSpace.xl, BzSpace.gutter, BzSpace.l),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BzRadius.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    name == null ? 'Xush kelibsiz!' : 'Salom, $name!',
                    style: theme.textTheme.headlineLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null) ...[const SizedBox(width: 6), const Icon(BzIcons.chevronRight, size: 22)],
              ],
            ),
            const SizedBox(height: BzSpace.xs),
            Text(
              'Bugun qayerga boramiz?',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// A read-only white search field that opens the catalog tab with the search focused; the map
/// icon on its right opens the map search.
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  static const hint = 'Xizmat yoki biznes qidirish';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(BzRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: hint,
                excludeSemantics: true,
                child: InkWell(
                  key: const Key('home-search'),
                  onTap: () => context.go(AppRoutes.exploreWith(focus: true)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(BzSpace.xl, 18, BzSpace.s, 18),
                    child: Row(
                      children: [
                        Icon(BzIcons.search, color: scheme.onSurfaceVariant, size: 22),
                        const SizedBox(width: BzSpace.m),
                        Expanded(
                          child: Text(
                            hint,
                            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              key: const Key('home-map'),
              tooltip: 'Xaritadan qidirish',
              icon: Icon(BzIcons.map, color: scheme.onSurface, size: 26),
              onPressed: () => unawaited(context.push(AppRoutes.map)),
            ),
            const SizedBox(width: BzSpace.s),
          ],
        ),
      ),
    );
  }
}

/// The nearest upcoming appointment: an indigo gradient card.
class NextBookingCard extends StatelessWidget {
  const NextBookingCard({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = appointment;
    final tz = a.business?.timezone;
    final when = UzDates.dateTime(a.startLocal(), today: Dates.todayLocal(timezone: tz));
    const on = BzColors.white;
    final soft = on.withValues(alpha: 0.8);

    return Container(
      key: const Key('home-next-booking'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BzRadius.card),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BzColors.indigo700, BzColors.indigo],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(BzRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(context.push(AppRoutes.appointment(a.id))),
          child: Padding(
            padding: const EdgeInsets.all(BzSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(BzIcons.calendarTick, size: 18, color: soft),
                    const SizedBox(width: BzSpace.s),
                    Expanded(
                      child: Text('Yaqin bron', style: theme.textTheme.labelLarge?.copyWith(color: soft)),
                    ),
                    AppointmentStatusChip(a.status),
                  ],
                ),
                const SizedBox(height: BzSpace.m),
                Text(
                  a.business?.name ?? '',
                  style: theme.textTheme.titleLarge?.copyWith(color: on),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (a.serviceName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    a.serviceName!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: soft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: BzSpace.l),
                Row(
                  children: [
                    const Icon(BzIcons.clock, size: 18, color: on),
                    const SizedBox(width: BzSpace.s),
                    Expanded(
                      child: Text(when, style: theme.textTheme.titleSmall?.copyWith(color: on)),
                    ),
                    const Icon(BzIcons.chevronRight, color: on, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal row of colorful category cards.
class HomeCategoryGrid extends StatelessWidget {
  const HomeCategoryGrid({super.key, required this.categories, required this.onTap});

  final List<Category> categories;
  final ValueChanged<Category> onTap;

  /// Hides empty categories, but only when at least 3 non-empty ones remain.
  static List<Category> visible(List<Category> all) {
    final nonEmpty = [
      for (final c in all)
        if (c.count > 0) c,
    ];
    return nonEmpty.length >= 3 ? nonEmpty : all;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CategoryTile.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: BzSpace.m),
        itemBuilder: (_, i) => CategoryTile(category: categories[i], index: i, onTap: () => onTap(categories[i])),
      ),
    );
  }
}

/// A 260 px card of the "Siz borgan joylar" carousel.
class RevisitCard extends StatelessWidget {
  const RevisitCard({super.key, required this.item});

  final RevisitItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = item.business;
    final tz = b.timezone;
    final last = UzDates.dayLabel(Dates.localDateOf(item.lastAt, tz), today: Dates.todayLocal(timezone: tz));
    final subtitle = item.serviceName ?? item.orderSummary;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return SizedBox(
      width: 260,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(context.push(AppRoutes.business(b.slug))),
          child: Padding(
            padding: const EdgeInsets.all(BzSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BizLogo(url: b.logo, name: b.name, size: 44, brandColor: b.brandColor),
                    const SizedBox(width: BzSpace.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: BzSpace.s),
                if (item.staffName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Icon(BzIcons.user, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: BzSpace.xs),
                        Expanded(
                          child: Text(item.staffName!, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Icon(BzIcons.history, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: BzSpace.xs),
                    Expanded(
                      child: Text('Oxirgi tashrif: $last', style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const Spacer(),
                const SizedBox(height: BzSpace.m),
                OutlinedButton.icon(
                  onPressed: () => unawaited(context.push(item.rebookPath())),
                  icon: const Icon(BzIcons.retry, size: 18),
                  label: Text(item.rebookLabel),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: BzSpace.m),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontally scrolling row whose children share the tallest child's height.
class HomeCarousel extends StatelessWidget {
  const HomeCarousel({super.key, required this.children, this.equalHeight = false});

  final List<Widget> children;
  final bool equalHeight;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: equalHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: BzSpace.m), children[i]],
      ],
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter),
      child: equalHeight ? IntrinsicHeight(child: row) : row,
    );
  }
}

/// A compact one-line error with `Qayta urinish`.
class HomeInlineError extends StatelessWidget {
  const HomeInlineError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(BzSpace.l, BzSpace.s, BzSpace.s, BzSpace.s),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(BzRadius.m),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Icon(BzIcons.danger, size: 20, color: scheme.error),
          const SizedBox(width: BzSpace.s),
          Expanded(
            child: Text(message, style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          TextButton(onPressed: onRetry, child: const Text('Qayta urinish')),
        ],
      ),
    );
  }
}

/// Signed-out invitation at the end of the page.
class HomeLoginCard extends StatelessWidget {
  const HomeLoginCard({super.key, required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(BzSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                  child: Icon(BzIcons.bookings, color: scheme.primary),
                ),
                const SizedBox(width: BzSpace.m),
                Expanded(child: Text('Bronlaringizni kuzatish uchun kiring', style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: BzSpace.s),
            Text(
              "Yaqin bronlar, buyurtmalar va bonuslaringiz shu yerda ko'rinadi.",
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: BzSpace.l),
            PrimaryButton(key: const Key('home-login'), label: 'Kirish', onPressed: onLogin),
          ],
        ),
      ),
    );
  }
}
