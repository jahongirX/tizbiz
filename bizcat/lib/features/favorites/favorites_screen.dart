import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/favorites.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/shared/widgets/business_cards.dart';
import 'package:bizcat/shared/widgets/login_prompt.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The Sevimlilar tab (BIZCAT-SPEC §9.10). Reads only [favoritesProvider].
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sevimlilar')),
        body: const Center(
          child: LoginPromptView(
            title: 'Sevimli joylaringiz',
            message: 'Yoqqan bizneslarni yurakcha bilan saqlang.',
            from: AppRoutes.favorites,
            icon: Icons.favorite_border,
          ),
        ),
      );
    }

    final state = ref.watch(favoritesProvider);
    final ctrl = ref.read(favoritesProvider.notifier);

    // A heart tapped on this (visible) screen removes the card: confirm it with a snackbar.
    ref.listen<FavoritesState>(favoritesProvider, (prev, next) {
      if (prev == null || !prev.loaded || !next.loaded) return;
      if (!TickerMode.valuesOf(context).enabled) return; // another tab is in front
      final removed = prev.ids.difference(next.ids);
      if (removed.isNotEmpty && next.error == prev.error) showSnack('Sevimlilardan olib tashlandi');
    });

    final Widget body;
    if (!state.loaded && state.error == null) {
      body = const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: LoadingView(kind: LoadingKind.cards, rows: 3),
      );
    } else if (state.error != null && state.cards.isEmpty) {
      final e = state.error!;
      void retry() => unawaited(ctrl.refresh());
      body = isOffline(e) ? OfflineState(onRetry: retry) : ErrorState(message: errorText(e), onRetry: retry);
    } else {
      final cards = [
        for (final c in state.cards)
          if (state.ids.contains(c.id)) c,
      ];
      body = RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: cards.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: BzSpace.xxxl),
                children: [
                  EmptyState(
                    icon: Icons.favorite_border,
                    title: "Sevimlilar ro'yxati bo'sh",
                    message: 'Biznes sahifasidagi yurakchani bosing.',
                    actionLabel: 'Katalogni ochish',
                    onAction: () => context.go(AppRoutes.explore),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.s, BzSpace.gutter, BzSpace.xxxl),
                itemCount: cards.length,
                separatorBuilder: (_, _) => const SizedBox(height: BzSpace.m),
                itemBuilder: (_, i) => BusinessCardTile(key: ValueKey('fav-${cards[i].id}'), card: cards[i]),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sevimlilar')),
      body: body,
    );
  }
}
