import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tizbiz_biznes/app/app.dart';
import 'package:tizbiz_biznes/app/shells/manager_shell.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/prefs.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/features/auth/login_screen.dart';
import 'package:tizbiz_biznes/features/dashboard/dashboard_screen.dart';
import 'package:tizbiz_biznes/shared/polling.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/test_app.dart';

/// The real app with the real SessionNotifier on a FakeHttp backend.
Future<FakeHttp> _pumpApp(WidgetTester tester, {String? token, void Function(FakeHttp http)? routes}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final http = FakeHttp();
  routes?.call(http);
  final store = InMemoryTokenStore(token);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => kTestNow),
      pollingEnabledProvider.overrideWithValue(false),
      tokenStoreProvider.overrideWithValue(store),
      apiClientProvider.overrideWith(
        (ref) => fakeApi(http, store: store, onUnauthorized: (e) => ref.read(sessionProvider.notifier).onUnauthorized(e)),
      ),
    ],
    retry: (retryCount, error) => null,
    child: const TizbizApp(),
  ));
  await settleRoutes(tester);
  return http;
}

void main() {
  testWidgets('no token: splash -> login', (tester) async {
    await _pumpApp(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('stored token + /auth/me: lands on the dashboard of the manager shell', (tester) async {
    final http = await _pumpApp(
      tester,
      token: fakeBizToken(),
      routes: (h) => h.on('GET', Endpoints.authMe, body: envelope(jAuthMe())),
    );
    expect(http.calls(Endpoints.authMe), hasLength(1));
    expect(find.byType(ManagerShell), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Navbatlar'), findsWidgets);
  });

  testWidgets('a 401 from /auth/me ends on the login screen', (tester) async {
    await _pumpApp(
      tester,
      token: fakeBizToken(),
      routes: (h) => h.on('GET', Endpoints.authMe, status: 401, body: apiError(401, 'Your request was made with invalid credentials.')),
    );
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
