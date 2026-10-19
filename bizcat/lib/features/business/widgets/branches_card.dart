import 'dart:async';

import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Google Maps search URI for a point (opens the maps app on the phone).
Uri mapPointUri(double lat, double lng) => Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

/// `Filiallar (10)`: every branch with its address; the map icon opens it in the maps app.
class BranchesCard extends ConsumerWidget {
  const BranchesCard({super.key, required this.branches});

  final List<BusinessBranch> branches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      key: const Key('business-branches'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(BzSpace.l, BzSpace.l, BzSpace.l, BzSpace.xs),
            child: Text('Filiallar (${branches.length})', style: theme.textTheme.titleMedium),
          ),
          for (final b in branches)
            ListTile(
              leading: Icon(BzIcons.location, color: theme.colorScheme.primary),
              title: Text(b.name),
              subtitle: Text(
                [?b.address, if (b.district != null && b.district != b.address) b.district!, ?b.landmark].join(' · '),
                style: muted,
              ),
              trailing: b.hasLocation
                  ? IconButton(
                      tooltip: 'Xaritada ochish',
                      icon: const Icon(BzIcons.map),
                      onPressed: () => unawaited(
                        ref.read(urlOpenerProvider).open(mapPointUri(b.lat!, b.lng!)).then((ok) {
                          if (!ok) showSnack("Xaritani ochib bo'lmadi.");
                        }),
                      ),
                    )
                  : null,
            ),
          const SizedBox(height: BzSpace.s),
        ],
      ),
    );
  }
}

/// Shown on a listing imported from an open source: it is not on Bizcat yet, so there is no
/// online booking; the owner can connect it.
class UnclaimedNote extends ConsumerWidget {
  const UnclaimedNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: const Key('business-unclaimed'),
      padding: const EdgeInsets.all(BzSpace.m),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(BzRadius.l)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(BzIcons.info, color: scheme.primary, size: 20),
          const SizedBox(width: BzSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bu biznes hali Bizcat'ga ulanmagan: onlayn bron yo'q, ma'lumotlar ochiq manbalardan.",
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () => unawaited(ref.read(urlOpenerProvider).open(Uri.parse('https://tizbiz.uz/register'))),
                  child: Text(
                    'Bu sizning biznesingizmi? Bepul ulang',
                    style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
