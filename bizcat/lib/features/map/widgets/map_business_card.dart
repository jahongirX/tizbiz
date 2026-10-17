import 'package:bizcat/shared/widgets/business_cards.dart';
import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/shared/widgets/rating.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Height of the bottom carousel cards.
const double kMapCardHeight = 124;

/// '850 m' / '3.4 km'.
String distanceLabel(double meters) =>
    meters < 1000 ? '${(meters / 10).round() * 10} m' : '${(meters / 1000).toStringAsFixed(1)} km';

/// A bottom-carousel card: cover thumbnail, name, category, rating, place, price, distance.
/// Tapping opens the business (its catalog tab).
class MapBusinessCard extends StatelessWidget {
  const MapBusinessCard({super.key, required this.card, required this.selected, required this.onOpen, this.meters});

  final BusinessCard card;
  final bool selected;
  final VoidCallback onOpen;

  /// Distance from the consumer, when their position is known.
  final double? meters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final place = card.district ?? card.address ?? card.city;
    final price = priceFromLabel(card.priceFromTiyin);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.symmetric(horizontal: BzSpace.xs, vertical: selected ? 0 : 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(BzRadius.l),
        border: Border.all(color: selected ? BzColors.apricot : scheme.outlineVariant, width: selected ? 1.5 : 1),
        boxShadow: [
          BoxShadow(color: BzColors.indigo.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('map-card-${card.slug}'),
          borderRadius: BorderRadius.circular(BzRadius.l),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(BzSpace.s),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  height: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(BzRadius.m),
                        child: BizCover(url: card.cover, brandColor: card.brandColor, aspectRatio: 96 / 108),
                      ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: BzColors.white, width: 2),
                          ),
                          child: BizLogo(url: card.logo, name: card.name, size: 34, brandColor: card.brandColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: BzSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(card.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        [?card.categoryLabel, ?place].where((s) => s.trim().isNotEmpty).join(' · '),
                        style: muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: BzSpace.s),
                      Row(
                        children: [
                          RatingBadge(avg: card.ratingAvg, count: card.ratingCount, compact: true),
                          if (meters != null) ...[
                            const SizedBox(width: BzSpace.s),
                            Icon(Icons.near_me_outlined, size: 14, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 2),
                            Text(distanceLabel(meters!), style: muted),
                          ],
                        ],
                      ),
                      if (price != null) ...[
                        const SizedBox(height: BzSpace.xs),
                        Text(price, style: theme.textTheme.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
