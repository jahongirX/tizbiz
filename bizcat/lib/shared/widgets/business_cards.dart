import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/shared/widgets/favorite_button.dart';
import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/shared/widgets/rating.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// `"<Money.format> dan"` for a card's price_from_tiyin (null when unknown).
String? priceFromLabel(int? tiyin) => tiyin == null ? null : '${Money.format(tiyin)} dan';

/// Full-width directory card: cover, overlapping logo, name, category, rating, place, price,
/// `Tavsiya` chip, closed-booking note and a favorite heart.
class BusinessCardTile extends StatelessWidget {
  const BusinessCardTile({super.key, required this.card, this.onTap, this.showFavorite = true});

  final BusinessCard card;

  /// Default: `context.push(AppRoutes.business(card.slug))`.
  final VoidCallback? onTap;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final place = card.district ?? card.address;
    final price = priceFromLabel(card.priceFromTiyin);
    const logoSize = 56.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => unawaited(context.push(AppRoutes.business(card.slug))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                BizCover(url: card.cover, brandColor: card.brandColor, aspectRatio: 2),
                if (showFavorite)
                  Positioned(
                    top: BzSpace.s,
                    right: BzSpace.s,
                    child: FavoriteButton(businessId: card.id, initial: card.isFavorite, card: card, onImage: true),
                  ),
                Positioned(
                  left: BzSpace.l,
                  bottom: -logoSize / 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(logoSize / 4 + 2),
                      border: Border.all(color: scheme.surface, width: 2),
                    ),
                    child: BizLogo(url: card.logo, name: card.name, size: logoSize, brandColor: card.brandColor),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(BzSpace.l, logoSize / 2 + BzSpace.s, BzSpace.l, BzSpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(card.name,
                            style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: BzSpace.s),
                      RatingBadge(avg: card.ratingAvg, count: card.ratingCount),
                    ],
                  ),
                  if (card.categoryLabel != null)
                    Text(card.categoryLabel!, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (place != null) ...[
                    const SizedBox(height: BzSpace.xs),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: BzSpace.xs),
                        Expanded(
                          child: Text(place, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                  if (price != null || card.isFeatured) ...[
                    const SizedBox(height: BzSpace.s),
                    Row(
                      children: [
                        if (price != null)
                          Expanded(child: Text(price, style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary)))
                        else
                          const Spacer(),
                        if (card.isFeatured) const FeaturedChip(),
                      ],
                    ),
                  ],
                  if (!card.onlineBookingEnabled) ...[
                    const SizedBox(height: BzSpace.xs),
                    Text('Onlayn yozilish yopiq', style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `Tavsiya` pill (indigo50 / indigo).
class FeaturedChip extends StatelessWidget {
  const FeaturedChip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(BzRadius.pill)),
      child: Text('Tavsiya', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onPrimaryContainer)),
    );
  }
}

/// Carousel card: 16:10 cover, name (1 line), rating, district.
class BusinessCardCompact extends StatelessWidget {
  const BusinessCardCompact({super.key, required this.card, this.onTap, this.width = 240});

  final BusinessCard card;

  /// Default: `context.push(AppRoutes.business(card.slug))`.
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = card.district ?? card.city;
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? () => unawaited(context.push(AppRoutes.business(card.slug))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              BizCover(url: card.cover, brandColor: card.brandColor, aspectRatio: 16 / 10),
              Padding(
                padding: const EdgeInsets.all(BzSpace.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: BzSpace.xs),
                    Row(
                      children: [
                        RatingBadge(avg: card.ratingAvg, count: card.ratingCount, compact: true),
                        if (place != null) ...[
                          const SizedBox(width: BzSpace.s),
                          Expanded(
                            child: Text(place, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
