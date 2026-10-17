import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/core/revisions.dart';
import 'package:bizcat/core/session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const Object _keep = Object();

/// Max comment length (server rule).
const int kReviewCommentMax = 1000;

/// GET Endpoints.consumerReviews -> `List<Review>` (mine: + business{id,slug,name,logo},
/// appointment_id, order_id, status). Signed out -> []. Re-read when reviews change.
final myReviewsProvider = FutureProvider.autoDispose<List<Review>>((ref) async {
  final consumerId = ref.watch(consumerIdProvider);
  ref.watch(reviewsRevisionProvider);
  if (consumerId == null) return const [];
  return ref.read(apiProvider).getList<Review>(Endpoints.consumerReviews, Review.fromJson);
});

/// Bumps both revisions after a review was created, edited or deleted (bookings carry
/// can_review / review_id, the business page carries the rating).
void _bumpRevisions(Ref ref) {
  ref.read(bookingsRevisionProvider.notifier).bump();
  ref.read(reviewsRevisionProvider.notifier).bump();
}

/// Review actions outside the composer (the "Sharhlarim" list).
final reviewActionsProvider = Provider<ReviewActions>(ReviewActions.new);

class ReviewActions {
  ReviewActions(this._ref);

  final Ref _ref;

  /// DELETE Endpoints.consumerReview(id) -> 204. true on success; errors -> a snackbar.
  Future<bool> delete(int id) async {
    try {
      await _ref.read(apiProvider).delete<Object?>(Endpoints.consumerReview(id));
      _bumpRevisions(_ref);
      return true;
    } on Object catch (e) {
      showErrorSnack(e);
      return false;
    }
  }
}

/// What the composer reviews: a visit (create) or an existing review (edit).
typedef ReviewTarget = ({int? appointmentId, int? orderId, int? reviewId});

@immutable
final class ReviewComposeState {
  const ReviewComposeState({
    this.rating = 0,
    this.comment = '',
    this.submitting = false,
    this.loading = false,
    this.ratingError,
    this.commentError,
    this.error,
    this.existing,
  });

  /// 1..5; 0 = none chosen yet.
  final int rating;
  final String comment;
  final bool submitting;

  /// Edit mode: the review is still being looked up in [myReviewsProvider].
  final bool loading;
  final String? ratingError;
  final String? commentError;

  /// A blocking error (409 already reviewed / not completed, 404 not found, a failed lookup).
  final Object? error;

  /// Edit mode: the review being edited.
  final Review? existing;

  bool get isEdit => existing != null;

  ReviewComposeState copyWith({
    int? rating,
    String? comment,
    bool? submitting,
    bool? loading,
    Object? ratingError = _keep,
    Object? commentError = _keep,
    Object? error = _keep,
    Review? existing,
  }) => ReviewComposeState(
    rating: rating ?? this.rating,
    comment: comment ?? this.comment,
    submitting: submitting ?? this.submitting,
    loading: loading ?? this.loading,
    ratingError: identical(ratingError, _keep) ? this.ratingError : ratingError as String?,
    commentError: identical(commentError, _keep) ? this.commentError : commentError as String?,
    error: identical(error, _keep) ? this.error : error,
    existing: existing ?? this.existing,
  );
}

/// The review composer (create / edit / delete).
final reviewComposeProvider = NotifierProvider.autoDispose
    .family<ReviewComposeController, ReviewComposeState, ReviewTarget>(ReviewComposeController.new);

class ReviewComposeController extends Notifier<ReviewComposeState> {
  ReviewComposeController(this.target);

  final ReviewTarget target;

  static const notFound = ApiException(
    kind: ApiErrorKind.http,
    status: 404,
    title: 'Not Found',
    detail: 'Sharh topilmadi.',
  );

  @override
  ReviewComposeState build() {
    final id = target.reviewId;
    if (id == null) return const ReviewComposeState();
    // Edit mode: seed from "mine" once it is known (kept subscribed while the composer lives).
    ref.listen(myReviewsProvider, (_, next) {
      if (state.loading) state = _seed(next, id);
    });
    return _seed(ref.read(myReviewsProvider), id);
  }

  ReviewComposeState _seed(AsyncValue<List<Review>> mine, int id) {
    if (mine.hasError && !mine.isLoading) return ReviewComposeState(error: mine.error);
    final list = mine.value;
    if (list == null) return const ReviewComposeState(loading: true);
    for (final r in list) {
      if (r.id == id) return ReviewComposeState(rating: r.rating, comment: r.comment ?? '', existing: r);
    }
    return const ReviewComposeState(error: notFound);
  }

  void setRating(int rating) => state = state.copyWith(rating: rating, ratingError: null);

  void setComment(String comment) => state = state.copyWith(
    comment: comment,
    commentError: comment.length > kReviewCommentMax ? state.commentError : null,
  );

  /// Validates, then POST (create) or PATCH (edit). true on success (revisions bumped).
  /// 422 -> field errors; 409 / 404 -> [ReviewComposeState.error]; anything else -> a snackbar.
  Future<bool> submit() async {
    if (state.submitting || state.loading) return false;
    final rating = state.rating;
    final comment = state.comment.trim();
    final ratingError = rating < 1 || rating > 5 ? 'Baho tanlang.' : null;
    final commentError = comment.length > kReviewCommentMax ? "Ko'pi bilan $kReviewCommentMax ta belgi." : null;
    if (ratingError != null || commentError != null) {
      state = state.copyWith(ratingError: ratingError, commentError: commentError);
      return false;
    }

    final existing = state.existing;
    final api = ref.read(apiProvider);
    state = state.copyWith(submitting: true, ratingError: null, commentError: null, error: null);
    try {
      if (existing != null) {
        final byOrder = existing.orderId != null;
        final input = ReviewInput(
          appointmentId: byOrder ? null : (existing.appointmentId ?? 0),
          orderId: existing.orderId,
          rating: rating,
          comment: comment.isEmpty ? null : comment,
        );
        await api.patch<Review>(
          Endpoints.consumerReview(existing.id),
          body: input.toPatchJson(),
          decode: (d) => Review.fromJson(JsonRead.object(d)),
        );
      } else {
        final input = ReviewInput(
          appointmentId: target.appointmentId,
          orderId: target.appointmentId == null ? target.orderId : null,
          rating: rating,
          comment: comment.isEmpty ? null : comment,
        );
        await api.post<Review>(
          Endpoints.consumerReviews,
          body: input.toJson(),
          decode: (d) => Review.fromJson(JsonRead.object(d)),
        );
      }
      if (!ref.mounted) return true;
      _bumpRevisions(ref);
      state = state.copyWith(submitting: false);
      return true;
    } on Object catch (e) {
      if (!ref.mounted) return false;
      if (e is ApiException && e.isValidation && e.hasFieldErrors) {
        state = state.copyWith(
          submitting: false,
          ratingError: e.fieldError('rating'),
          commentError: e.fieldError('comment'),
        );
        if (e.fieldError('rating') == null && e.fieldError('comment') == null) showErrorSnack(e);
      } else if (e is ApiException && (e.isConflict || e.isNotFound)) {
        state = state.copyWith(submitting: false, error: e);
      } else {
        state = state.copyWith(submitting: false);
        showErrorSnack(e);
      }
      return false;
    }
  }

  /// DELETE the edited review. true on success (revisions bumped); errors -> a snackbar.
  Future<bool> delete() async {
    final existing = state.existing;
    if (existing == null || state.submitting) return false;
    state = state.copyWith(submitting: true);
    final ok = await ref.read(reviewActionsProvider).delete(existing.id);
    if (ref.mounted) state = state.copyWith(submitting: false);
    return ok;
  }
}
