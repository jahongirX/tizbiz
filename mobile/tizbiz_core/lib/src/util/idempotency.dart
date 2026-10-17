import 'dart:math';

import '../models/enums.dart';

/// Idempotency keys for booking, order and deposit creation.
abstract final class Idempotency {
  static const String header = 'Idempotency-Key';

  /// RFC 4122 version-4 UUID, lowercase, 36 chars 'xxxxxxxx-xxxx-4xxx-Yxxx-xxxxxxxxxxxx' with Y in
  /// [89ab]. Uses Random.secure() unless [random] is given (tests). No extra dependency.
  static String newKey([Random? random]) {
    final r = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Stable deposit key per appointment + provider, as in BACKEND-PLAN §4.5: 'dep-5012-payme'.
  /// Re-tapping "To'lash" must reuse it so the server replays the same Payme checkout
  /// (no double charge).
  static String deposit(int appointmentId, {PaymentProvider provider = PaymentProvider.payme}) =>
      'dep-$appointmentId-${provider.wire}';
}
