import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

typedef ReviewsFilterValue = ({int? rating, bool? hasReply});
typedef ReviewsPage = ({Paged<Review> page, RatingSummary summary});

final class ReviewsFilter extends Notifier<ReviewsFilterValue> {
  @override
  ReviewsFilterValue build() => (rating: null, hasReply: null);

  void setRating(int? rating) => state = (rating: rating, hasReply: state.hasReply);
  void setHasReply(bool? hasReply) => state = (rating: state.rating, hasReply: hasReply);
}

final reviewsFilterProvider = NotifierProvider.autoDispose<ReviewsFilter, ReviewsFilterValue>(ReviewsFilter.new);

/// Paged GET /v1/reviews; the rating summary comes from `meta` (avg, count, distribution).
final class ReviewsPaged extends AsyncNotifier<ReviewsPage> {
  ReviewsPaged(this.filter);

  final ReviewsFilterValue filter;
  bool _loadingMore = false;

  Future<ReviewsPage> _fetch(int page, {CancelToken? cancel}) async {
    final res = await ref.read(apiClientProvider).getPage(
      Endpoints.reviews,
      Review.fromJson,
      query: {'rating': filter.rating, 'has_reply': filter.hasReply, ...ApiQuery.page(page)},
      cancelToken: cancel,
    );
    return (page: res, summary: RatingSummary.fromMeta(res.meta));
  }

  @override
  Future<ReviewsPage> build() async {
    requireActive(ref);
    ref.watch(apiClientProvider);
    final cancel = CancelToken();
    ref.onDispose(cancel.cancel);
    return _fetch(1, cancel: cancel);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (_loadingMore || current == null || !current.page.hasMore || state.isLoading) return;
    _loadingMore = true;
    try {
      final next = await _fetch(current.page.meta.page + 1);
      if (!ref.mounted) return;
      state = AsyncData((page: current.page.append(next.page), summary: next.summary));
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData((page: Paged(items: current.page.items, meta: current.page.meta), summary: current.summary));
      }
      rethrow;
    } finally {
      _loadingMore = false;
    }
  }

  /// Swaps the row with the same id (after a reply).
  void replaceItem(Review review) {
    final current = state.value;
    if (current == null) return;
    final items = [for (final r in current.page.items) r.id == review.id ? review : r];
    state = AsyncData((page: Paged(items: items, meta: current.page.meta), summary: current.summary));
  }
}

final reviewsPagedProvider =
    AsyncNotifierProvider.autoDispose.family<ReviewsPaged, ReviewsPage, ReviewsFilterValue>(ReviewsPaged.new);
