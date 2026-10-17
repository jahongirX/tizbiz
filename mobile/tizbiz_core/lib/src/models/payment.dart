import 'package:meta/meta.dart';

import '../time/dates.dart';
import '../util/json_read.dart';

/// Transaction (live fields() hides business_id, external_id, idempotency_key).
@immutable
final class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    this.appointmentId,
    this.provider = '',
    this.amountTiyin = 0,
    this.type = '',
    this.status = '',
    this.createdAt,
    this.updatedAt,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) => PaymentTransaction(
        id: JsonRead.integer(json['id']),
        appointmentId: JsonRead.integerOrNull(json['appointment_id']),
        provider: JsonRead.string(json['provider']),
        amountTiyin: JsonRead.integer(json['amount_tiyin']),
        type: JsonRead.string(json['type']),
        status: JsonRead.string(json['status']),
        createdAt: JsonRead.unix(json['created_at']),
        updatedAt: JsonRead.unix(json['updated_at']),
      );

  final int id;
  final int? appointmentId;
  final String provider;
  final int amountTiyin;
  final String type;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'appointment_id': appointmentId,
        'provider': provider,
        'amount_tiyin': amountTiyin,
        'type': type,
        'status': status,
        'created_at': createdAt == null ? null : Dates.toUnix(createdAt!),
        'updated_at': updatedAt == null ? null : Dates.toUnix(updatedAt!),
      };
}

/// POST /v1/payments/deposit (payme) response.
///
/// Deposit flow (both apps): POST Endpoints.paymentsDeposit body
/// `{"appointment_id": id, "provider": "payme"}`, idempotencyKey: Idempotency.deposit(id),
/// auth: RequestAuth.none; open [checkoutUrl]; then poll GET /v1/consumer/appointments/{id}
/// (Bizcat) every 5 s for up to 2 min, or until paid == true.
@immutable
final class DepositCheckout {
  const DepositCheckout({required this.transaction, this.provider = 'payme', this.checkoutUrl});

  factory DepositCheckout.fromJson(Map<String, dynamic> json) {
    final url = JsonRead.nonEmptyOrNull(json['checkout_url']);
    return DepositCheckout(
      transaction:
          PaymentTransaction.fromJson(JsonRead.objectOrNull(json['transaction']) ?? const <String, dynamic>{}),
      provider: JsonRead.nonEmptyOrNull(json['provider']) ?? 'payme',
      checkoutUrl: url == null ? null : Uri.tryParse(url.trim()),
    );
  }

  final PaymentTransaction transaction;
  final String provider;

  /// Open with url_launcher, external app.
  final Uri? checkoutUrl;

  Map<String, dynamic> toJson() => {
        'transaction': transaction.toJson(),
        'provider': provider,
        'checkout_url': checkoutUrl?.toString(),
      };
}
