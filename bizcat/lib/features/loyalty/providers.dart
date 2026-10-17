import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/revisions.dart';
import 'package:bizcat/core/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// GET Endpoints.consumerLoyalty -> one entry per business the consumer is a client of.
/// Empty when signed out. Re-read after sign-in/out and after bookings change.
final loyaltyWalletProvider = FutureProvider.autoDispose<List<LoyaltyWalletEntry>>((ref) async {
  final consumerId = ref.watch(consumerIdProvider);
  ref.watch(bookingsRevisionProvider);
  if (consumerId == null) return const [];
  return ref.read(apiProvider).getList(Endpoints.consumerLoyalty, LoyaltyWalletEntry.fromJson);
});

/// Totals of the wallet header.
({int cashbackTiyin, int points}) walletTotals(List<LoyaltyWalletEntry> entries) =>
    (cashbackTiyin: entries.fold(0, (s, e) => s + e.cashbackTiyin), points: entries.fold(0, (s, e) => s + e.points));
