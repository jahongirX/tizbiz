import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Review mutations (BIZNES-SPEC §9.10).
final class ReviewActions {
  ReviewActions(this._ref);

  final Ref _ref;

  /// POST /v1/reviews/{id}/reply {"reply": text}; a second call overwrites. Returns the item.
  Future<Review> reply(int id, String text) => _ref.read(apiClientProvider).post(
        Endpoints.reviewReply(id),
        body: {'reply': text},
        decode: (d) => Review.fromJson(JsonRead.object(d)),
      );
}

final reviewActionsProvider = Provider<ReviewActions>(ReviewActions.new);
