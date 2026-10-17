import 'package:flutter/foundation.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Shown on the login screen after a 401 / token expiry.
const kSessionExpiredMessage = 'Sessiya tugadi. Qaytadan kiring.';

/// The business app's session.
@immutable
sealed class SessionState {
  const SessionState();
}

/// Reading the stored token and `/v1/auth/me` (splash).
final class SessionBooting extends SessionState {
  const SessionBooting();

  @override
  bool operator ==(Object other) => other is SessionBooting;

  @override
  int get hashCode => (SessionBooting).hashCode;
}

final class SessionSignedOut extends SessionState {
  const SessionSignedOut({this.message});

  /// Banner on the login screen ('Sessiya tugadi. Qaytadan kiring.').
  final String? message;

  @override
  bool operator ==(Object other) => other is SessionSignedOut && other.message == message;

  @override
  int get hashCode => Object.hash(SessionSignedOut, message);
}

final class SessionSignedIn extends SessionState {
  const SessionSignedIn({
    required this.session,
    required this.epoch,
    this.needsPicker = false,
    this.fromCache = false,
  });

  /// token, user, businesses, active.
  final AuthSession session;

  /// +1 on every login and switch; the router is rebuilt per epoch.
  final int epoch;

  /// true right after a login with businesses.length > 1.
  final bool needsPicker;

  /// Booted offline from the cached `/auth/me`.
  final bool fromCache;

  SessionSignedIn copyWith({AuthSession? session, int? epoch, bool? needsPicker, bool? fromCache}) =>
      SessionSignedIn(
        session: session ?? this.session,
        epoch: epoch ?? this.epoch,
        needsPicker: needsPicker ?? this.needsPicker,
        fromCache: fromCache ?? this.fromCache,
      );
}
