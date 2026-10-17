import 'dart:async';

import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Address card (apps/booking LocationCard.vue): apricot pin, `Manzil`, address, phone link and
/// `Xaritada ochish`. Hidden when nothing is known.
class LocationCard extends ConsumerWidget {
  const LocationCard({super.key, this.address, this.mapUrl, this.lat, this.lng, this.name, this.phone});

  final String? address;
  final String? mapUrl;
  final double? lat;
  final double? lng;
  final String? name;
  final String? phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAddress = (address ?? '').trim().isNotEmpty;
    final hasPhone = Phone.telUri(phone) != null;
    final canMap = hasMapTarget(mapUrl: mapUrl, lat: lat, lng: lng, name: name, address: address);
    if (!hasAddress && !hasPhone && !canMap) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(BzSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: BzColors.indigo50, shape: BoxShape.circle),
                  child: const Icon(Icons.place, color: BzColors.apricot, size: 22),
                ),
                const SizedBox(width: BzSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manzil', style: theme.textTheme.bodySmall),
                      if (hasAddress) Text(address!.trim(), style: theme.textTheme.bodyLarge),
                      if (hasPhone)
                        InkWell(
                          onTap: () => unawaited(callPhone(ref, phone)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: BzSpace.xs),
                            child: Text(
                              Phone.format(phone),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (canMap) ...[
              const SizedBox(height: BzSpace.m),
              SecondaryButton(
                label: 'Xaritada ochish',
                icon: Icons.map_outlined,
                onPressed: () => unawaited(
                  openMap(ref, mapUrl: mapUrl, lat: lat, lng: lng, name: name, address: address),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
