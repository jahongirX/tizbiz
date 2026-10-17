// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tizbiz_biznes/app/app.dart';
import 'package:tizbiz_biznes/app/router.dart';
import 'package:tizbiz_biznes/app/theme/app_theme.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/prefs.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/shared/polling.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import 'fake_http.dart';
import 'fake_session.dart';
import 'fixtures.dart';

export 'fake_http.dart';
export 'fake_session.dart';
export 'fixtures.dart';

/// The fake HTTP adapter behind the default `apiClientProvider` of the last pump (unless the test
/// overrode `apiClientProvider` itself). Unmatched requests answer 404.
late FakeHttp lastFakeHttp;

/// The container of the last [pumpRouterAt].
late ProviderContainer lastContainer;

/// The default overrides of every pump: prefs (mock), clock pinned to [kTestNow], polling off,
/// a [FakeHttp]-backed ApiClient and the [FakeSessionNotifier]. A default is skipped when
/// [overrides] already overrides the same provider.
Future<List<Override>> _defaults(FakeSessionNotifier session, List<Override> overrides, {FakeHttp? http, Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final taken = {for (final o in overrides) o.origin};
  lastFakeHttp = http ?? FakeHttp();
  final token = session.initial is SessionSignedIn ? (session.initial as SessionSignedIn).session.token : null;
  return [
    if (!taken.contains(prefsProvider)) prefsProvider.overrideWithValue(sp),
    if (!taken.contains(clockProvider)) clockProvider.overrideWithValue(() => kTestNow),
    if (!taken.contains(pollingEnabledProvider)) pollingEnabledProvider.overrideWithValue(false),
    if (!taken.contains(apiClientProvider)) apiClientProvider.overrideWithValue(fakeApi(lastFakeHttp, token: token)),
    if (!taken.contains(sessionProvider)) sessionProvider.overrideWith(() => session),
    ...overrides,
  ];
}

/// Pumps [child] inside ProviderScope + MaterialApp (material_ui) with the app theme, uz locale,
/// pollingEnabledProvider=false, clockProvider fixed to 2026-10-17 07:00Z, and a
/// FakeSessionNotifier signed in as [role] of a demo business of [engine].
///
/// [category] null = the engine's demo category (barber / cafe / clinic / rental).
/// [session] replaces the whole initial state (e.g. `fxSignedIn(businesses: [...])`).
Future<FakeSessionNotifier> pumpScreen(
  WidgetTester tester,
  Widget child, {
  BizRole role = BizRole.owner,
  Engine engine = Engine.slot,
  int? staffId,
  String? category,
  List<Override> overrides = const [],
  ThemeMode themeMode = ThemeMode.light,
  SessionState? session,
  FakeHttp? http,
}) async {
  final fake = FakeSessionNotifier(session ?? fxSignedIn(role: role, engine: engine, staffId: staffId, category: category));
  final all = await _defaults(fake, overrides, http: http);
  await tester.pumpWidget(ProviderScope(
    overrides: all,
    retry: (retryCount, error) => null,
    child: _TestMaterialApp(themeMode: themeMode, home: child),
  ));
  await tester.pump();
  return fake;
}

class _TestMaterialApp extends ConsumerWidget {
  const _TestMaterialApp({required this.themeMode, required this.home});

  final ThemeMode themeMode;
  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(activeBusinessProvider.select((a) => a?.vertical.accent));
    return MaterialApp(
      theme: AppTheme.light(accent),
      darkTheme: AppTheme.dark(accent),
      themeMode: themeMode,
      locale: const Locale('uz'),
      supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    );
  }
}

/// Same as [pumpScreen] but boots the real app router (TizbizApp) and navigates to [location]
/// (for route / redirect smoke tests). Returns the fake session.
Future<FakeSessionNotifier> pumpRouterAt(
  WidgetTester tester,
  String location, {
  BizRole role = BizRole.owner,
  Engine engine = Engine.slot,
  int? staffId,
  String? category,
  List<Override> overrides = const [],
  SessionState? session,
  FakeHttp? http,
}) async {
  final fake = FakeSessionNotifier(session ?? fxSignedIn(role: role, engine: engine, staffId: staffId, category: category));
  final all = await _defaults(fake, overrides, http: http);
  final container = ProviderContainer.test(overrides: all, retry: (retryCount, error) => null);
  lastContainer = container;
  // A fresh tree per call (several pumps in one test must not share navigator state).
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const TizbizApp()));
  await tester.pump();
  container.read(routerProvider).go(location);
  await settleRoutes(tester);
  return fake;
}

/// Pumps enough frames for redirects and page transitions (no pumpAndSettle: spinners never settle).
Future<void> settleRoutes(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// The location the app router of the last [pumpRouterAt] shows now (after redirects).
String currentLocation() => lastContainer.read(routerProvider).state.uri.toString();
