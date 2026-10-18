import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import 'api.dart';
import 'city.dart';
import 'messenger.dart';
import 'prefs.dart';

/// Why the user is signed out.
enum SignOutReason { none, user, expired, deleted }

/// The consumer session (BIZCAT-SPEC §6.4).
sealed class SessionState {
  const SessionState();
}

/// Restore still running (the splash shows).
final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

final class SessionSignedOut extends SessionState {
  const SessionSignedOut([this.reason = SignOutReason.none]);

  final SignOutReason reason;

  @override
  bool operator ==(Object other) => other is SessionSignedOut && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'SessionSignedOut($reason)';
}

final class SessionSignedIn extends SessionState {
  const SessionSignedIn(this.consumer, {this.stale = false});

  final ConsumerUser consumer;

  /// true when restored offline from the cache.
  final bool stale;

  @override
  String toString() => 'SessionSignedIn(${consumer.id}, stale: $stale)';
}

/// The session state machine. Read `ref.watch(sessionProvider)`; act through `.notifier`.
final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  bool _restoring = false;

  /// Returns [SessionUnknown] and schedules [restore].
  @override
  SessionState build() {
    Future.microtask(restore);
    return const SessionUnknown();
  }

  ApiClient get _api => ref.read(apiProvider);
  AppPrefs get _prefs => ref.read(appPrefsProvider);

  /// Token -> GET /v1/consumer/me. Offline/server errors keep a stale signed-in session.
  Future<void> restore() async {
    if (_restoring) return;
    _restoring = true;
    try {
      final api = _api;
      final token = await api.currentToken();
      if (!ref.mounted) return;
      if (token == null) {
        if (state is SessionUnknown) state = const SessionSignedOut();
        return;
      }
      try {
        final me = await api.get<ConsumerUser>(
          Endpoints.consumerMe,
          decode: (d) => ConsumerUser.fromJson(JsonRead.object(d)),
        );
        if (!ref.mounted) return;
        if (state is SessionSignedOut) return; // signed out meanwhile
        state = SessionSignedIn(me);
        await _prefs.setCachedProfile(me);
      } on ApiException catch (e) {
        if (!ref.mounted) return;
        if (e.isUnauthorized) {
          // The 401 hook already ran (token cleared, state expired). Make sure we leave Unknown.
          if (state is! SessionSignedOut) state = const SessionSignedOut(SignOutReason.expired);
          return;
        }
        final claims = JwtClaims.tryParse(token);
        state = SessionSignedIn(_prefs.cachedProfile ?? ConsumerUser(id: claims?.sub ?? 0, phone: ''), stale: true);
      }
    } on Object catch (e) {
      debugPrint('session: restore failed: $e');
      if (ref.mounted && state is SessionUnknown) state = const SessionSignedOut();
    } finally {
      _restoring = false;
    }
  }

  /// After a successful OTP verify.
  Future<void> signIn(ConsumerSession s) async {
    await _api.setToken(s.token);
    if (!ref.mounted) return;
    state = SessionSignedIn(s.consumer);
    await _prefs.setCachedProfile(s.consumer);
    final city = s.consumer.city;
    if (_prefs.city == null && city != null && ref.mounted) {
      await ref.read(cityProvider.notifier).set(city);
    }
  }

  /// After PATCH /me or GET /me; also refreshes the cache. Ignored when signed out.
  void updateConsumer(ConsumerUser c) {
    if (state is! SessionSignedIn) return;
    state = SessionSignedIn(c);
    unawaited(_prefs.setCachedProfile(c));
  }

  /// GET /v1/consumer/me -> [updateConsumer]. Errors are ignored (a 401 runs the hook).
  Future<void> refreshProfile() async {
    if (state is! SessionSignedIn) return;
    try {
      final me = await _api.get<ConsumerUser>(
        Endpoints.consumerMe,
        decode: (d) => ConsumerUser.fromJson(JsonRead.object(d)),
      );
      if (!ref.mounted) return;
      updateConsumer(me);
    } on Object catch (e) {
      debugPrint('session: refreshProfile failed: $e');
    }
  }

  /// Clears the token and the cached profile. There is no server logout endpoint.
  Future<void> signOut({SignOutReason reason = SignOutReason.user}) async {
    await _api.clearToken();
    await _prefs.setCachedProfile(null);
    if (!ref.mounted) return;
    state = SessionSignedOut(reason);
  }

  /// The 401 hook: signed out (expired), cached profile cleared, one snackbar.
  void handleUnauthorized() {
    final current = state;
    if (current is SessionSignedOut && current.reason == SignOutReason.expired) return;
    state = const SessionSignedOut(SignOutReason.expired);
    unawaited(_prefs.setCachedProfile(null));
    showSnack('Sessiya tugadi. Qaytadan kiring.');
  }
}

/// Whether a consumer is signed in (stale sessions count).
final isSignedInProvider = Provider<bool>((ref) => ref.watch(sessionProvider) is SessionSignedIn);

/// The signed-in consumer, or null.
final currentConsumerProvider = Provider<ConsumerUser?>((ref) {
  final s = ref.watch(sessionProvider);
  return s is SessionSignedIn ? s.consumer : null;
});

/// Key for consumer-scoped providers: changes on sign-in, sign-out and account switch.
final consumerIdProvider = Provider<int?>((ref) => ref.watch(currentConsumerProvider.select((c) => c?.id)));
