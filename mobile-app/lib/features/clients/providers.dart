import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Search + segment of the clients list. Segment: '' (all), 'new', 'repeat', 'lost'.
typedef ClientsQueryValue = ({String search, String segment});

const kClientSegments = <({String value, String label})>[
  (value: '', label: 'Barchasi'),
  (value: 'new', label: 'Yangi'),
  (value: 'repeat', label: 'Takroriy'),
  (value: 'lost', label: "Yo'qolgan"),
];

final class ClientsQuery extends Notifier<ClientsQueryValue> {
  @override
  ClientsQueryValue build() => (search: '', segment: '');

  void setSearch(String v) => state = (search: v.trim(), segment: state.segment);
  void setSegment(String v) => state = (search: state.search, segment: v);
}

final clientsQueryProvider = NotifierProvider.autoDispose<ClientsQuery, ClientsQueryValue>(ClientsQuery.new);

const kClientsPerPage = 20;

/// GET /v1/clients paged (20 per page): `loadMore()` appends the next page, `refresh()` reloads.
class ClientsPaged extends AsyncNotifier<Paged<Client>> {
  ClientsPaged(this.query);

  final ClientsQueryValue query;

  bool _loadingMore = false;

  /// True while [loadMore] runs.
  bool get loadingMore => _loadingMore;

  CancelToken? _cancel;

  Future<Paged<Client>> _fetch(int page) {
    final cancel = CancelToken();
    _cancel = cancel;
    return ref
        .read(apiClientProvider)
        .getPage(
          Endpoints.clients,
          Client.fromJson,
          query: {
            if (query.search.isNotEmpty) 'search': query.search,
            if (query.segment.isNotEmpty) 'segment': query.segment,
            ...ApiQuery.page(page, perPage: kClientsPerPage),
          },
          cancelToken: cancel,
        );
  }

  @override
  Future<Paged<Client>> build() async {
    requireActive(ref);
    ref.watch(clientsRevisionProvider);
    ref.watch(apiClientProvider);
    ref.onDispose(() => _cancel?.cancel());
    _loadingMore = false;
    return _fetch(1);
  }

  /// Appends the next page; on error keeps the rows and rethrows.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || _loadingMore || state.isLoading) return;
    _loadingMore = true;
    state = AsyncData(Paged(items: current.items, meta: current.meta));
    try {
      final next = await _fetch(current.meta.page + 1);
      if (!ref.mounted) return;
      _loadingMore = false;
      state = AsyncData(current.append(next));
    } catch (_) {
      if (!ref.mounted) rethrow;
      _loadingMore = false;
      // Keep the rows; the caller shows the error.
      state = AsyncData(Paged(items: current.items, meta: current.meta));
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final clientsPagedProvider = AsyncNotifierProvider.autoDispose.family<ClientsPaged, Paged<Client>, ClientsQueryValue>(
  ClientsPaged.new,
);

/// GET /v1/clients/{id} -> client, categories, history (last 20), loyalty.
final clientDetailProvider = FutureProvider.autoDispose.family<ClientDetail, int>((ref, id) async {
  requireActive(ref);
  ref.watch(clientsRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref
      .watch(apiClientProvider)
      .get<ClientDetail>(
        Endpoints.client(id),
        decode: (d) => ClientDetail.fromJson(JsonRead.object(d)),
        cancelToken: cancel,
      );
});

/// GET /v1/client-categories, sorted by sort then id.
final clientCategoriesProvider = FutureProvider.autoDispose<List<ClientCategory>>((ref) async {
  requireActive(ref);
  ref.watch(clientsRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final list = await ref
      .watch(apiClientProvider)
      .getList(Endpoints.clientCategories, ClientCategory.fromJson, cancelToken: cancel);
  return [...list]..sort((a, b) {
    final c = (a.sort ?? 0).compareTo(b.sort ?? 0);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
});
