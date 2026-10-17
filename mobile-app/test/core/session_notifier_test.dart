import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/prefs.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fake_http.dart';
import '../support/fixtures.dart';

final class _Harness {
  _Harness(this.container, this.http, this.store, this.prefs);

  final ProviderContainer container;
  final FakeHttp http;
  final InMemoryTokenStore store;
  final SharedPreferences prefs;

  SessionNotifier get notifier => container.read(sessionProvider.notifier);
  SessionState get state => container.read(sessionProvider);
  ApiClient get api => container.read(apiClientProvider);

  /// Reads the session and waits until it leaves SessionBooting.
  Future<SessionState> boot() async {
    container.read(sessionProvider);
    for (var i = 0; i < 50 && state is SessionBooting; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return state;
  }
}

Future<_Harness> _harness({String? token, Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final http = FakeHttp();
  final store = InMemoryTokenStore(token);
  final container = ProviderContainer.test(
    overrides: [
      prefsProvider.overrideWithValue(sp),
      clockProvider.overrideWithValue(() => kTestNow),
      tokenStoreProvider.overrideWithValue(store),
      apiClientProvider.overrideWith(
        (ref) => fakeApi(http, store: store, onUnauthorized: (e) => ref.read(sessionProvider.notifier).onUnauthorized(e)),
      ),
    ],
    retry: (retryCount, error) => null,
  );
  return _Harness(container, http, store, sp);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ownerToken = fakeBizToken();

  test('boot without a token -> SignedOut, no request', () async {
    final h = await _harness();
    expect(h.container.read(sessionProvider), isA<SessionBooting>());
    final s = await h.boot();
    expect(s, const SessionSignedOut());
    expect(h.http.requests, isEmpty);
  });

  test('boot with a token + me 200 -> SignedIn(epoch 1), cache written', () async {
    final h = await _harness(token: ownerToken);
    h.http.on('GET', Endpoints.authMe, body: envelope(jAuthMe()));
    final s = await h.boot();
    expect(s, isA<SessionSignedIn>());
    final signed = s as SessionSignedIn;
    expect(signed.epoch, 1);
    expect(signed.fromCache, isFalse);
    expect(signed.needsPicker, isFalse);
    expect(signed.session.token, ownerToken);
    expect(signed.session.user.id, 4);
    expect(h.http.requests.single.headers['authorization'], 'Bearer $ownerToken');
    expect(h.prefs.getString(kLastMePrefKey), isNotNull);
    final a = h.container.read(activeBusinessProvider)!;
    expect((a.businessId, a.slug, a.isOwner), (2, 'shox-barber', true));
  });

  test('boot: me 401 -> SignedOut with the message, token cleared', () async {
    final h = await _harness(token: ownerToken);
    h.http.on('GET', Endpoints.authMe, status: 401, body: apiError(401, 'Your request was made with invalid credentials.'));
    final s = await h.boot();
    expect(s, const SessionSignedOut(message: kSessionExpiredMessage));
    expect(h.store.value, isNull);
  });

  test('boot offline with a matching cache -> SignedIn(fromCache)', () async {
    final cached = jsonEncode(AuthMe.fromJson(jAuthMe()).toJson());
    final h = await _harness(token: ownerToken, prefs: {kLastMePrefKey: cached});
    h.http.offline = true;
    final s = await h.boot();
    expect(s, isA<SessionSignedIn>());
    expect((s as SessionSignedIn).fromCache, isTrue);
    expect(s.session.active.businessId, 2);
  });

  test('boot offline without a cache -> SignedOut with the network message', () async {
    final h = await _harness(token: ownerToken);
    h.http.offline = true;
    final s = await h.boot();
    expect(s, isA<SessionSignedOut>());
    expect((s as SessionSignedOut).message, contains('Internet'));
  });

  test('login stores the token, sends the normalized phone, needsPicker with 2 businesses', () async {
    final h = await _harness();
    await h.boot();
    final token = fakeBizToken();
    h.http.on('POST', Endpoints.login, body: envelope(jLogin(token: token, businesses: [
      jMembership(),
      jMembership(id: 3, name: 'Aziza Tortlari', slug: 'aziza-tortlari', category: 'cafe', engine: Engine.catalog),
    ])));
    await h.notifier.login('90 111 11 11', 'secret123');
    final req = h.http.calls(Endpoints.login).single;
    expect(req.body, {'phone': '+998901111111', 'password': 'secret123'});
    expect(req.headers.containsKey('authorization'), isFalse);
    expect(h.store.value, token);
    final s = h.state as SessionSignedIn;
    expect(s.needsPicker, isTrue);
    expect(s.epoch, 1);
    h.notifier.completePicker();
    expect((h.state as SessionSignedIn).needsPicker, isFalse);
  });

  test('login 401 rethrows and does not log anybody out', () async {
    final h = await _harness();
    await h.boot();
    h.http.on('POST', Endpoints.login, status: 401, body: apiError(401, "Telefon yoki parol noto'g'ri."));
    await expectLater(
      h.notifier.login('901111111', 'bad'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', "Telefon yoki parol noto'g'ri.")),
    );
    expect(h.state, const SessionSignedOut());
  });

  test('switch replaces the token and bumps the epoch', () async {
    final h = await _harness(token: ownerToken);
    h.http.on('GET', Endpoints.authMe, body: envelope(jAuthMe(businesses: [
      jMembership(),
      jMembership(id: 3, name: 'Aziza Tortlari', slug: 'aziza-tortlari', category: 'cafe', engine: Engine.catalog),
    ])));
    await h.boot();
    final switched = fakeBizToken(tid: 3);
    h.http.on('POST', Endpoints.switchBusiness(3), body: envelope({
      'token': switched,
      'expires_at': Dates.toUnix(kTestNow.add(const Duration(days: 7))),
      'active': jActive(businessId: 3),
    }));
    h.http.on('GET', Endpoints.authMe, body: envelope(jAuthMe(activeBusinessId: 3, businesses: [
      jMembership(),
      jMembership(id: 3, name: 'Aziza Tortlari', slug: 'aziza-tortlari', category: 'cafe', engine: Engine.catalog),
    ])));
    await h.notifier.switchBusiness(3);
    final s = h.state as SessionSignedIn;
    expect(s.epoch, 2);
    expect(s.session.token, switched);
    expect(h.store.value, switched);
    expect(h.container.read(activeBusinessProvider)!.engine, Engine.catalog);
    expect(h.http.requests.last.headers['authorization'], 'Bearer $switched');
  });

  test('a 401 on any later request -> SignedOut(Sessiya tugadi...)', () async {
    final h = await _harness(token: ownerToken);
    h.http.on('GET', Endpoints.authMe, body: envelope(jAuthMe()));
    await h.boot();
    h.http.on('GET', Endpoints.clients, status: 401, body: apiError(401, 'Your request was made with invalid credentials.'));
    await expectLater(h.api.getPage(Endpoints.clients, Client.fromJson), throwsA(isA<ApiException>()));
    expect(h.state, const SessionSignedOut(message: kSessionExpiredMessage));
    expect(h.store.value, isNull);
    expect(h.prefs.getString(kLastMePrefKey), isNull);
  });

  test('refreshMe replaces active and keeps the epoch; onForbidden is throttled', () async {
    final h = await _harness(token: ownerToken);
    h.http.on('GET', Endpoints.authMe, body: envelope(jAuthMe()));
    await h.boot();
    h.http.on('GET', Endpoints.authMe, body: envelope(jAuthMe(role: BizRole.admin)));
    await h.notifier.onForbidden();
    expect((h.state as SessionSignedIn).epoch, 1);
    expect(h.container.read(activeBusinessProvider)!.role, BizRole.admin);
    final before = h.http.calls(Endpoints.authMe).length;
    await h.notifier.onForbidden();
    expect(h.http.calls(Endpoints.authMe).length, before, reason: 'second call within 30 s is throttled');
  });

  test('logout clears token and cache', () async {
    final h = await _harness(token: ownerToken);
    h.http.on('GET', Endpoints.authMe, body: envelope(jAuthMe()));
    await h.boot();
    await h.notifier.logout();
    expect(h.state, const SessionSignedOut());
    expect(h.store.value, isNull);
    expect(h.prefs.getString(kLastMePrefKey), isNull);
  });

  test('an expired stored token boots signed out without a request', () async {
    final h = await _harness(token: fakeBizToken(exp: kTestNow.subtract(const Duration(hours: 1))));
    final s = await h.boot();
    expect(s, const SessionSignedOut());
    expect(h.http.requests, isEmpty);
  });
}
