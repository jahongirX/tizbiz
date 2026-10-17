// The business page itself uses the shared businessPageProvider(slug) (header, info, rating,
// reviews preview) and storefrontProvider(slug) (offerings and the booking flow).

import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/booking_flow.dart';
import 'package:bizcat/core/revisions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const Object _keep = Object();

/// Family key of [businessReviewsProvider]: the business slug and an optional star filter.
typedef ReviewsKey = ({String slug, int? rating});

/// The pages of public reviews loaded so far plus the business rating summary.
@immutable
final class ReviewsPage {
  const ReviewsPage({required this.page, required this.summary, this.loadingMore = false, this.moreError});

  /// Every item loaded so far; `page.meta` is the last loaded page's meta.
  final Paged<Review> page;

  /// From the list `meta` (avg, count, distribution).
  final RatingSummary summary;

  /// A next page request is in flight.
  final bool loadingMore;

  /// The last [BusinessReviewsController.loadMore] failure (cleared on the next attempt).
  final Object? moreError;

  List<Review> get items => page.items;
  bool get hasMore => page.hasMore;
  bool get isEmpty => page.isEmpty;

  ReviewsPage copyWith({Paged<Review>? page, RatingSummary? summary, bool? loadingMore, Object? moreError = _keep}) =>
      ReviewsPage(
        page: page ?? this.page,
        summary: summary ?? this.summary,
        loadingMore: loadingMore ?? this.loadingMore,
        moreError: identical(moreError, _keep) ? this.moreError : moreError,
      );
}

/// GET Endpoints.directoryReviews(slug) query {rating?, page, per_page: 20} (public) ->
/// `Paged<Review>`, summary = RatingSummary.fromMeta(meta). [BusinessReviewsController.loadMore]
/// appends the next page. Re-read when reviews change (reviewsRevisionProvider).
final businessReviewsProvider = AsyncNotifierProvider.autoDispose
    .family<BusinessReviewsController, ReviewsPage, ReviewsKey>(BusinessReviewsController.new);

class BusinessReviewsController extends AsyncNotifier<ReviewsPage> {
  BusinessReviewsController(this.key);

  final ReviewsKey key;

  static const int perPage = 20;

  /// Bumped on every build so a loadMore that started before a refresh is dropped.
  int _generation = 0;

  @override
  Future<ReviewsPage> build() async {
    ref.watch(reviewsRevisionProvider);
    _generation++;
    final first = await _fetch(1);
    return ReviewsPage(page: first, summary: RatingSummary.fromMeta(first.meta));
  }

  /// The wire query: `{rating?, page, per_page}`.
  static Map<String, Object?> queryFor(ReviewsKey key, int page) => {
    'rating': ?key.rating,
    'page': page,
    'per_page': perPage,
  };

  Future<Paged<Review>> _fetch(int page) => ref
      .read(apiProvider)
      .getPage<Review>(
        Endpoints.directoryReviews(key.slug),
        Review.fromJson,
        query: queryFor(key, page),
        auth: RequestAuth.none,
      );

  /// Loads and appends the next page. No-op while loading, without data or on the last page.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || state.isLoading || current.loadingMore || !current.hasMore) return;
    final generation = _generation;
    state = AsyncData(current.copyWith(loadingMore: true, moreError: null));
    try {
      final next = await _fetch(current.page.meta.page + 1);
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(ReviewsPage(page: current.page.append(next), summary: RatingSummary.fromMeta(next.meta)));
    } on Object catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(current.copyWith(loadingMore: false, moreError: e));
    }
  }
}

/// Initial tab index of the business page from the `tab` route param:
/// `offer` (default) -> 0, `reviews` -> 1, `info` -> 2.
int businessTabIndex(String? tab) => switch (tab) {
  'reviews' => 1,
  'info' => 2,
  _ => 0,
};

/// Today's opening hours line: `Bugun: 09:00–21:00`, or `Bugun: dam olish kuni` when today has
/// no row. null when [hours] is empty (the row is hidden).
String? todayHoursLabel(List<OpeningHours> hours, int todayWeekday) {
  if (hours.isEmpty) return null;
  final today = hoursFor(hours, todayWeekday);
  return today == null ? 'Bugun: dam olish kuni' : 'Bugun: ${hoursRange(today)}';
}

/// The row of [weekday] (ISO 1..7), or null.
OpeningHours? hoursFor(List<OpeningHours> hours, int weekday) {
  for (final h in hours) {
    if (h.weekday == weekday) return h;
  }
  return null;
}

/// `09:00–21:00`.
String hoursRange(OpeningHours h) => '${h.open.format()}–${h.close.format()}';

/// Slot/rental services a consumer can book online (`isActive && onlineBookable`).
List<Service> bookableServices(StorefrontData s) => [
  for (final x in s.services)
    if (x.isActive && x.onlineBookable) x,
];

/// Catalog items: the flat `items`, or (when empty) every category's items.
List<Service> catalogItems(StorefrontData s) =>
    s.items.isNotEmpty ? s.items : [for (final c in s.categories) ...c.items];

/// Whether the business page shows the booking CTA: online booking on, and the flow has
/// something to book (a bookable service for slot/rental, an item for catalog).
bool canBookOnline(StorefrontData s) {
  if (!s.business.onlineBookingEnabled) return false;
  return switch (bookingFlowFor(s)) {
    BookingFlow.slot || BookingFlow.rental => bookableServices(s).isNotEmpty,
    BookingFlow.catalog => catalogItems(s).isNotEmpty,
  };
}
