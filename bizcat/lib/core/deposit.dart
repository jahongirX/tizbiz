import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import 'api.dart';
import 'launcher.dart';

/// Thrown by [DepositService.startPayme] when the checkout URL is missing or cannot be opened.
final class DepositLaunchException implements Exception {
  const DepositLaunchException(this.url);

  final Uri? url;

  @override
  String toString() => 'DepositLaunchException($url)';
}

final depositServiceProvider = Provider<DepositService>((ref) => DepositService(ref));

/// Payme deposit checkout (Click is never offered).
class DepositService {
  DepositService(this._ref);

  final Ref _ref;

  /// POST /v1/payments/deposit {"appointment_id": id, "provider": "payme"} with the stable key
  /// `dep-<id>-payme` and no token, then opens the checkout URL externally.
  ///
  /// Throws [ApiException] (409/422 with Uzbek texts) or [DepositLaunchException].
  Future<DepositCheckout> startPayme(int appointmentId) async {
    final checkout = await _ref.read(apiProvider).post<DepositCheckout>(
          Endpoints.paymentsDeposit,
          body: {'appointment_id': appointmentId, 'provider': PaymentProvider.payme.wire},
          idempotencyKey: Idempotency.deposit(appointmentId),
          auth: RequestAuth.none,
          decode: (d) => DepositCheckout.fromJson(JsonRead.object(d)),
        );
    final url = checkout.checkoutUrl;
    if (url == null) throw const DepositLaunchException(null);
    final ok = await _ref.read(urlOpenerProvider).open(url);
    if (!ok) throw DepositLaunchException(url);
    return checkout;
  }
}
