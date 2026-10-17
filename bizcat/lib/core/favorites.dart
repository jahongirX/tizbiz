import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import 'api.dart';
import 'messenger.dart';
import 'session.dart';

const Object _keep = Object();

/// The consumer's favorites (ids for hearts, cards for the favorites screen).
@immutable
final class FavoritesState {
  const FavoritesState({this.ids = const {}, this.cards = const [], this.loaded = false, this.error});

  /// Business ids that are favorites (optimistic).
  final Set<int> ids;

  /// For the favorites screen, newest first.
  final List<BusinessCard> cards;

  /// true after the first successful GET (always true when signed out).
  final bool loaded;
  final Object? error;

  bool contains(int businessId) => ids.contains(businessId);

  FavoritesState copyWith({Set<int>? ids, List<BusinessCard>? cards, bool? loaded, Object? error = _keep}) =>
      FavoritesState(
        ids: ids ?? this.ids,
        cards: cards ?? this.cards,
        loaded: loaded ?? this.loaded,
        error: identical(error, _keep) ? this.error : error,
      );
}

/// Favorites of the signed-in consumer; empty (loaded) when signed out.
final favoritesProvider = NotifierProvider<FavoritesController, FavoritesState>(FavoritesController.new);

class FavoritesController extends Notifier<FavoritesState> {
  /// Watches [consumerIdProvider]: null -> empty and loaded; otherwise schedules [refresh].
  /// Local toggles a refresh must not overwrite: kept until a GET that started after the toggle's
  /// request finished (`settled`) has answered.
  int _seq = 0;
  final Map<int, ({int tok, bool on, BusinessCard? card, int? settled})> _local = {};

  bool _keepLocal(({int tok, bool on, BusinessCard? card, int? settled}) v, int startSeq) =>
      v.settled == null || v.settled! > startSeq;

  @override
  FavoritesState build() {
    _local.clear();
    final id = ref.watch(consumerIdProvider);
    if (id == null) return const FavoritesState(loaded: true);
    Future.microtask(refresh);
    return const FavoritesState();
  }

  bool get _signedIn => ref.read(consumerIdProvider) != null;

  /// GET /v1/consumer/favorites.
  Future<void> refresh() async {
    if (!_signedIn) return;
    final r = ref;
    final startSeq = _seq;
    try {
      final cards = await r.read(apiProvider).getList(Endpoints.consumerFavorites, BusinessCard.fromJson);
      if (!r.mounted) return;
      // Re-apply toggles made while this request was in flight.
      final list = [...cards];
      for (final e in _local.entries) {
        if (!_keepLocal(e.value, startSeq)) continue;
        list.removeWhere((c) => c.id == e.key);
        final card = e.value.card;
        if (e.value.on && card != null) list.insert(0, card.copyWith(isFavorite: true));
      }
      final ids = {for (final c in list) c.id};
      for (final e in _local.entries) {
        if (!_keepLocal(e.value, startSeq)) continue;
        e.value.on ? ids.add(e.key) : ids.remove(e.key);
      }
      _local.removeWhere((_, v) => !_keepLocal(v, startSeq));
      state = FavoritesState(ids: ids, cards: List.unmodifiable(list), loaded: true);
    } on Object catch (e) {
      if (!r.mounted) return;
      state = state.copyWith(error: e);
    }
  }

  /// Optimistic add/remove of [card]. On error it reverts and shows a snackbar.
  /// Returns the new value. Signed out: does nothing and returns false.
  ///
  /// [current] is the value the UI shows (pass it when [FavoritesState.loaded] is false);
  /// it defaults to `state.contains(card.id)` once loaded, else `card.isFavorite`.
  Future<bool> toggle(BusinessCard card, {bool? current}) =>
      _toggle(card.id, card: card, current: current ?? (state.loaded ? state.contains(card.id) : card.isFavorite));

  /// When only the id is known (detail page). Calls [refresh] after an add to fetch the card.
  Future<bool> toggleById(int businessId, {bool? current}) async {
    final added = await _toggle(businessId, current: current ?? state.contains(businessId));
    if (added) await refresh();
    return added;
  }

  Future<bool> _toggle(int id, {BusinessCard? card, required bool current}) async {
    if (!_signedIn) return false;
    final r = ref;
    final before = state;
    final next = !current;
    final knownCard = card ?? before.cards.where((c) => c.id == id).firstOrNull;
    final tok = ++_seq;
    _local[id] = (tok: tok, on: next, card: knownCard, settled: null);
    void settle(bool on) {
      if (_local[id]?.tok == tok) _local[id] = (tok: tok, on: on, card: knownCard, settled: ++_seq);
    }

    state = before.copyWith(
      ids: next ? {...before.ids, id} : ({...before.ids}..remove(id)),
      cards: next
          ? (card == null || before.cards.any((c) => c.id == id)
              ? before.cards
              : List.unmodifiable([card.copyWith(isFavorite: true), ...before.cards]))
          : List.unmodifiable(before.cards.where((c) => c.id != id)),
    );
    try {
      final api = r.read(apiProvider);
      final path = Endpoints.consumerFavorite(id);
      if (next) {
        await api.put<Object?>(path);
      } else {
        await api.delete<Object?>(path);
      }
      settle(next);
      return next;
    } on Object catch (e) {
      if (r.mounted && _signedIn) {
        settle(current);
        // Revert only this id; keep anything else that changed meanwhile.
        final now = state;
        state = now.copyWith(
          ids: current ? {...now.ids, id} : ({...now.ids}..remove(id)),
          cards: current
              ? (now.cards.any((c) => c.id == id)
                  ? now.cards
                  : before.cards.where((c) => c.id == id).isEmpty
                      ? now.cards
                      : List.unmodifiable([...before.cards.where((c) => c.id == id), ...now.cards]))
              : List.unmodifiable(now.cards.where((c) => c.id != id)),
        );
      }
      if (!(e is ApiException && e.isUnauthorized)) showErrorSnack(e);
      return current;
    }
  }
}
