import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/favorites.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/shared/widgets/nav.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Heart toggle. Shows `state.loaded ? state.contains(id) : initial`.
/// Signed out it opens the login (`from` = current location).
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.businessId,
    this.initial = false,
    this.card,
    this.size = 24,
    this.onImage = false,
  });

  final int businessId;

  /// The server's `is_favorite` (card or detail), used until favorites are loaded.
  final bool initial;

  /// When given, [FavoritesController.toggle] adds it to the favorites list at once.
  final BusinessCard? card;
  final double size;

  /// White circle background (on cover images).
  final bool onImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = ref.watch(favoritesProvider);
    final on = fav.loaded ? fav.contains(businessId) : initial;
    final scheme = Theme.of(context).colorScheme;
    final icon = Icon(on ? Icons.favorite : Icons.favorite_border, size: size, color: scheme.primary);

    void onTap() {
      if (!ref.read(isSignedInProvider)) {
        unawaited(context.push(AppRoutes.loginWith(from: currentLocation(context))));
        return;
      }
      final ctrl = ref.read(favoritesProvider.notifier);
      final c = card;
      unawaited(c != null ? ctrl.toggle(c, current: on) : ctrl.toggleById(businessId, current: on));
    }

    final button = IconButton(
      tooltip: on ? 'Sevimlilardan olib tashlash' : "Sevimlilarga qo'shish",
      onPressed: onTap,
      icon: icon,
      style: onImage
          ? IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: scheme.primary)
          : null,
    );
    return button;
  }
}
