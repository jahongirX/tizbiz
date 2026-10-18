import 'dart:async';

import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/shared/widgets/business_cards.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/shared/widgets/rating.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// '850 m' / '3.4 km'.
String distanceLabel(double meters) =>
    meters < 1000 ? '${(meters / 10).round() * 10} m' : '${(meters / 1000).toStringAsFixed(1)} km';

/// Google Maps directions to the business (opens the maps app on the phone).
Uri directionsUri(BusinessCard b) => Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${b.lat},${b.lng}');

/// The business card shown in a modal sheet when a placemark is tapped: cover with logo,
/// name, category, rating with the review count, address, distance, price, and two actions:
/// `Batafsil` (opens the business page) and `Yo'nalish` (directions).
class MapBusinessSheet extends ConsumerWidget {
  const MapBusinessSheet({super.key, required this.card, required this.onOpen, this.meters});

  final BusinessCard card;
  final VoidCallback onOpen;

  /// Distance from the consumer, when their position is known.
  final double? meters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final category = card.categoryLabel;
    final place = card.address ?? card.district ?? card.city;
    final price = priceFromLabel(card.priceFromTiyin);
    const logo = 64.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.m, BzSpace.gutter, BzSpace.l),
        child: Column(
          key: ValueKey('map-sheet-${card.slug}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: scheme.outline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: BzSpace.m),
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(BzRadius.xl),
                  child: BizCover(url: card.cover, brandColor: card.brandColor, aspectRatio: 2.4),
                ),
                Positioned(
                  top: BzSpace.s,
                  right: BzSpace.s,
                  child: Material(
                    color: BzColors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    child: IconButton(
                      key: const Key('map-sheet-close'),
                      tooltip: 'Yopish',
                      icon: const Icon(BzIcons.close, color: BzColors.indigo),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Positioned(
                  left: BzSpace.l,
                  bottom: -logo / 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(logo / 4 + 3),
                      border: Border.all(color: scheme.surface, width: 3),
                    ),
                    child: BizLogo(url: card.logo, name: card.name, size: logo, brandColor: card.brandColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: logo / 2 + BzSpace.m),
            Text(card.name, style: theme.textTheme.headlineSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (category != null) ...[
              const SizedBox(height: 2),
              Text(category, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: BzSpace.m),
            Row(
              children: [
                if (card.ratingCount > 0) ...[
                  RatingStars(value: card.ratingAvg, size: 18),
                  const SizedBox(width: 6),
                  Text(card.ratingAvg.toStringAsFixed(1), style: theme.textTheme.titleMedium),
                  const SizedBox(width: 6),
                  Text('· ${card.ratingCount} ta sharh', style: muted),
                ] else
                  Text("Hali sharh yo'q", style: muted),
              ],
            ),
            if (place != null || meters != null) ...[
              const SizedBox(height: BzSpace.m),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(BzIcons.location, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: BzSpace.s),
                  Expanded(child: Text(place ?? '', style: theme.textTheme.bodyMedium)),
                  if (meters != null) ...[
                    const SizedBox(width: BzSpace.s),
                    Text(distanceLabel(meters!), style: theme.textTheme.labelLarge),
                  ],
                ],
              ),
            ],
            if (price != null) ...[
              const SizedBox(height: BzSpace.s),
              Row(
                children: [
                  Icon(BzIcons.wallet, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: BzSpace.s),
                  Text(price, style: theme.textTheme.labelLarge),
                ],
              ),
            ],
            const SizedBox(height: BzSpace.xl),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PrimaryButton(key: const Key('map-sheet-open'), label: 'Batafsil', onPressed: onOpen),
                ),
                const SizedBox(width: BzSpace.m),
                Expanded(
                  flex: 2,
                  child: SecondaryButton(
                    key: const Key('map-sheet-route'),
                    label: "Yo'nalish",
                    icon: BzIcons.route,
                    onPressed: card.hasLocation
                        ? () => unawaited(
                            ref.read(urlOpenerProvider).open(directionsUri(card)).then((ok) {
                              if (!ok) showSnack("Xaritani ochib bo'lmadi.");
                            }),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
