import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/prefs.dart';
import 'package:tizbiz_biznes/core/session/session_state.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

export 'package:tizbiz_biznes/core/session/session_state.dart';

/// Prefs key of the cached `/v1/auth/me` (offline boot).
const kLastMePrefKey = 'tizbiz_last_me';

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

/// Login, business switch, `/auth/me` refresh and logout (BIZNES-SPEC §5.3).
class SessionNotifier extends Notifier<SessionState> {
  Timer? _expiryTimer;
  int _epoch = 0;
  DateTime? _lastForbiddenRefresh;

  ApiClient get _api => ref.read(apiClientProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  SessionState build() {
    ref.onDispose(_cancelExpiry);
    Future.microtask(_boot);
    return const SessionBooting();
  }

  // ---------------------------------------------------------------- boot

  Future<void> _boot() async {
    final api = _api;
    final String? token;
    try {
      token = await api.currentToken();
    } on Object catch (e) {
      debugPrint('session boot: token read failed: $e');
      if (ref.mounted) state = const SessionSignedOut();
      return;
    }
    if (!ref.mounted || state is! SessionBooting) return;
    if (token == null) {
      state = const SessionSignedOut();
      return;
    }
    final claims = JwtClaims.tryParse(token);
    try {
      final me = await _fetchMe(api);
      if (!ref.mounted || state is! SessionBooting) return;
      await _writeCache(me);
      _epoch++;
      _setSignedIn(SessionSignedIn(
        session: AuthSession(
          token: token,
          expiresAt: claims?.expiresAt,
          user: me.user,
          businesses: me.businesses,
          active: me.active,
        ),
        epoch: _epoch,
      ));
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      if (e.isUnauthorized) {
        // The ApiClient hook has already fired (onUnauthorized); make sure we end signed out.
        if (state is! SessionSignedOut) state = const SessionSignedOut(message: kSessionExpiredMessage);
        return;
      }
      if (state is! SessionBooting) return;
      if (e.isNetwork) {
        final cached = _readCache();
        if (cached != null &&
            claims != null &&
            cached.user.id == claims.sub &&
            cached.active.businessId == claims.tenantId) {
          _epoch++;
          _setSignedIn(SessionSignedIn(
            session: AuthSession(
              token: token,
              expiresAt: claims.expiresAt,
              user: cached.user,
              businesses: cached.businesses,
              active: cached.active,
            ),
            epoch: _epoch,
            fromCache: true,
          ));
          return;
        }
      }
      state = SessionSignedOut(message: e.message);
    } on Object catch (e) {
      debugPrint('session boot failed: $e');
      if (ref.mounted && state is SessionBooting) state = const SessionSignedOut();
    }
  }

  // ---------------------------------------------------------------- actions

  /// POST /v1/auth/login. Rethrows [ApiException] for the form (401: 'Telefon yoki parol noto'g'ri.').
  /// Navigation happens through the router redirect.
  Future<void> login(String phone, String password) async {
    final api = _api;
    final session = await api.post<AuthSession>(
      Endpoints.login,
      body: {'phone': Phone.normalize(phone) ?? phone.trim(), 'password': password},
      auth: RequestAuth.none,
      decode: (d) => AuthSession.fromJson(JsonRead.object(d)),
    );
    await api.setToken(session.token);
    await _writeCache(AuthMe(user: session.user, active: session.active, businesses: session.businesses));
    if (!ref.mounted) return;
    _epoch++;
    _setSignedIn(SessionSignedIn(session: session, epoch: _epoch, needsPicker: session.businesses.length > 1));
  }

  /// POST /v1/auth/switch/{id}, then GET /v1/auth/me. Rethrows the switch error
  /// (403 'Siz bu biznesning a'zosi emassiz.' / 'Bu biznes faol emas.').
  Future<void> switchBusiness(int businessId) async {
    final current = state;
    if (current is! SessionSignedIn) throw StateError('switchBusiness while signed out');
    final api = _api;
    final result = await api.post<SwitchResult>(
      Endpoints.switchBusiness(businessId),
      decode: (d) => SwitchResult.fromJson(JsonRead.object(d)),
    );
    await api.setToken(result.token);
    var session = current.session.withSwitch(result);
    try {
      final me = await _fetchMe(api);
      session = session.withMe(me);
      await _writeCache(me);
    } on ApiException catch (e) {
      // The new token is already stored: keep the switch result's `active` (consistent with it).
      if (e.isUnauthorized) return;
      debugPrint('switchBusiness: /auth/me failed: ${e.message}');
      await _writeCache(AuthMe(user: session.user, active: session.active, businesses: session.businesses));
    }
    if (!ref.mounted) return;
    _epoch++;
    _setSignedIn(SessionSignedIn(session: session, epoch: _epoch));
  }

  /// The business chosen in the picker is already active.
  void completePicker() {
    final s = state;
    if (s is SessionSignedIn && s.needsPicker) state = s.copyWith(needsPicker: false);
  }

  /// GET /v1/auth/me; replaces user/businesses/active, keeps the epoch. Errors are swallowed
  /// (401 is handled by the ApiClient hook).
  Future<void> refreshMe() async {
    if (state is! SessionSignedIn) return;
    try {
      final me = await _fetchMe(_api);
      if (!ref.mounted) return;
      final s = state;
      if (s is! SessionSignedIn) return;
      await _writeCache(me);
      if (!ref.mounted) return;
      state = s.copyWith(session: s.session.withMe(me), fromCache: false);
    } on ApiException catch (e) {
      debugPrint('refreshMe failed: ${e.message}');
    }
  }

  /// Throttled [refreshMe] (at most once per 30 s): a 403 or a staff "not linked" 404 may mean the
  /// member's role or link changed, so the router can move them to the right shell.
  Future<void> onForbidden() async {
    final now = _now();
    final last = _lastForbiddenRefresh;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) return;
    _lastForbiddenRefresh = now;
    await refreshMe();
  }

  /// The ApiClient's 401 hook (also called by the expiry timer and ErrorView).
  Future<void> onUnauthorized(ApiException e) async {
    if (state is SessionSignedOut) return;
    _cancelExpiry();
    state = const SessionSignedOut(message: kSessionExpiredMessage);
    await _api.clearToken();
    await _removeCache();
  }

  /// There is no server logout endpoint: forget the token locally.
  Future<void> logout() async {
    _cancelExpiry();
    state = const SessionSignedOut();
    await _api.clearToken();
    await _removeCache();
  }

  // ---------------------------------------------------------------- helpers

  Future<AuthMe> _fetchMe(ApiClient api) =>
      api.get<AuthMe>(Endpoints.authMe, decode: (d) => AuthMe.fromJson(JsonRead.object(d)));

  void _setSignedIn(SessionSignedIn next) {
    state = next;
    _scheduleExpiry(next.session.expiresAt);
  }

  /// ApiClient silently drops an expired token, so the following 401 carries no Authorization
  /// header and the hook would not fire: log out at `expiresAt` ourselves.
  void _scheduleExpiry(DateTime? expiresAt) {
    _cancelExpiry();
    if (expiresAt == null) return;
    var left = expiresAt.difference(_now());
    if (left.isNegative) left = Duration.zero;
    _expiryTimer = Timer(left, () {
      unawaited(onUnauthorized(const ApiException(kind: ApiErrorKind.http, status: 401)));
    });
  }

  void _cancelExpiry() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }

  AuthMe? _readCache() {
    try {
      final raw = ref.read(prefsProvider).getString(kLastMePrefKey);
      if (raw == null || raw.isEmpty) return null;
      return AuthMe.fromJson(JsonRead.object(jsonDecode(raw)));
    } on Object catch (e) {
      debugPrint('session cache unreadable: $e');
      return null;
    }
  }

  Future<void> _writeCache(AuthMe me) async {
    try {
      await ref.read(prefsProvider).setString(kLastMePrefKey, jsonEncode(me.toJson()));
    } on Object catch (e) {
      debugPrint('session cache write failed: $e');
    }
  }

  Future<void> _removeCache() async {
    try {
      await ref.read(prefsProvider).remove(kLastMePrefKey);
    } on Object catch (e) {
      debugPrint('session cache remove failed: $e');
    }
  }
}
