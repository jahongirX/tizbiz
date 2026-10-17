import 'package:tizbiz_core/tizbiz_core.dart';

import 'deposit.dart';

/// User-facing Uzbek text for any error.
String errorText(Object error) {
  if (error is ApiException) return error.message;
  if (error is DepositLaunchException) return "To'lov sahifasini ochib bo'lmadi.";
  return 'Xatolik yuz berdi.';
}

/// Transport failure (no connection or timeout).
bool isOffline(Object error) => error is ApiException && error.isNetwork;
