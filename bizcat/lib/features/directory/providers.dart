import 'dart:async';

import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/data/directory_query.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Results per page of the directory list.
const int kDirectoryPerPage = 20;

/// Human labels of [DirectoryQuery.sorts].
const Map<String, String> kDirectorySortLabels = {
  'featured': 'Tavsiya etilgan',
  'rating': "Reyting bo'yicha",
  'new': "Yangi qo'shilganlar",
  'name': "Nomi bo'yicha",
};

String directorySortLabel(String sort) => kDirectorySortLabels[sort] ?? kDirectorySortLabels['featured']!;

/// The directory filter. Initialised from the route params ([DirectoryFilterController.init]) and
/// the selected city; it follows later city changes and keeps the other fields.
final directoryFilterProvider = NotifierProvider.autoDispose<DirectoryFilterController, DirectoryQuery>(
  DirectoryFilterController.new,
);

class DirectoryFilterController extends Notifier<DirectoryQuery> {
  /// False until [init] ran; [directoryResultsProvider] waits for it so the unseeded default
  /// query is never fetched.
  bool get ready => _ready;
  bool _ready = false;

  @override
  DirectoryQuery build() {
    ref.listen<String?>(cityProvider, (_, city) {
      if (city != state.city) state = state.copyWith(city: city, page: 1);
    });
    return DirectoryQuery(city: ref.read(cityProvider), perPage: kDirectoryPerPage);
  }

  /// Applies the route params (called from the screen's initState, and again when the route
  /// params change). Unknown sorts fall back to 'featured'.
  void init({String? q, String? category, String? sort}) {
    final next = DirectoryQuery(
      q: _cleanQ(q),
      category: _blankToNull(category),
      sort: DirectoryQuery.sorts.contains(sort) ? sort! : 'featured',
      city: ref.read(cityProvider),
      perPage: kDirectoryPerPage,
    );
    final firstTime = !_ready;
    _ready = true;
    if (next != state) {
      state = next;
    } else if (firstTime) {
      // Equal states do not notify; the results still have to start loading.
      ref.notifyListeners();
    }
  }

  /// Ignores a single character (it does not search); '' clears the search.
  void setQuery(String q) {
    final t = q.trim();
    if (t.length == 1) return;
    final next = t.isEmpty ? null : t;
    if (next != state.q) state = state.copyWith(q: next, page: 1);
  }

  void setCategory(String? key) {
    final k = _blankToNull(key);
    if (k != state.category) state = state.copyWith(category: k, page: 1);
  }

  void setSort(String sort) {
    if (!DirectoryQuery.sorts.contains(sort) || sort == state.sort) return;
    state = state.copyWith(sort: sort, page: 1);
  }

  /// Clears the search, the category and the sort; keeps the city.
  void reset() => state = DirectoryQuery(city: state.city, perPage: kDirectoryPerPage);

  static String? _blankToNull(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static String? _cleanQ(String? q) {
    final t = _blankToNull(q);
    return (t == null || t.length < 2) ? null : t;
  }
}

/// One loaded state of the directory list.
@immutable
final class DirectoryPage {
  const DirectoryPage({required this.page, this.loadingMore = false, this.moreError});

  final Paged<BusinessCard> page;
  final bool loadingMore;

  /// The last loadMore() failure (the loaded items stay).
  final Object? moreError;

  bool get hasMore => page.hasMore;
}

/// The paged results of [directoryFilterProvider]: build() loads page 1, loadMore() appends.
final directoryResultsProvider = AsyncNotifierProvider.autoDispose<DirectoryResultsController, DirectoryPage>(
  DirectoryResultsController.new,
);

class DirectoryResultsController extends AsyncNotifier<DirectoryPage> {
  late DirectoryQuery _filter;

  Future<Paged<BusinessCard>> _fetch(DirectoryQuery q) => ref
      .read(apiProvider)
      .getPage(
        Endpoints.directoryBusinesses,
        BusinessCard.fromJson,
        query: q.copyWith(perPage: kDirectoryPerPage).toQuery(),
      );

  @override
  Future<DirectoryPage> build() async {
    final filter = ref.watch(directoryFilterProvider).copyWith(page: 1);
    ref.watch(consumerIdProvider);
    // Not seeded from the route yet: stay loading (init() changes the filter, which rebuilds this).
    if (!ref.read(directoryFilterProvider.notifier).ready) return Completer<DirectoryPage>().future;
    _filter = filter;
    return DirectoryPage(page: await _fetch(filter));
  }

  /// Appends the next page. No-op while loading, without more pages, or before the first page.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || state.isLoading || current.loadingMore || !current.hasMore) return;
    final filter = _filter;
    state = AsyncData(DirectoryPage(page: current.page, loadingMore: true));
    try {
      final next = await _fetch(filter.copyWith(page: current.page.meta.page + 1));
      if (!ref.mounted || _filter != filter) return;
      state = AsyncData(DirectoryPage(page: current.page.append(next)));
    } on Object catch (e) {
      if (!ref.mounted || _filter != filter) return;
      state = AsyncData(DirectoryPage(page: current.page, moreError: e));
    }
  }
}
