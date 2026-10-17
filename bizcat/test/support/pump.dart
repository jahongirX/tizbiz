import 'package:bizcat/app/app.dart';
import 'package:bizcat/app/router.dart';
import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/images.dart';
import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/core/prefs.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';
import 'fake_opener.dart';
import 'fixtures.dart';

/// What [pumpBizcat] returns.
final class TestHarness {
  TestHarness({required this.api, required this.opener, required this.container, required this.prefs});

  final FakeApi api;
  final FakeUrlOpener opener;
  final ProviderContainer container;
  final SharedPreferences prefs;

  GoRouter get router => container.read(routerProvider);

  /// The current location, e.g. '/login?from=%2Fprofile%2Fwallet'.
  String get location => router.state.uri.toString();

  SessionState get session => container.read(sessionProvider);
}

/// Pumps frames until nothing is scheduled (like pumpAndSettle, but never throws on endless
/// animations such as LoadingView or an indeterminate progress bar). Max [maxFrames] x [step].
Future<void> settle(WidgetTester t, {int maxFrames = 60, Duration step = const Duration(milliseconds: 50)}) async {
  for (var i = 0; i < maxFrames; i++) {
    await t.pump(step);
    if (!t.binding.hasScheduledFrame) break;
  }
}

/// Pumps the full app (router included) and navigates to [location].
///
/// - SharedPreferences mock values `{'bizcat.onboarded': true, ...prefs}`
/// - apiProvider -> `FakeApi.client(token: signedIn ? fakeConsumerToken() : null)` wired to the
///   session's 401 hook
/// - default fakes: GET /v1/consumer/me -> Fx.me (signed in), /v1/directory/categories ->
///   Fx.categories, /v1/directory/businesses -> Fx.cards, /v1/consumer/favorites -> []
///   ([setup] runs after them, and its registrations win)
/// - urlOpenerProvider -> FakeUrlOpener, netImagesEnabledProvider -> false
/// - retry off, `BizcatApp(googleFonts: false)`
///
/// It waits until the session is known (the splash is gone), then `router.go(location)`.
/// With [deepLink] true the app instead cold-starts AT [location] (splash -> `from`), which is
/// how a real deep link behaves.
Future<TestHarness> pumpBizcat(
  WidgetTester t, {
  String location = '/home',
  bool signedIn = false,
  Map<String, Object> prefs = const {},
  void Function(FakeApi api)? setup,
  List<Override> overrides = const [],
  bool deepLink = false,
}) async {
  SharedPreferences.setMockInitialValues({'bizcat.onboarded': true, ...prefs});
  final sp = await SharedPreferences.getInstance();
  final api = FakeApi()
    ..on('GET', '/v1/directory/categories', body: Fx.categories)
    ..on('GET', '/v1/directory/businesses', body: Fx.cards)
    ..on('GET', '/v1/consumer/favorites', body: Fx.emptyList);
  if (signedIn) api.on('GET', '/v1/consumer/me', body: Fx.me);
  setup?.call(api);
  final opener = FakeUrlOpener();

  await t.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      prefsProvider.overrideWithValue(sp),
      apiProvider.overrideWith((ref) {
        final client = api.client(
          token: signedIn ? fakeConsumerToken() : null,
          onUnauthorized: (_) => ref.read(sessionProvider.notifier).handleUnauthorized(),
        );
        ref.onDispose(client.close);
        return client;
      }),
      urlOpenerProvider.overrideWithValue(opener),
      netImagesEnabledProvider.overrideWithValue(false),
      if (deepLink) initialLocationProvider.overrideWithValue(location),
      ...overrides,
    ],
    child: const BizcatApp(googleFonts: false),
  ));

  final container = t.container();
  for (var i = 0; i < 200 && container.read(sessionProvider) is SessionUnknown; i++) {
    await t.pump(const Duration(milliseconds: 10));
  }
  await settle(t);

  final harness = TestHarness(api: api, opener: opener, container: container, prefs: sp);
  if (!deepLink && harness.location != location) {
    harness.router.go(location);
    await settle(t);
  }
  return harness;
}

/// Pumps a single widget (no router) inside ProviderScope + MaterialApp with the Bizcat light
/// theme (no google_fonts), the messenger key and the uz localizations, with the same fakes as
/// [pumpBizcat] (prefs, FakeApi, FakeUrlOpener, network images off). Use it for widgets and for
/// screens that do not navigate (e.g. the splash). Pass [router] to host the widget in a
/// MaterialApp.router instead (then [child] is ignored).
Future<({ProviderContainer container, FakeUrlOpener opener, FakeApi api})> pumpInApp(
  WidgetTester t,
  Widget child, {
  bool signedIn = false,
  Map<String, Object> prefs = const {},
  void Function(FakeApi api)? setup,
  List<Override> overrides = const [],
  bool wrapInScaffold = true,
  GoRouter? router,
}) async {
  SharedPreferences.setMockInitialValues({'bizcat.onboarded': true, ...prefs});
  final sp = await SharedPreferences.getInstance();
  final api = FakeApi()..on('GET', '/v1/consumer/favorites', body: Fx.emptyList);
  if (signedIn) api.on('GET', '/v1/consumer/me', body: Fx.me);
  setup?.call(api);
  final opener = FakeUrlOpener();
  final theme = AppTheme.light(googleFonts: false);
  const locale = Locale('uz');
  const locales = [Locale('uz'), Locale('ru'), Locale('en')];
  await t.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      prefsProvider.overrideWithValue(sp),
      apiProvider.overrideWith((ref) {
        final client = api.client(
          token: signedIn ? fakeConsumerToken() : null,
          onUnauthorized: (_) => ref.read(sessionProvider.notifier).handleUnauthorized(),
        );
        ref.onDispose(client.close);
        return client;
      }),
      urlOpenerProvider.overrideWithValue(opener),
      netImagesEnabledProvider.overrideWithValue(false),
      ...overrides,
    ],
    child: router != null
        ? MaterialApp.router(
            theme: theme,
            routerConfig: router,
            scaffoldMessengerKey: scaffoldMessengerKey,
            locale: locale,
            supportedLocales: locales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
          )
        : MaterialApp(
            theme: theme,
            scaffoldMessengerKey: scaffoldMessengerKey,
            locale: locale,
            supportedLocales: locales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: wrapInScaffold ? Scaffold(body: child) : child,
          ),
  ));
  final container = t.container();
  for (var i = 0; i < 200 && container.read(sessionProvider) is SessionUnknown; i++) {
    await t.pump(const Duration(milliseconds: 10));
  }
  await t.pump();
  return (container: container, opener: opener, api: api);
}
