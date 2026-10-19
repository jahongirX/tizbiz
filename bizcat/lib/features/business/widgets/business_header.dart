import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/favorites.dart';
import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/features/business/providers.dart';
import 'package:bizcat/features/business/widgets/branches_card.dart';
import 'package:bizcat/shared/widgets/business_cards.dart';
import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/shared/widgets/nav.dart';
import 'package:bizcat/shared/widgets/rating.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The cover of the SliverAppBar: BizCover with the logo on its bottom-left corner; when the bar
/// collapses the cover fades into a plain bar with the business name.
class BusinessCoverSpace extends StatelessWidget {
  const BusinessCoverSpace({super.key, required this.business});

  final BusinessDetail business;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = business.card;
    final topInset = MediaQuery.paddingOf(context).top;
    return LayoutBuilder(
      builder: (context, c) {
        final collapsedHeight = kToolbarHeight + topInset;
        final range = 120.0;
        final t = ((c.maxHeight - collapsedHeight) / range).clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            BizCover(url: card.cover, brandColor: card.brandColor, aspectRatio: null),
            Positioned(
              left: BzSpace.gutter,
              bottom: BzSpace.l,
              child: Opacity(
                opacity: t,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: BzColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: BizLogo(url: card.logo, name: card.name, size: 64, brandColor: card.brandColor),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Opacity(
                opacity: 1 - t,
                child: ColoredBox(
                  color: scheme.surface,
                  child: Padding(
                    padding: EdgeInsets.only(top: topInset, left: 64, right: 64),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        card.name,
                        style: theme.textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A round white icon button that stays readable on the cover and on the collapsed bar.
class CoverIconButton extends StatelessWidget {
  const CoverIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(backgroundColor: BzColors.white, foregroundColor: scheme.primary),
    );
  }
}

/// Name, category, tagline, the rating badge (tap -> reviews tab), the actions, the address and
/// today's hours.
class BusinessHeaderBlock extends StatelessWidget {
  const BusinessHeaderBlock({super.key, required this.page, required this.onRatingTap, this.onBranchesTap});

  final BusinessPage page;
  final VoidCallback onRatingTap;

  /// Opens the tab that lists the branches.
  final VoidCallback? onBranchesTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = page.business;
    final card = b.card;
    final tagline = card.tagline?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.l, BzSpace.gutter, BzSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.name, style: theme.textTheme.headlineSmall),
          if ((card.categoryLabel ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(card.categoryLabel!, style: theme.textTheme.bodySmall),
          ],
          if (tagline.isNotEmpty) ...[
            const SizedBox(height: BzSpace.s),
            Text(tagline, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: BzSpace.m),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(BzRadius.pill),
                onTap: onRatingTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outline),
                    borderRadius: BorderRadius.circular(BzRadius.pill),
                  ),
                  child: RatingBadge(
                    avg: page.rating.count > 0 ? page.rating.avg : card.ratingAvg,
                    count: _count(page),
                  ),
                ),
              ),
              if (card.isFeatured) ...[const SizedBox(width: BzSpace.s), const FeaturedChip()],
              if (card.branches.isNotEmpty) ...[
                const SizedBox(width: BzSpace.s),
                ActionChip(
                  key: const Key('business-branches-chip'),
                  avatar: Icon(BzIcons.location, size: 16, color: scheme.primary),
                  label: Text('${card.branches.length} ta filial'),
                  onPressed: onBranchesTap,
                ),
              ],
            ],
          ),
          if (!card.isClaimed) ...[const SizedBox(height: BzSpace.m), const UnclaimedNote()],
          const SizedBox(height: BzSpace.l),
          BusinessActionRow(page: page),
          if ((card.address ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: BzSpace.m),
            BusinessAddressRow(business: b),
          ],
          if (b.hours.isNotEmpty) ...[
            const SizedBox(height: BzSpace.xs),
            BusinessHoursRow(hours: b.hours, timezone: b.timezone),
          ],
        ],
      ),
    );
  }

  static int _count(BusinessPage p) => p.rating.count > 0 ? p.rating.count : p.business.card.ratingCount;
}

/// `Qo'ng'iroq`, `Xarita`, `Telegram`, `Sevimli`; each is hidden when its target is missing.
class BusinessActionRow extends ConsumerWidget {
  const BusinessActionRow({super.key, required this.page});

  final BusinessPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = page.business;
    final card = b.card;
    final fav = ref.watch(favoritesProvider);
    final isFav = fav.loaded ? fav.contains(card.id) : page.isFavorite;
    final hasPhone = Phone.telUri(b.phone) != null;
    final hasMap = hasMapTarget(mapUrl: b.mapUrl, lat: card.lat, lng: card.lng, name: card.name, address: card.address);
    final telegram = b.telegramBotUsername?.trim() ?? '';

    void toggleFavorite() {
      if (!ref.read(isSignedInProvider)) {
        unawaited(context.push(AppRoutes.loginWith(from: currentLocation(context))));
        return;
      }
      unawaited(ref.read(favoritesProvider.notifier).toggle(card, current: isFav));
    }

    final buttons = <Widget>[
      if (hasPhone)
        _ActionButton(icon: BzIcons.call, label: "Qo'ng'iroq", onTap: () => unawaited(callPhone(ref, b.phone))),
      if (hasMap)
        _ActionButton(
          icon: BzIcons.map,
          label: 'Xarita',
          onTap: () => unawaited(
            openMap(ref, mapUrl: b.mapUrl, lat: card.lat, lng: card.lng, name: card.name, address: card.address),
          ),
        ),
      if (telegram.isNotEmpty)
        _ActionButton(icon: BzIcons.send, label: 'Telegram', onTap: () => unawaited(openTelegram(ref, telegram))),
      _ActionButton(
        icon: isFav ? BzIcons.heartBold : BzIcons.heart,
        label: 'Sevimli',
        selected: isFav,
        onTap: toggleFavorite,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: BzSpace.s),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.selected = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 64),
        padding: const EdgeInsets.symmetric(horizontal: BzSpace.xs, vertical: BzSpace.s),
        backgroundColor: selected ? scheme.primaryContainer : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BzRadius.m)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: BzSpace.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Map pin + address (+ `district, city`) and a trailing `Xaritada ochish`.
class BusinessAddressRow extends ConsumerWidget {
  const BusinessAddressRow({super.key, required this.business});

  final BusinessDetail business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = business.card;
    final place = [card.district, card.city].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
    final canMap = hasMapTarget(
      mapUrl: business.mapUrl,
      lat: card.lat,
      lng: card.lng,
      name: card.name,
      address: card.address,
    );
    return Row(
      children: [
        // The map pin is one of the two places the brand's accent color is allowed (secondary).
        Icon(BzIcons.locationBold, color: scheme.secondary, size: 22),
        const SizedBox(width: BzSpace.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.address!.trim(), style: theme.textTheme.bodyMedium),
              if (place.isNotEmpty) Text(place, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        if (canMap)
          TextButton(
            onPressed: () => unawaited(
              openMap(
                ref,
                mapUrl: business.mapUrl,
                lat: card.lat,
                lng: card.lng,
                name: card.name,
                address: card.address,
              ),
            ),
            child: const Text('Xaritada ochish'),
          ),
      ],
    );
  }
}

/// `Bugun: 09:00–21:00`; a tap expands all 7 weekdays.
class BusinessHoursRow extends StatefulWidget {
  const BusinessHoursRow({super.key, required this.hours, required this.timezone});

  final List<OpeningHours> hours;
  final String timezone;

  @override
  State<BusinessHoursRow> createState() => _BusinessHoursRowState();
}

class _BusinessHoursRowState extends State<BusinessHoursRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = Dates.todayLocal(timezone: widget.timezone).weekday;
    final label = todayHoursLabel(widget.hours, today);
    if (label == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(BzRadius.s),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: BzSpace.s),
            child: Row(
              children: [
                Icon(BzIcons.clock, color: scheme.primary, size: 22),
                const SizedBox(width: BzSpace.s),
                Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
                Icon(_expanded ? BzIcons.expandLess : BzIcons.expandMore, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 30, bottom: BzSpace.s),
                  child: WeeklyHoursTable(hours: widget.hours, today: today),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Monday..Sunday with `09:00–21:00` or `Dam olish kuni`; today in bold.
class WeeklyHoursTable extends StatelessWidget {
  const WeeklyHoursTable({super.key, required this.hours, required this.today});

  final List<OpeningHours> hours;

  /// ISO weekday of today (business-local).
  final int today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        for (var d = 1; d <= 7; d++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    UzDates.weekdayLong(d),
                    style: d == today
                        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
                        : theme.textTheme.bodyMedium,
                  ),
                ),
                Builder(
                  builder: (context) {
                    final h = hoursFor(hours, d);
                    final style = d == today
                        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
                        : theme.textTheme.bodyMedium;
                    return Text(
                      h == null ? 'Dam olish kuni' : hoursRange(h),
                      style: h == null ? style?.copyWith(color: scheme.onSurfaceVariant) : style,
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
