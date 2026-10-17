import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped after any booking/order create or cancel, and when a deposit turns paid.
/// Watch it in providers that list bookings so they refetch without importing other features.
final bookingsRevisionProvider = NotifierProvider<RevisionController, int>(RevisionController.new);

/// Bumped after a review create, update or delete.
final reviewsRevisionProvider = NotifierProvider<RevisionController, int>(RevisionController.new);

/// A counter; `ref.read(xRevisionProvider.notifier).bump()`.
class RevisionController extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}
