import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/features/loyalty/providers.dart';
import 'package:bizcat/shared/widgets/async_body.dart';
import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/app_theme.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Hamyon: cashback, points and deposits per business (BIZCAT-SPEC §9.11).
class LoyaltyWalletScreen extends ConsumerWidget {
  const LoyaltyWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(loyaltyWalletProvider);
    Future<void> refresh() async {
      try {
        ref.invalidate(loyaltyWalletProvider);
        await ref.read(loyaltyWalletProvider.future);
      } on Object {
        // The error state shows it.
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Hamyon')),
      body: AsyncBody<List<LoyaltyWalletEntry>>(
        value: wallet,
        onRetry: () => ref.invalidate(loyaltyWalletProvider),
        loading: const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: LoadingView(kind: LoadingKind.cards, rows: 3),
        ),
        isEmpty: (list) => list.isEmpty,
        empty: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: BzSpace.xxxl),
            children: const [
              EmptyState(
                icon: BzIcons.wallet,
                title: "Hali bonuslar yo'q",
                message: "Bizcat orqali yoziling va keshbek to'plang.",
              ),
            ],
          ),
        ),
        builder: (entries) {
          final muted = Theme.of(context).colorScheme.onSurfaceVariant;
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.s, BzSpace.gutter, BzSpace.xxxl),
              children: [
                _TotalsCard(entries: entries),
                const SizedBox(height: BzSpace.m),
                Text(
                  'Bonuslardan foydalanish uchun biznesda telefon raqamingizni ayting.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                ),
                for (final e in entries) ...[const SizedBox(height: BzSpace.m), _EntryCard(entry: e)],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.entries});

  final List<LoyaltyWalletEntry> entries;

  @override
  Widget build(BuildContext context) {
    final totals = walletTotals(entries);
    final text = Theme.of(context).textTheme;
    final soft = BzColors.white.withValues(alpha: 0.75);
    return Container(
      padding: const EdgeInsets.all(BzSpace.xl),
      decoration: BoxDecoration(color: BzColors.indigo, borderRadius: BorderRadius.circular(BzRadius.l)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Jami keshbek', style: text.bodyMedium?.copyWith(color: soft)),
          const SizedBox(height: BzSpace.xs),
          Text(Money.format(totals.cashbackTiyin), style: BzText.sora(context, 28, color: BzColors.white)),
          const SizedBox(height: BzSpace.s),
          Text('Jami ballar: ${totals.points}', style: text.bodyMedium?.copyWith(color: soft)),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final LoyaltyWalletEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = entry.business;
    final stripe = parseHexColor(b.brandColor) ?? scheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: b.slug.isEmpty ? null : () => unawaited(context.push(AppRoutes.business(b.slug))),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: stripe),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(BzSpace.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          BizLogo(url: b.logo, name: b.name, size: 40, brandColor: b.brandColor),
                          const SizedBox(width: BzSpace.m),
                          Expanded(
                            child: Text(
                              b.name,
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(BzIcons.chevronRight, color: scheme.onSurfaceVariant),
                        ],
                      ),
                      const SizedBox(height: BzSpace.m),
                      Row(
                        children: [
                          _Metric(label: 'Ballar', value: '${entry.points}'),
                          _Metric(label: 'Keshbek', value: Money.format(entry.cashbackTiyin)),
                          _Metric(label: 'Tashriflar', value: '${entry.visits}'),
                        ],
                      ),
                      if (entry.depositBalanceTiyin > 0) ...[
                        const SizedBox(height: BzSpace.s),
                        Text(
                          'Depozit balansi: ${Money.format(entry.depositBalanceTiyin)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
