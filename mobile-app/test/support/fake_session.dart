import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// [SessionNotifier] with a fixed initial state and recorded calls (no boot, no network).
///
/// Use: `sessionProvider.overrideWith(() => fake)` (pumpScreen does it for you).
class FakeSessionNotifier extends SessionNotifier {
  FakeSessionNotifier(this.initial);

  final SessionState initial;

  final List<({String phone, String password})> loginCalls = [];
  final List<int> switchCalls = [];
  int logoutCount = 0;
  int refreshMeCount = 0;
  int forbiddenCount = 0;
  int unauthorizedCount = 0;
  int completePickerCount = 0;

  /// Thrown by [login] / [switchBusiness] when set (e.g. an ApiException 401 / 403).
  Object? loginError;
  Object? switchError;

  /// Emitted after a successful [login] / [switchBusiness] when set.
  SessionState? afterLogin;
  SessionState? afterSwitch;

  @override
  SessionState build() => initial;

  /// Sets the state directly (drive the router / screens in tests).
  void emit(SessionState s) => state = s;

  @override
  Future<void> login(String phone, String password) async {
    loginCalls.add((phone: phone, password: password));
    final e = loginError;
    if (e != null) throw e;
    final next = afterLogin;
    if (next != null) state = next;
  }

  @override
  Future<void> switchBusiness(int businessId) async {
    switchCalls.add(businessId);
    final e = switchError;
    if (e != null) throw e;
    final next = afterSwitch;
    if (next != null) state = next;
  }

  @override
  void completePicker() {
    completePickerCount++;
    final s = state;
    if (s is SessionSignedIn) state = s.copyWith(needsPicker: false);
  }

  @override
  Future<void> refreshMe() async => refreshMeCount++;

  @override
  Future<void> onForbidden() async => forbiddenCount++;

  @override
  Future<void> onUnauthorized(ApiException e) async {
    unauthorizedCount++;
    state = const SessionSignedOut(message: kSessionExpiredMessage);
  }

  @override
  Future<void> logout() async {
    logoutCount++;
    state = const SessionSignedOut();
  }
}
