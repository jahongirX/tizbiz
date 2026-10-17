# Business app spec: `mobile-app/` ("TizBiz Biznes")

Status: **source of truth** for every agent that builds the Flutter business app at
`/Users/jahongirxushboqov/Sites/startup/mobile-app`. Written 2026-10-17 against
`docs/mobile/BACKEND-PLAN.md` (BP, the API contract), `docs/mobile/CORE-SPEC.md` (CS, the shared
`tizbiz_core` package: API client, models, formatting) and the server controllers on `main`.

The app is used by business owners, administrators and staff (barbers, doctors, cooks). One app,
two shells: the **manager shell** (`business_owner`, `business_admin`) mirrors the web cabinet
`apps/admin`; the **staff shell** (`staff`) shows only the member's own work through `/v1/me/*`.

Hard rules (every agent):

1. **Contract first.** Endpoint paths come from `Endpoints`, query encodings from `ApiQuery`,
   models and request bodies from `tizbiz_core` (CS §3, §10). The app never hand-writes a path, a
   JSON key or a date encoding. If something is missing in the core, stop and report it; do not
   add it locally.
2. **Port behaviour from the server, not from the web views.** `apps/admin` has known bugs
   (critic): `Schedule.vue` sends `{days:[...]}` and Sunday = 0 (wipes working hours), time-off
   sends `{starts_at, ends_at}` (always 422), `Analytics.vue` sends datetimes (period ignored),
   `Timetable.vue` offers transitions the server rejects. This spec gives the server truth.
3. **One Material library: `package:material_ui/material_ui.dart`.** go_router 18 and
   cached_network_image 4 are built on the decoupled `material_ui` package (Flutter 3.47). Never
   import `package:flutter/material.dart` anywhere in `lib/` or `test/` (two different `Theme` /
   `MaterialApp` types would otherwise coexist). Widgets-only imports (`package:flutter/widgets.dart`,
   `services.dart`, `foundation.dart`) are fine.
4. **Parallel safety.** A feature agent edits only files inside its own `lib/features/<feature>/`
   and `test/features/<feature>/`. Everything else is owned by the skeleton agent (§15).
5. UI text is Uzbek (Latin). Code, comments and commit messages are English. Money is tiyin
   (`Money.format`), API instants are UTC (`Dates.parseUtc`), display uses the business zone
   (`Asia/Tashkent`, fixed +05:00).
6. No push, no Firebase, no code generation (no freezed/json_serializable/build_runner/riverpod_generator).

---

## 1. Project setup (skeleton agent)

### 1.1 Create

```bash
cd /Users/jahongirxushboqov/Sites/startup
~/development/flutter/bin/flutter create --org uz.tizbiz --project-name tizbiz_biznes \
  --platforms android,ios,web --description "TizBiz Biznes: biznes egalari va xodimlar ilovasi" mobile-app
cd mobile-app && ~/development/flutter/bin/dart fix --apply --code=migrate_design_widgets   # material -> material_ui
```

Then fix identifiers (flutter create derives `uz.tizbiz.tizbiz_biznes`):

| Where | Value |
|---|---|
| `android/app/build.gradle(.kts)` `namespace` and `applicationId` | `uz.tizbiz.biznes` |
| `android/app/build.gradle(.kts)` `minSdk` | `23` (flutter_secure_storage) |
| `android/app/src/main/AndroidManifest.xml` | `android:label="TizBiz Biznes"`; `<uses-permission android:name="android.permission.INTERNET"/>`; `<queries>` with `ACTION_VIEW` for schemes `tel` and `https` (url_launcher on Android 11+) |
| move `MainActivity.kt` to package `uz.tizbiz.biznes` | |
| `ios/Runner.xcodeproj/project.pbxproj` `PRODUCT_BUNDLE_IDENTIFIER` | `uz.tizbiz.biznes` (and `.RunnerTests`) |
| `ios/Runner/Info.plist` | `CFBundleDisplayName` = `TizBiz Biznes`; `LSApplicationQueriesSchemes` = `[tel, https]` |
| `web/index.html` `<title>`, `web/manifest.json` `name`/`short_name` | `TizBiz Biznes` / `TizBiz`; `theme_color` `#2563EB`, `background_color` `#F5F6F8` |

No Android SDK or Xcode on this machine: platform folders are generated and edited but only
`flutter build web` is verified locally.

### 1.2 `pubspec.yaml`

```yaml
name: tizbiz_biznes
description: TizBiz Biznes - business owner and staff app.
publish_to: none
version: 0.1.0+1

environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  flutter:
    sdk: flutter
  material_ui: ^1.6.0
  cupertino_ui: ^1.1.0
  tizbiz_core:
    path: ../mobile/tizbiz_core
  flutter_riverpod: ^3.4.3
  go_router: ^18.0.2
  dio: ^5.9.0                 # only for tests' fake adapter and CancelToken typing; requests go through ApiClient
  flutter_svg: ^2.3.0
  intl: ^0.20.2
  url_launcher: ^6.3.2
  cached_network_image: ^4.0.4
  flutter_secure_storage: any # pin to the version `flutter pub add flutter_secure_storage` resolves
  shared_preferences: ^2.5.0
  fl_chart: any               # pin to the version `flutter pub add fl_chart` resolves (expected 1.x)

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/brand/
```

After `flutter pub get`, replace both `any` constraints with `^<resolved version>`. `google_fonts`
is **not** used in this app (the web cabinet uses the platform system font; it also keeps tests
offline).

`analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml
analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
linter:
  rules:
    - prefer_const_constructors
    - prefer_final_locals
    - always_declare_return_types
    - unawaited_futures
    - avoid_print
    - directives_ordering
```

### 1.3 Assets

| File | Source |
|---|---|
| `assets/brand/tizbiz-logo.png` | copy of `apps/admin/src/assets/logo.png` |
| `assets/brand/tizbiz-icon.png` | copy of `apps/admin/public/favicon.png` |
| `web/favicon.png` | copy of `apps/admin/public/favicon.png` |
| `web/icons/Icon-192.png`, `Icon-512.png`, `Icon-maskable-*.png` | `sips -z 192 192` / `-z 512 512` from `apps/admin/public/logo.png` |

Launcher icons for Android/iOS stay the Flutter defaults in this iteration (no
flutter_launcher_icons in the allowed list).

### 1.4 dart-define

| Define | Default | Use |
|---|---|---|
| `API_BASE` | `https://api.tizbiz.uz` | read only through `ApiConfig.fromEnvironment()` (CS §3.1) |
| `DEMO_LOGINS` | `false` | `true` shows demo login chips on the login screen (also shown in `kDebugMode`) |

```bash
# local API: php -S 127.0.0.1:8899 -t api/web api/web/router.php   (from repo root)
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8899 --dart-define=DEMO_LOGINS=true
flutter build web --release --dart-define=API_BASE=https://api.tizbiz.uz
```

`lib/core/env.dart`:

```dart
abstract final class Env {
  static const bool demoLogins = bool.fromEnvironment('DEMO_LOGINS');
  static const String appVersion = '0.1.0';
}
```

---

## 2. Folder layout

```
mobile-app/
  pubspec.yaml  analysis_options.yaml  README.md
  assets/brand/tizbiz-logo.png  assets/brand/tizbiz-icon.png
  lib/
    main.dart                                  # S: bootstrap (prefs, ProviderScope)
    app/                                       # S: app shell, routing, theme
      app.dart                                 # TizbizApp (MaterialApp.router)
      routes.dart                              # Routes: every path constant + builders
      router.dart                              # routerProvider (GoRouter, all routes)
      redirect.dart                            # computeRedirect(): pure redirect function
      not_found_screen.dart                    # NotFoundScreen
      splash_screen.dart                       # SplashScreen
      shells/manager_shell.dart                # ManagerShell (bottom nav, offline banner)
      shells/staff_shell.dart                  # StaffShell
      shells/nav_items.dart                    # managerNavItems(), staffNavItems()
      more/more_menu_screen.dart               # MoreMenuScreen ("Ko'proq")
      theme/app_theme.dart                     # AppTheme.light/dark(accent)
      theme/app_colors.dart                    # AppColors ThemeExtension + status colours
      theme/vertical.dart                      # Vertical (accent, icon, label per category)
    core/                                      # S: session + infrastructure providers
      env.dart
      clock.dart                               # clockProvider
      prefs.dart                               # prefsProvider (SharedPreferences)
      secure_token_store.dart                  # SecureTokenStore implements TokenStore
      api_providers.dart                       # tokenStoreProvider, apiClientProvider
      session/session_state.dart               # SessionState (sealed)
      session/session_notifier.dart            # SessionNotifier, sessionProvider
      session/active_business.dart             # ActiveBusiness, activeBusinessProvider, requireActive()
      theme_mode.dart                          # themeModeProvider
    shared/                                    # S: reusable widgets, helpers, shared data providers
      data/revisions.dart                      # revision counters for cross-feature refresh
      data/catalog_data.dart                   # staffListProvider, activeStaffProvider, servicesListProvider, serviceCategoriesProvider
      data/schedule_data.dart                  # workingHoursProvider(staffId), timeOffProvider(staffId)
      format.dart                              # bizTime(), fmtDayTime(), source labels, status action labels
      polling.dart                             # kPollInterval, pollingEnabledProvider, PollWhileVisible
      widgets/*.dart                           # see §8
    features/                                  # F: one folder per feature, see §15
      auth/            dashboard/       timetable/     appointments/   orders/
      clients/         catalog/         staff_admin/   money/          reviews/
      settings/        team/            me_day/        me/
  test/
    support/                                   # S: test harness
      test_app.dart  fake_session.dart  fake_http.dart  fixtures.dart
    app/  core/  shared/                       # S: skeleton tests
    features/<feature>/                        # F: feature tests
```

`S` = skeleton agent, `F` = the feature agent that owns the folder. All imports are package
imports (`package:tizbiz_biznes/...`). A feature imports only `package:tizbiz_core/tizbiz_core.dart`,
`package:tizbiz_biznes/core/...`, `package:tizbiz_biznes/shared/...`, `package:tizbiz_biznes/app/routes.dart`
and `package:tizbiz_biznes/app/theme/...`. **A feature never imports another feature.**

---

## 3. Bootstrap

### 3.1 `lib/main.dart`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    retry: (retryCount, error) => null,   // Riverpod 3 auto-retry OFF: errors surface immediately, tests stay deterministic
    child: const TizbizApp(),
  ));
}
```

### 3.2 `lib/app/app.dart`

```dart
class TizbizApp extends ConsumerWidget {
  // MaterialApp.router(
  //   title: 'TizBiz Biznes',
  //   routerConfig: ref.watch(routerProvider),
  //   theme: AppTheme.light(accent), darkTheme: AppTheme.dark(accent), themeMode: ref.watch(themeModeProvider),
  //   locale: const Locale('uz'),
  //   supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
  //   localizationsDelegates: GlobalMaterialLocalizations.delegates,   // from material_ui
  //   builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
  // )
  // accent = ref.watch(activeBusinessProvider)?.vertical.accent ?? AppTheme.defaultPrimary(brightness)
}
```

`lib/core/clock.dart`: `final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);`
Every "today"/"now" in the app is `ref.read(clockProvider)()` (tests pin it to
`DateTime.utc(2026, 10, 17, 7)`, i.e. Saturday 17 Oct 2026, 12:00 Tashkent).

`lib/core/theme_mode.dart`: `themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>`;
persisted in prefs key `tizbiz_theme` (`'light'|'dark'|'system'`, default system), same key as
the web cabinet. Methods: `set(ThemeMode m)`.

---

## 4. Theme (mirrors `apps/admin/src/style.css`)

### 4.1 Tokens (`lib/app/theme/app_colors.dart`)

| Token | Light | Dark |
|---|---|---|
| bg (scaffold) | `#F5F6F8` | `#0F1115` |
| surface (cards, sheets, app bar) | `#FFFFFF` | `#181B21` |
| surface2 (inputs fill, off-hours band) | `#F0F2F5` | `#21252D` |
| border | `#E2E5EA` | `#2B303A` |
| text | `#1A1D23` | `#E8EAED` |
| textMuted | `#6B7280` | `#9AA1AC` |
| primary (default, no business) | `#2563EB` | `#3B82F6` |
| primarySoft | primary 14% over surface | primary 14% over surface (web: `color-mix(accent 14%, transparent)`) |
| danger / dangerSoft | `#DC2626` / `#FDECEC` | `#EF4444` / `#2A1618` |
| success | `#16A34A` | `#22C55E` |
| warning | `#D97706` | `#F59E0B` |

`AppColors extends ThemeExtension<AppColors>` carries all tokens above plus status colours, and
`AppColors.of(context)` reads it.

Appointment status badge colours (`apps/admin/src/style.css` `.badge.*`), bg / fg:

| Status | Light | Dark |
|---|---|---|
| pending | `#FEF3C7` / `#92400E` | `#3A2E12` / `#FBBF24` |
| confirmed | `#DBEAFE` / `#1E40AF` | `#14284A` / `#93C5FD` |
| arrived | `#E0E7FF` / `#3730A3` | `#1E1B4B` / `#A5B4FC` |
| completed | `#DCFCE7` / `#166534` | `#14331F` / `#86EFAC` |
| no_show | `#FEE2E2` / `#991B1B` | `#3A1616` / `#FCA5A5` |
| canceled | `#F3F4F6` / `#6B7280` | `#262A31` / `#9AA1AC` |

Order status colours (`Orders.vue` columns), used as dot/left border, badge bg = colour 15%:
new `#3B82F6`, confirmed `#8B5CF6`, preparing `#F59E0B`, ready `#10B981`, delivered `#6B7280`,
cancelled `#EF4444`.

### 4.2 Verticals (`lib/app/theme/vertical.dart`, from `apps/admin/src/lib/verticals.js`)

```dart
enum Vertical {
  barber('barber', 'Barber', Color(0xFF3B82F6), Icons.content_cut),
  cafe('cafe', 'Kafe / Tort', Color(0xFFF97316), Icons.restaurant),
  clinic('clinic', 'Klinika', Color(0xFF10B981), Icons.medical_services_outlined),
  rental('rental', 'Ijara', Color(0xFF8B5CF6), Icons.celebration_outlined);
  /// category -> key; aliases salon->barber, dentistry|diagnostics->clinic, restaurant->cafe;
  /// else by engine (slot->barber, catalog->cafe, medical->clinic, rental->rental); else barber.
  static Vertical of({String? category, Engine? engine});
}
```

The active business's `vertical.accent` replaces `primary` in both themes (as the web shell does).

### 4.3 `AppTheme`

`static ThemeData light(Color? accent)` / `dark(Color? accent)`: `useMaterial3: true`, explicit
`ColorScheme` (primary = accent ?? default primary, onPrimary white, surface, error = danger,
outline = border), `scaffoldBackgroundColor` = bg, cards radius 10 with 1 px border and no
elevation, inputs radius 8 filled with surface2, `NavigationBarTheme` with indicator primarySoft,
`AppBarTheme` surface background without scroll tint, base font size 14 and headings
`FontWeight.w600`, `extensions: [AppColors.light/dark]`. Charts (fl_chart) always get explicit
colours and text styles from `AppColors` (fl_chart does not read the material_ui theme).

---

## 5. Session, API and the 401 hook (skeleton agent)

### 5.1 Infrastructure providers

```dart
// lib/core/prefs.dart
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

// lib/core/secure_token_store.dart
final class SecureTokenStore implements TokenStore {        // CS §4.1, key 'tizbiz_biz_token'
  SecureTokenStore(this._storage, [this._key = 'tizbiz_biz_token']);
}

// lib/core/api_providers.dart
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore(const FlutterSecureStorage()));
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    config: ApiConfig.fromEnvironment(log: kDebugMode ? debugPrint : null),
    tokenKind: TokenKind.biz,
    tokenStore: ref.watch(tokenStoreProvider),
    onUnauthorized: (e) => ref.read(sessionProvider.notifier).onUnauthorized(e),   // read lazily: no build cycle
  );
  ref.onDispose(client.close);
  return client;
});
```

### 5.2 `SessionState`

```dart
sealed class SessionState { const SessionState(); }

final class SessionBooting extends SessionState { const SessionBooting(); }

final class SessionSignedOut extends SessionState {
  const SessionSignedOut({this.message});
  final String? message;       // shown as a banner on the login screen ('Sessiya tugadi. Qaytadan kiring.')
}

final class SessionSignedIn extends SessionState {
  const SessionSignedIn({required this.session, required this.epoch, this.needsPicker = false, this.fromCache = false});
  final AuthSession session;   // CS §10.10: token, user, businesses, active
  final int epoch;             // +1 on every login and switch; the router is rebuilt per epoch (§6.4)
  final bool needsPicker;      // true right after a login with businesses.length > 1
  final bool fromCache;        // booted offline from the cached /auth/me
}
```

### 5.3 `SessionNotifier` (`sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new)`)

| Method | Behaviour |
|---|---|
| `build()` | returns `SessionBooting()` and schedules `_boot()` with `Future.microtask`. |
| `_boot()` | `token = await api.currentToken()` (null when absent, wrong kind or expired). null → `SignedOut()`. Else `GET Endpoints.authMe` → `AuthMe.fromJson` → `SignedIn(session: AuthSession(token, expiresAt: claims.expiresAt, user, businesses, active), epoch: 1)`; writes the cache. On `ApiException.isNetwork` with a cache whose `user.id == claims.sub` and `active.businessId == claims.tenantId` → `SignedIn(fromCache: true)`. 401 → (hook already fired) `SignedOut(message: 'Sessiya tugadi. Qaytadan kiring.')`. Other errors → `SignedOut(message: e.message)`. |
| `login(String phone, String password)` | `POST Endpoints.login` body `{"phone": Phone.normalize(phone), "password": password}` with `RequestAuth.none`, decode `AuthSession.fromJson`. `api.setToken(token)`, cache `AuthMe(user, active, businesses)`, state `SignedIn(epoch: prev+1, needsPicker: businesses.length > 1)`. Rethrows `ApiException` for the form (401 detail `Telefon yoki parol noto'g'ri.`). |
| `switchBusiness(int businessId)` | `POST Endpoints.switchBusiness(id)` → `SwitchResult` → `api.setToken(result.token)` → `GET authMe` → state `SignedIn(session: session.withSwitch(result).withMe(me), epoch: +1, needsPicker: false)`. Rethrows (403 `Siz bu biznesning a'zosi emassiz.` / `Bu biznes faol emas.`). |
| `completePicker()` | `needsPicker = false` (chosen business is already active). |
| `refreshMe()` | `GET authMe`; replaces user/businesses/active (`withMe`), keeps epoch, `fromCache = false`. Errors other than 401 are swallowed (logged). |
| `onForbidden()` | throttled `refreshMe()` (at most once per 30 s). Called by `ErrorView` on 403 and by the staff screens on 404 "not linked", so a demoted/unlinked member is moved to the right shell. |
| `onUnauthorized(ApiException e)` | if not already signed out: cancel the expiry timer, `api.clearToken()`, remove cache, state `SignedOut(message: 'Sessiya tugadi. Qaytadan kiring.')`. |
| `logout()` | `api.clearToken()`, remove cache, `SignedOut()`. There is no server logout endpoint. |

Extra rules:
- **Expiry timer**: on every `SignedIn` with `expiresAt`, schedule `Timer(expiresAt - now, () => onUnauthorized(...))`.
  Needed because `ApiClient` silently drops an expired token and the following 401 carries no
  `Authorization` header, so the hook would not fire (CS §3.3 rule 5).
- **Cache**: prefs key `tizbiz_last_me` = `jsonEncode(AuthMe.toJson())`.
- Token storage key `tizbiz_biz_token` (flutter_secure_storage; on web it is WebCrypto + localStorage).

### 5.4 `ActiveBusiness` (`lib/core/session/active_business.dart`)

```dart
@immutable
final class ActiveBusiness {
  final int businessId;          // active.business_id
  final String name, slug;       // from the BusinessMembership with that id
  final String? category, logo;
  final Engine engine;
  final BizRole role;            // active.role
  final int? staffId;            // active.staff_id
  final List<String> permissions;// active.permissions (fallback Permissions.forRole)
  final String timezone;         // Dates.defaultTimezone: no endpoint exposes the zone to managers; all businesses are Asia/Tashkent
  final Vertical vertical;
  bool get isManager => role.isManager;
  bool get isStaff => role == BizRole.staff;
  bool get isOwner => role == BizRole.owner;
  bool get hasStaffProfile => staffId != null;
  bool can(String permission) => permissions.contains(permission);
  bool get hasOrders => engine.isCatalogStorefront;      // catalog, medical
  bool get hasAppointments => engine.hasTimetable;        // slot, medical, rental
  String get appointmentsTerm => engine.appointmentsTerm; // Navbatlar | Qabullar | Ijaralar
}

final activeBusinessProvider = Provider<ActiveBusiness?>(...);   // null unless SignedIn with active.businessId set
/// Tenant key: every tenant data provider watches it first, so a switch refetches everything.
final tenantKeyProvider = Provider<int?>((ref) => ref.watch(activeBusinessProvider.select((a) => a?.businessId)));
/// For data providers: watches tenantKeyProvider + activeBusinessProvider; throws StateError when null.
ActiveBusiness requireActive(Ref ref);
```

### 5.5 How the 401 hook logs out (end to end)

1. A request with a stored token gets 401 (expired, removed member, demoted business, or a
   consumer token). `ApiClient` clears the store and calls `onUnauthorized` once per token value.
2. `apiClientProvider`'s callback calls `SessionNotifier.onUnauthorized`, which sets
   `SignedOut(message: 'Sessiya tugadi. Qaytadan kiring.')`.
3. `routerProvider` rebuilds for the signed-out epoch and the redirect sends every location to
   `/login`, which shows the message in a yellow banner.
4. Fallbacks for 401s the hook cannot see: the expiry timer (§5.3), and `ErrorView` calling
   `onUnauthorized` after the frame when it receives an `ApiException.isUnauthorized`.
5. Login 401 uses `RequestAuth.none`, so it never logs anybody out; the form shows the detail.

---

## 6. Routing

### 6.1 Route constants (`lib/app/routes.dart`, skeleton)

```dart
abstract final class Routes {
  static const splash = '/splash', login = '/login', pickBusiness = '/pick-business', noBusiness = '/no-business';
  // manager shell
  static const dashboard = '/o/dashboard', timetable = '/o/timetable', appointments = '/o/appointments',
      orders = '/o/orders', clients = '/o/clients', more = '/o/more',
      services = '/o/more/services', serviceNew = '/o/more/services/new', serviceCategories = '/o/more/service-categories',
      staff = '/o/more/staff', staffNew = '/o/more/staff/new',
      finance = '/o/more/finance', payroll = '/o/more/payroll', reviews = '/o/more/reviews',
      settings = '/o/more/settings', team = '/o/more/team';
  static String service(int id) => '/o/more/services/$id';
  static String staffDetail(int id, {int tab = 0}) => '/o/more/staff/$id?tab=$tab';  // 0 Ma'lumot, 1 Ish vaqti, 2 Dam olish
  static String appointmentsFor({int? staffId}) => staffId == null ? appointments : '$appointments?staff=$staffId';
  // manager detail routes (root navigator, no bottom bar)
  static String appointment(int id) => '/appointment/$id';
  static String appointmentNew({int? staffId, LocalDate? date, HmTime? time, int? clientId}); // '/appointment/new?staff=2&date=2026-10-17&time=10:30&client=881'
  static String client(int id) => '/client/$id';
  static const clientNew = '/client/new';
  static String clientEdit(int id) => '/client/$id/edit';
  // staff shell
  static const myDay = '/s/today', myStats = '/s/stats', mySchedule = '/s/schedule', myOrders = '/s/orders', profile = '/s/profile';
  static String myAppointment(int id) => '/s/appointment/$id';
  /// Home for a session (see §6.3).
  static String homeFor(ActiveBusiness a);
}
```

Features navigate only through these (`context.go(Routes.clients)`, `context.push(Routes.appointment(id))`).

### 6.2 Route table (every route; the skeleton registers all of them)

Auth column: `out` = signed out only, `in` = signed in (any role), `M` = manager role, `St` = staff role.
Perm = `ActiveBusiness.can(...)` required (CS §4.3 names); Engine = extra engine guard.

| # | Path | Name | Screen class | File | Feature | Auth | Perm / Engine | Params |
|---|---|---|---|---|---|---|---|---|
| 1 | `/splash` | `splash` | `SplashScreen` | `lib/app/splash_screen.dart` | skeleton | booting | | |
| 2 | `/login` | `login` | `LoginScreen` | `lib/features/auth/login_screen.dart` | auth | out | | |
| 3 | `/pick-business` | `pick-business` | `BusinessPickerScreen` | `lib/features/auth/business_picker_screen.dart` | auth | in | | |
| 4 | `/no-business` | `no-business` | `NoBusinessScreen` | `lib/features/auth/no_business_screen.dart` | auth | in | | |
| 5 | `/o/dashboard` | `dashboard` | `DashboardScreen` | `lib/features/dashboard/dashboard_screen.dart` | dashboard | M | `analytics` | |
| 6 | `/o/timetable` | `timetable` | `TimetableScreen` | `lib/features/timetable/timetable_screen.dart` | timetable | M | `appointments.all`; engine hasTimetable | |
| 7 | `/o/appointments` | `appointments` | `AppointmentsScreen` | `lib/features/appointments/appointments_screen.dart` | appointments | M | `appointments.all`; hasTimetable | query `staff` → `initialStaffId: int?` |
| 8 | `/o/orders` | `orders` | `OrdersBoardScreen` | `lib/features/orders/orders_board_screen.dart` | orders | M | `orders`; isCatalogStorefront | |
| 9 | `/o/clients` | `clients` | `ClientsScreen` | `lib/features/clients/clients_screen.dart` | clients | M | `clients` | |
| 10 | `/o/more` | `more` | `MoreMenuScreen` | `lib/app/more/more_menu_screen.dart` | skeleton | M | | |
| 11 | `/o/more/services` | `services` | `ServicesScreen` | `lib/features/catalog/services_screen.dart` | catalog | M | `catalog.manage` | |
| 12 | `/o/more/services/new` | `service-new` | `ServiceFormScreen` | `lib/features/catalog/service_form_screen.dart` | catalog | M | `catalog.manage` | `serviceId: null` |
| 13 | `/o/more/services/:id` | `service` | `ServiceFormScreen` | (same file) | catalog | M | `catalog.manage` | path `id` → `serviceId: int` |
| 14 | `/o/more/service-categories` | `service-categories` | `ServiceCategoriesScreen` | `lib/features/catalog/service_categories_screen.dart` | catalog | M | `catalog.manage` | |
| 15 | `/o/more/staff` | `staff` | `StaffListScreen` | `lib/features/staff_admin/staff_list_screen.dart` | staff_admin | M | `catalog.manage` | |
| 16 | `/o/more/staff/new` | `staff-new` | `StaffFormScreen` | `lib/features/staff_admin/staff_form_screen.dart` | staff_admin | M | `catalog.manage` | |
| 17 | `/o/more/staff/:id` | `staff-detail` | `StaffDetailScreen` | `lib/features/staff_admin/staff_detail_screen.dart` | staff_admin | M | `catalog.manage` | path `id` → `staffId: int`; query `tab` → `initialTab: int` (0..2, default 0) |
| 18 | `/o/more/finance` | `finance` | `FinanceScreen` | `lib/features/money/finance_screen.dart` | money | M | `finance` | |
| 19 | `/o/more/payroll` | `payroll` | `PayrollScreen` | `lib/features/money/payroll_screen.dart` | money | M | `payroll`; engine != catalog | |
| 20 | `/o/more/reviews` | `reviews` | `ReviewsScreen` | `lib/features/reviews/reviews_screen.dart` | reviews | M | `reviews` | |
| 21 | `/o/more/settings` | `settings` | `BookingSettingsScreen` | `lib/features/settings/booking_settings_screen.dart` | settings | M | `settings.manage` | |
| 22 | `/o/more/team` | `team` | `TeamScreen` | `lib/features/team/team_screen.dart` | team | M | `team.read` | |
| 23 | `/appointment/new` | `appointment-new` | `AppointmentCreateScreen` | `lib/features/appointments/appointment_create_screen.dart` | appointments | M | `appointments.manage`; hasTimetable | query `staff`, `date` (YYYY-MM-DD), `time` (HH:MM), `client` → `initialStaffId: int?`, `initialDate: LocalDate?`, `initialTime: HmTime?`, `initialClientId: int?` |
| 24 | `/appointment/:id` | `appointment` | `AppointmentDetailScreen` | `lib/features/appointments/appointment_detail_screen.dart` | appointments | M | `appointments.all` | `appointmentId: int` |
| 25 | `/client/new` | `client-new` | `ClientFormScreen` | `lib/features/clients/client_form_screen.dart` | clients | M | `clients` | `clientId: null` |
| 26 | `/client/:id` | `client` | `ClientDetailScreen` | `lib/features/clients/client_detail_screen.dart` | clients | M | `clients` | `clientId: int` |
| 27 | `/client/:id/edit` | `client-edit` | `ClientFormScreen` | (same as 25) | clients | M | `clients` | `clientId: int` |
| 28 | `/s/today` | `my-day` | `MyDayScreen` | `lib/features/me_day/my_day_screen.dart` | me_day | St | engine hasTimetable | |
| 29 | `/s/stats` | `my-stats` | `MyStatsScreen` | `lib/features/me/my_stats_screen.dart` | me | St | engine hasTimetable | |
| 30 | `/s/schedule` | `my-schedule` | `MyScheduleScreen` | `lib/features/me/my_schedule_screen.dart` | me | St | | |
| 31 | `/s/orders` | `my-orders` | `OrdersBoardScreen` | `lib/features/orders/orders_board_screen.dart` | orders | St | `orders`; isCatalogStorefront | |
| 32 | `/s/profile` | `profile` | `ProfileScreen` | `lib/features/me/profile_screen.dart` | me | St | | |
| 33 | `/s/appointment/:id` | `my-appointment` | `MyAppointmentDetailScreen` | `lib/features/me_day/my_appointment_detail_screen.dart` | me_day | St | | `appointmentId: int` |

Path params that do not parse as int, or a query `date`/`time` that does not parse, render
`NotFoundScreen` (`errorBuilder`). **Registration order:** every literal `new` route is registered
*before* its `:id` sibling (12 before 13, 16 before 17, 23 before 24, 25 before 26), because
go_router matches in list order and `new` would otherwise hit the int parser and show
`NotFoundScreen`. `routes_smoke_test.dart` opens each `.../new` path to prove it. Routes 23-27 and 33 use `parentNavigatorKey: rootNavigatorKey`
(full screen, no bottom bar).

Exact constructors (placeholders and final screens must keep them):

```dart
const SplashScreen({super.key});
const LoginScreen({super.key});
const BusinessPickerScreen({super.key});
const NoBusinessScreen({super.key});
const DashboardScreen({super.key});
const TimetableScreen({super.key});
const AppointmentsScreen({super.key, this.initialStaffId});                        // int?
const OrdersBoardScreen({super.key});
const ClientsScreen({super.key});
const MoreMenuScreen({super.key});
const ServicesScreen({super.key});
const ServiceFormScreen({super.key, this.serviceId});                              // int? (null = new)
const ServiceCategoriesScreen({super.key});
const StaffListScreen({super.key});
const StaffFormScreen({super.key});                                                // create only; edit lives in StaffDetailScreen tab 0
const StaffDetailScreen({super.key, required this.staffId, this.initialTab = 0});
const FinanceScreen({super.key});
const PayrollScreen({super.key});
const ReviewsScreen({super.key});
const BookingSettingsScreen({super.key});
const TeamScreen({super.key});
const AppointmentCreateScreen({super.key, this.initialStaffId, this.initialDate, this.initialTime, this.initialClientId});
const AppointmentDetailScreen({super.key, required this.appointmentId});
const ClientFormScreen({super.key, this.clientId});                                // int? (null = new)
const ClientDetailScreen({super.key, required this.clientId});
const MyDayScreen({super.key});
const MyStatsScreen({super.key});
const MyScheduleScreen({super.key});
const ProfileScreen({super.key});
const MyAppointmentDetailScreen({super.key, required this.appointmentId});
const NotFoundScreen({super.key});
```

### 6.3 Redirect rules (`lib/app/redirect.dart`, pure and unit-tested)

```dart
/// Returns the location to go to, or null to stay.
String? computeRedirect({required SessionState session, required ActiveBusiness? active, required Uri location});
```

Evaluated in this order:

1. `SessionBooting` → `/splash` (unless already there).
2. `SessionSignedOut` → `/login` for every location except `/login`.
3. `SignedIn` and `session.businesses` empty → `/no-business` (only that route allowed).
4. `SignedIn` and `active == null` (no `active.business_id`) or `needsPicker` → `/pick-business`.
   `/pick-business` stays reachable afterwards (the business switcher).
5. `active.role == BizRole.unknown` → `/no-business`.
6. `/`, `/splash`, `/login` → `Routes.homeFor(active)`.
7. Manager (`owner`/`admin`) on a `/s/...` path → home. Staff on a `/o/...`, `/appointment/...` or
   `/client/...` path → home. **Staff never reach a manager screen.**
8. Permission and engine guards from the route table fail → home.

`Routes.homeFor(a)`:
- manager: `/o/orders` when `engine == catalog`, else `/o/dashboard`;
- staff: `/s/orders` when `a.hasOrders && (!a.hasStaffProfile || !a.hasAppointments)` (catalog
  staff such as the seeded aziza-tortlari cook have a linked profile but no appointments), else
  `/s/today`.

### 6.4 Router provider (`lib/app/router.dart`)

```dart
final rootNavigatorKey = GlobalKey<NavigatorState>();
final routerProvider = Provider<GoRouter>((ref) {
  // Rebuilt when the epoch changes (login, switch, logout): resets every branch stack of both shells.
  ref.watch(sessionProvider.select((s) => s is SessionSignedIn ? s.epoch : (s is SessionBooting ? -2 : -1)));
  final refresh = _SessionListenable(ref);          // ChangeNotifier: notifies on any session/active change (role, needsPicker)
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => computeRedirect(session: ref.read(sessionProvider), active: ref.read(activeBusinessProvider), location: state.uri),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [/* table §6.2: flat routes 1-4, StatefulShellRoute.indexedStack (manager), StatefulShellRoute.indexedStack (staff), root routes 23-27, 33 */],
  );
  ref.onDispose(() { router.dispose(); refresh.dispose(); });
  return router;
});
```

Manager shell `StatefulShellRoute.indexedStack(builder: (c, s, shell) => ManagerShell(shell: shell))`,
branches in this fixed order: 0 dashboard, 1 timetable, 2 appointments, 3 orders, 4 clients,
5 more (with routes 11-22 as children of `/o/more`). Staff shell branches: 0 today, 1 stats,
2 schedule, 3 orders, 4 profile.

### 6.5 Bottom navigation

`lib/app/shells/nav_items.dart`:

```dart
final class NavItem { final int branch; final String label; final IconData icon; final IconData selectedIcon; }
List<NavItem> managerNavItems(ActiveBusiness a);
List<NavItem> staffNavItems(ActiveBusiness a);
```

Manager bar per engine (branch index in brackets):

| Engine | Items |
|---|---|
| slot, rental | Bosh sahifa [0], Jadval [1], `a.appointmentsTerm` [2] (Navbatlar / Ijaralar), Mijozlar [4], Ko'proq [5] |
| medical | Bosh sahifa [0], Jadval [1], Qabullar [2], Buyurtmalar [3], Ko'proq [5] (Mijozlar is in the Ko'proq menu) |
| catalog | Bosh sahifa [0], Buyurtmalar [3], Mijozlar [4], Ko'proq [5] |

Staff bar: Mening kunim [0] and Statistikam [1] (only when `a.hasAppointments`; catalog has
none), Jadvalim [2], Buyurtmalar [3] (only when `a.hasOrders`), Profil [4]. So catalog staff see
Jadvalim, Buyurtmalar, Profil; medical staff see all five.

Icons: dashboard `space_dashboard_outlined`, Jadval `calendar_view_day_outlined`, appointments
`event_note_outlined`, Buyurtmalar `receipt_long_outlined`, Mijozlar `people_outline`, Ko'proq
`menu`, Mening kunim `today_outlined`, Statistikam `insights_outlined`, Jadvalim
`schedule_outlined`, Profil `person_outline`.

`ManagerShell` / `StaffShell`: `Scaffold(body: Column([if fromCache OfflineBanner(), Expanded(shell)]), bottomNavigationBar: NavigationBar(...))`.
When the current branch is not in the bar (e.g. Mijozlar on medical), highlight Ko'proq. Tapping
the current item calls `shell.goBranch(i, initialLocation: true)` (pop to branch root).

### 6.6 "Ko'proq" menu (`MoreMenuScreen`, skeleton)

Header card: `BusinessAvatar`, business name, vertical label, role label (`BizRole.label`),
button **Biznesni almashtirish** (only when `businesses.length > 1`) → `context.push(Routes.pickBusiness)`.

Menu rows, each shown only when its route guard passes:

| Row | Route | Shown when |
|---|---|---|
| Mening navbatlarim | `Routes.appointmentsFor(staffId: a.staffId)` | `a.hasStaffProfile && a.hasAppointments` |
| Mijozlar | `Routes.clients` | engine == medical |
| `engine.servicesTerm` (Xizmatlar / Menyu / Buyumlar) | `Routes.services` | `catalog.manage` |
| `engine.staffTerm` (Ustalar / Xodimlar / Shifokorlar) | `Routes.staff` | `catalog.manage` |
| Moliya | `Routes.finance` | `finance` |
| Ish haqi | `Routes.payroll` | `payroll` and engine != catalog |
| Sharhlar | `Routes.reviews` | `reviews` |
| Onlayn-yozuv sozlamalari | `Routes.settings` | `settings.manage` |
| Jamoa | `Routes.team` | `team.read` |
| Mavzu (Tizim / Yorug' / Qorong'i) | segmented control → `themeModeProvider` | always |
| Chiqish | confirm "Hisobdan chiqasizmi?" → `session.logout()` | always |

Footer: user name + phone (`Phone.format`), `Env.appVersion`, and in debug the API base URL.

---

## 7. Data conventions (all features)

### 7.1 Provider template

```dart
final dayAppointmentsProvider = FutureProvider.autoDispose.family<List<Appointment>, LocalDate>((ref, day) async {
  final a = requireActive(ref);                 // watches the tenant: refetch on switch
  ref.watch(appointmentsRevisionProvider);      // refetch after any appointment mutation anywhere
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).getList(Endpoints.appointments, Appointment.fromJson,
      query: ApiQuery.appointments(from: day, to: day, timezone: a.timezone), cancelToken: cancel);
});
```

- Riverpod 3 APIs only: `Provider`, `FutureProvider`, `NotifierProvider`, `AsyncNotifierProvider`,
  `.autoDispose`, `.family`. No `StateProvider`/`StateNotifierProvider` (legacy import). Family
  notifiers take their argument through the constructor (`AsyncNotifierProvider.autoDispose.family<N, T, A>(N.new)`).
- Family arguments are records or core value types (`LocalDate`, `int`): they have value equality.
- Mutations live in a plain `Provider<XActions>` per feature (class with methods that call the API,
  bump revisions and return the saved model). Screens `await` them and show errors themselves.
- After an `await`, a notifier checks `ref.mounted` before touching `state`.

### 7.2 Revisions (`lib/shared/data/revisions.dart`, skeleton)

```dart
final class Revision extends Notifier<int> { @override int build() => 0; void bump() => state++; }
final appointmentsRevisionProvider = NotifierProvider<Revision, int>(Revision.new);
final ordersRevisionProvider = NotifierProvider<Revision, int>(Revision.new);
final clientsRevisionProvider = NotifierProvider<Revision, int>(Revision.new);
final servicesRevisionProvider = NotifierProvider<Revision, int>(Revision.new);   // services + service categories
final staffRevisionProvider = NotifierProvider<Revision, int>(Revision.new);      // staff rows, commission, team links
final scheduleRevisionProvider = NotifierProvider<Revision, int>(Revision.new);   // working hours + time-off
void bump(Ref ref, NotifierProvider<Revision, int> p) => ref.read(p.notifier).bump();
```

Who bumps what: appointment create/status → appointments (also clients, because CRM counters
change); order status → orders; client create/edit/delete/categories → clients; service or
category CRUD → services; staff CRUD, commission edit, team link change → staff; working
hours/time-off → schedule.

### 7.3 Shared data providers (skeleton)

`lib/shared/data/catalog_data.dart`:

| Provider | Type | Endpoint | Notes |
|---|---|---|---|
| `staffListProvider` | `FutureProvider.autoDispose<List<Staff>>` | `GET Endpoints.staff` | all rows incl. inactive (server orders by name); watches tenant + staffRevision |
| `activeStaffProvider` | `Provider.autoDispose<AsyncValue<List<Staff>>>` | derived | `isActive == true` only (pickers, timetable) |
| `servicesListProvider` | `FutureProvider.autoDispose<List<Service>>` | `GET Endpoints.services` | incl. inactive; watches servicesRevision |
| `serviceCategoriesProvider` | `FutureProvider.autoDispose<List<ServiceCategory>>` | `GET Endpoints.serviceCategories` | sorted by `sort`, `id`; watches servicesRevision |

`lib/shared/data/schedule_data.dart`:

| Provider | Type | Endpoint |
|---|---|---|
| `workingHoursProvider` | `FutureProvider.autoDispose.family<List<WorkingHours>, int>` (staffId) | `GET Endpoints.workingHours(staffId)` |
| `timeOffProvider` | `FutureProvider.autoDispose.family<List<TimeOff>, int>` (staffId) | `GET Endpoints.timeOff(staffId)` |

Both watch tenant + scheduleRevision.

### 7.4 Screen states (every list/detail screen)

Use `AsyncBody` (§8). Required states:

| State | Rendering |
|---|---|
| loading, no data | `LoadingView` (centered spinner, or `SkeletonList` for lists) |
| data | content; while refetching with old data, a 2 px `LinearProgressIndicator` under the app bar |
| empty | `EmptyView(icon, title, message, action?)` with the texts given per screen |
| error, no data | `ErrorView`: offline (`isNetwork`): icon `wifi_off`, "Internet aloqasi yo'q", button "Qayta urinish"; 403: "Bu bo'lim uchun ruxsatingiz yo'q." + `session.onForbidden()`; 404: "Topilmadi."; 401: triggers logout (§5.5); other: `e.message` + "Qayta urinish" |
| error with old data | keep the data, show `StaleBanner` "Ma'lumot yangilanmadi: `<e.message>`" with "Qayta urinish" |

Every list supports pull-to-refresh (`RefreshIndicator` → `ref.refresh(provider.future)`).

### 7.5 Polling (`lib/shared/polling.dart`, skeleton)

```dart
const kPollInterval = Duration(seconds: 60);
final pollingEnabledProvider = Provider<bool>((ref) => true);   // tests override to false
/// Calls [onTick] every [interval] while: app lifecycle is resumed, TickerMode is enabled (the shell
/// branch is visible) and the enclosing route is current. Also calls it once on resume after > interval.
class PollWhileVisible extends ConsumerStatefulWidget {
  const PollWhileVisible({super.key, this.interval = kPollInterval, required this.onTick, required this.child});
}
```

Screens that poll (the tick invalidates their list provider): Dashboard (today block only),
Timetable, Appointments, Orders board (both shells), My day. Detail screens do not poll.

### 7.6 Forms

- Validators run on submit (`AutovalidateMode.onUserInteraction` after the first submit).
- 422 errors: `ApiException.fieldErrors` keyed by pointer (`name`, `phone`, `items[2].end_time`)
  are shown as the matching field's `errorText`; unmatched errors and non-422 errors are shown in a
  `FormErrorBanner` above the submit button. The submit button shows a spinner and is disabled
  while saving. Leaving a dirty form asks "O'zgarishlar saqlanmaydi. Chiqasizmi?".
- Phones: `PhoneField` (+998 prefix, `Phone.formatPartial`), validated with `Phone.isValid`,
  sent as `Phone.normalize(...)`.
- Money: `SomField` (so'm input, `Money.parseSomInput` → tiyin, displays `Money.group`).
- Times: `showTimePicker` (24 h), shown with `HmTime.format()`; dates: `showDatePicker` with
  locale `uz`, shown with `UzDates.dayMonthYear`.

### 7.7 Idempotency

- Admin booking create: one `Idempotency.newKey()` per create screen; regenerated when staff,
  service, date, time/session or client changes; reused on retry after a network error. 200
  (`isReplay`) and 201 are both success.
- Deposit link: always `Idempotency.deposit(appointmentId)` (`dep-<id>-payme`), provider `payme` only.

---

## 8. Shared widgets and helpers (`lib/shared/`, skeleton)

| File | API | Notes |
|---|---|---|
| `widgets/async_body.dart` | `AsyncBody<T>({required AsyncValue<T> value, required Widget Function(T) data, bool Function(T)? isEmpty, Widget? empty, VoidCallback? onRetry})` | implements §7.4 |
| `widgets/error_view.dart` | `ErrorView({required Object error, VoidCallback? onRetry})` | 401 → `onUnauthorized` post-frame; 403 → `onForbidden` |
| `widgets/empty_view.dart` | `EmptyView({required IconData icon, required String title, String? message, Widget? action})` | |
| `widgets/loading_view.dart` | `LoadingView()`, `SkeletonList({int count = 6})` | |
| `widgets/stale_banner.dart` | `StaleBanner({required Object error, VoidCallback? onRetry})` | |
| `widgets/offline_banner.dart` | `OfflineBanner()` | "Oflayn rejim. Ma'lumotlar eskirgan bo'lishi mumkin." + "Qayta urinish" → `refreshMe()` |
| `widgets/form_error_banner.dart` | `FormErrorBanner({String? message})` | |
| `widgets/status_badge.dart` | `AppointmentStatusBadge(AppointmentStatus s)`, `OrderStatusBadge(OrderStatus s)` | labels from the core enums (`Kutilmoqda`, ...) |
| `widgets/money_text.dart` | `MoneyText(int? tiyin, {TextStyle? style, bool compact = false})` | `Money.format` / `Money.compact` |
| `widgets/phone_field.dart` | `PhoneField({required TextEditingController controller, String label = 'Telefon', String? errorText, bool required = true})` | |
| `widgets/phone_link.dart` | `PhoneLink(String? phone)` | `Phone.format`, tap → `launchUrl(Phone.telUri(...))` |
| `widgets/som_field.dart` | `SomField({required String label, int? initialTiyin, required ValueChanged<int?> onChanged, bool required = false, String? errorText})` | |
| `widgets/period_chips.dart` | `PeriodChips({required DateRangeValue value, required List<PeriodPreset> presets, required ValueChanged<DateRangeValue> onChanged, int maxDays = 366})` | presets `today`, `week` (Monday..today), `month` (1st..today), `last7`, `last30`, `last90`, `prevMonth`, `custom` (date range picker) |
| `widgets/day_switcher.dart` | `DaySwitcher({required LocalDate date, required LocalDate today, required ValueChanged<LocalDate> onChanged})` | `‹  Shanba, 17 oktabr  ›`, "Bugun" chip, calendar button |
| `widgets/confirm_dialog.dart` | `Future<bool> confirmAction(BuildContext c, {required String title, String? message, String confirmLabel = 'Tasdiqlash', bool destructive = false})` | |
| `widgets/app_snack.dart` | `void showAppSnack(BuildContext c, String message, {bool error = false})` | |
| `widgets/section_card.dart` | `SectionCard({String? title, Widget? trailing, required Widget child, EdgeInsets padding})` | |
| `widgets/kpi_card.dart` | `KpiCard({required String label, required String value, String? sub, IconData? icon, Color? tone})` | |
| `widgets/info_row.dart` | `InfoRow({required String label, required Widget value})` | |
| `widgets/paged_list_view.dart` | `PagedListView<T>({required Paged<T> page, required Widget Function(BuildContext, T) itemBuilder, required Future<void> Function() onLoadMore, required Future<void> Function() onRefresh, bool loadingMore = false})` | loads more 300 px before the end |
| `widgets/star_rating.dart` | `StarRating({required double value, double size = 16})` | amber `#F59E0B` |
| `widgets/business_avatar.dart` | `BusinessAvatar({String? logo, required String name, double size = 40, Color? accent})` | `CachedNetworkImage`, initials fallback |
| `widgets/staff_not_linked_view.dart` | `StaffNotLinkedView()` | title **Hisobingiz xodimga bog'lanmagan**, text "Biznes egasidan Jamoa bo'limida hisobingizni xodim profiliga bog'lashni so'rang.", button "Qayta tekshirish" → `refreshMe()` |
| `widgets/placeholder_screen.dart` | `PlaceholderScreen({required String title})` | Scaffold + AppBar(title) + "Tez orada" |
| `widgets/max_width.dart` | `MaxWidth({double max = 720, required Widget child})` | centres forms on web/tablet |
| `format.dart` | `BizTime bizTime(DateTime utc, ActiveBusiness a)`; `String sourceLabel(String? source)` (admin→Admin, link/site→Sayt, telegram/bot→Telegram, app→Bizcat); extension `AppointmentStatusAction on AppointmentStatus { String get actionLabel; }` (confirmed "Tasdiqlash", arrived "Keldi", completed "Yakunlash", noShow "Kelmadi", canceled "Bekor qilish"); extension `OrderStatusAction on OrderStatus { String get nextActionLabel; }` (new "Tasdiqlash", confirmed "Tayyorlashni boshlash", preparing "Tayyor", ready "Topshirildi"); `String rentalSessionLabel(Appointment a, ActiveBusiness b)` (local start 10 & end 23 → "Kun bo'yi", start < 17 → "Ertalab", else "Kechqurun") | |

---

## 9. Manager features

Each feature lists: files (all inside its folder), providers (name, type, endpoint, exact
request/response keys via the core model), and screens (content, states, actions, validation).

### 9.1 `auth` (login, business picker, no business)

Files: `login_screen.dart`, `business_picker_screen.dart`, `no_business_screen.dart`, `widgets/demo_login_chips.dart`.
Providers: none of its own; uses `sessionProvider`.

**LoginScreen**
- Logo (`assets/brand/tizbiz-logo.png`, height 48), title "Biznes kabinetiga kirish", subtitle "TizBiz Biznes".
- Banner when `SessionSignedOut.message != null` (warning colours).
- `PhoneField` (required, `Phone.isValid`, error "Telefon raqam noto'g'ri"), password field with show/hide toggle (required, error "Parolni kiriting").
- Button **Kirish** → `session.login(phone, password)`. Errors: 401 → "Telefon yoki parol noto'g'ri." under the form; network → `e.message`; other → `e.message`.
- Demo chips (only `Env.demoLogins || kDebugMode`): "Barber egasi" +998901111111, "Tort egasi" +998902222222, "Klinika egasi" +998903333333, "To'yxona egasi" +998904444444, "Usta (xodim)" +998931110001, "Restoran egasi" +998905555555, "Oshpaz (xodim)" +998932220001, "Shifokor (xodim)" +998933330001; tap fills the fields with password `secret123` and submits.
- Footer link "Biznesingizni ro'yxatdan o'tkazing" → `launchUrl(Uri.parse('https://tizbiz.uz/register'), mode: externalApplication)`.
- Navigation happens through the redirect (no `context.go` after login).

**BusinessPickerScreen**
- Title "Biznesni tanlang". List of `session.businesses` (`BusinessMembership`): `BusinessAvatar(logo, name, accent: Vertical.of(category, engine).accent)`, name, vertical label, role label; the active one gets a "Faol" chip.
- Tap: the active one → `completePicker()`; another → `switchBusiness(id)` with a blocking progress dialog; on 403 snack `e.message`; on success the router rebuilds (new epoch).
- App bar back button only when `needsPicker == false` (opened from the switcher). Action "Chiqish".

**NoBusinessScreen**
- Empty view: icon `storefront_outlined`, "Siz hech qaysi faol biznes a'zosi emassiz" (or "Rolingiz aniqlanmadi" when role unknown), text "Biznes egasi sizni Jamoa bo'limiga qo'shishi kerak."
- Buttons: "Qayta tekshirish" → `refreshMe()`; "Ro'yxatdan o'tish" → tizbiz.uz/register; "Chiqish" → `logout()`.

Tests: `login_screen_test.dart` (empty submit shows both errors; valid submit calls `FakeSessionNotifier.login('+998901111111', 'secret123')` from input `90 111 11 11`; a thrown 401 shows the detail), `business_picker_screen_test.dart` (lists 2 businesses, tapping the inactive one calls `switchBusiness(3)`), `no_business_screen_test.dart`.

### 9.2 `dashboard` (Bosh sahifa)

Files: `dashboard_screen.dart`, `providers.dart`, `widgets/today_card.dart`, `widgets/revenue_chart.dart`, `widgets/appointments_bar_chart.dart`, `widgets/top_services_card.dart`, `widgets/staff_load_card.dart`, `widgets/orders_summary_section.dart`.

Providers:

| Provider | Type | Endpoint / source |
|---|---|---|
| `dashboardRangeProvider` | `NotifierProvider.autoDispose<DashboardRange, DateRangeValue>` | default `last7` (today-6 .. today) |
| `analyticsProvider` | `FutureProvider.autoDispose.family<AnalyticsOverview, ({LocalDate from, LocalDate to})>` | `GET Endpoints.analyticsOverview` query `ApiQuery.utcDays(from: from, to: to)` → `revenue_tiyin`, `appointments{total,pending,confirmed,arrived,completed,no_show,canceled}`, `no_show_rate`, `clients{total,new}`, `series[{date,revenue_tiyin,appointments}]`, `top_services[{service_id,name,count,revenue_tiyin}]`, `staff_load[{staff_id,name,count,revenue_tiyin}]`; watches appointmentsRevision |
| `todayAppointmentsProvider` | `FutureProvider.autoDispose<List<Appointment>>` | `GET Endpoints.appointments` query `ApiQuery.appointments(from: today, to: today)` |
| `ordersSummaryProvider` (catalog/medical) | `FutureProvider.autoDispose.family<OrdersSummary, ({LocalDate from, LocalDate to})>` | `GET Endpoints.orders` query `ApiQuery.orders(from: from, to: to, timezone: a.timezone)`; `OrdersSummary` (feature-local class): count, `total_tiyin` sum excluding `cancelled`, counts per `OrderStatus`, per-local-day sums (bucket `createdAt` by `Dates.localDateOf`) |

Screen (pull-to-refresh refreshes all; `PollWhileVisible` invalidates only `todayAppointmentsProvider` / today's orders):
- App bar: business name, subtitle `UzDates.weekdayDayMonth(today)`.
- **Bugun** card (engines with appointments): counters "Jami", "Kutilayotgan" (pending+confirmed+arrived), "Yakunlangan", "Kelmadi"; the next 3 live appointments (time range, client, service, staff, badge); tap → `Routes.appointment(id)`; link "Barchasi" → `Routes.appointments`. Empty: "Bugun yozuvlar yo'q".
- **Davr** `PeriodChips` presets `last7` (default), `last30`, `last90`, `custom` (max 366). Small footnote: "Hisobot kunlari UTC bo'yicha hisoblanadi." (BP: analytics treats dates as UTC days).
- KPI grid (2 columns): Daromad (`Money.compact(revenue_tiyin)`), Yozuvlar (`appointments.total`), "Kelmadi" (`no_show_rate` with 1 decimal + "%"), "Yangi mijozlar" (`clients.new`, sub "jami `clients.total`").
- "Kunlik daromad": `LineChart` of `series.revenue_tiyin` (x = date, labels `UzDates.dayMonthShort`, y labels `Money.compact`); "Kunlik yozuvlar": `BarChart` of `series.appointments`. Tooltip: date + value.
- "Top xizmatlar": up to 10 rows with a horizontal bar proportional to revenue, `count` ta, revenue.
- "Xodimlar yuki": rows per `staff_load` (name, count, revenue).
- Rental footnote when engine == rental: "Ijara daromadi mehmonlar soniga ko'paytirilmagan (xizmat narxi bo'yicha)."
- Engine catalog: no Bugun/analytics sections; instead **Buyurtmalar** section from `ordersSummaryProvider`: KPIs "Buyurtmalar", "Summa", "Yangi", "Bekor qilingan", and a `BarChart` of daily sums; link "Buyurtmalar taxtasi" → `Routes.orders`. Engine medical shows both the appointment sections and a compact Buyurtmalar KPI row.
- States: per section `AsyncBody` (one failing section does not hide the others). Empty analytics (`appointments.total == 0`): "Bu davrda ma'lumot yo'q".

Tests: renders KPIs and chart widgets from fixture analytics; catalog engine shows the orders section and no analytics; network error shows the offline view.

### 9.3 `timetable` (Jadval: one day by staff)

Files: `timetable_screen.dart`, `providers.dart`, `layout.dart` (pure lane/geometry math), `widgets/day_grid.dart`, `widgets/appointment_block.dart`, `widgets/staff_header.dart`.

Providers:

| Provider | Type | Endpoint / source |
|---|---|---|
| `timetableDateProvider` | `NotifierProvider.autoDispose<TimetableDate, LocalDate>` | default today (business-local) |
| `timetableStaffFilterProvider` | `NotifierProvider.autoDispose<StaffFilter, int?>` | null = all active staff |
| `dayAppointmentsProvider` | `FutureProvider.autoDispose.family<List<Appointment>, LocalDate>` | `GET Endpoints.appointments` query `ApiQuery.appointments(from: d, to: d)` (all staff; grouped client-side by `staffId`); watches appointmentsRevision |
| shared | `activeStaffProvider`, `workingHoursProvider(staffId)`, `timeOffProvider(staffId)` | §7.3 |

`layout.dart` (unit-tested, no widgets):
```dart
const double kHourPx = 64;
/// Visible hour range: min(start of working hours of the visible staff on d.weekday, first appointment start),
/// max(end, last appointment end); default 08:00-21:00; clamped to 00:00-24:00; rounded to whole hours.
({int startMin, int endMin}) visibleRange({required LocalDate day, required List<WorkingHours> hours, required List<Appointment> appts, required String timezone});
/// Overlap lanes per staff column: greedy by start time; returns lane index and lane count per appointment id.
Map<int, ({int lane, int lanes})> computeLanes(List<Appointment> appts, String timezone);
/// Snap a tap y offset to a 30-minute slot.
HmTime snapToSlot(double dy, int startMin);
```

Screen:
- App bar "Jadval"; `DaySwitcher`; staff chips row "Hammasi" + one chip per active staff.
- Grid: sticky staff header row (name, specialization), left time gutter 48 px with hour labels,
  one column per visible staff (width `max(132, (w - 48) / n)`, horizontal scroll when wider).
  Vertical scroll auto-positions to "now" (today) or to the range start.
- Column background: surface inside the staff's working hours for that weekday (ISO weekday),
  surface2 outside; time-off rows for that date are a hatched overlay with the reason (full day
  when `isFullDay`).
- Appointment block: top/height from local start/end (min height 24), lane-split width, left 3 px
  border in the status fg colour on the status bg; text `09:00 Soch olish` and client name;
  rental shows the session label and "N mehmon". Canceled blocks at 50% opacity.
- Now line (danger colour) when the day is today.
- Tap a block → `context.push(Routes.appointment(id))`. Tap an empty cell (manager with
  `appointments.manage`) → `context.push(Routes.appointmentNew(staffId, date, time: snapToSlot(...)))`.
- FAB "+ Yangi yozuv" → `Routes.appointmentNew(date: selected, staffId: filter)`.
- `PollWhileVisible` → invalidate `dayAppointmentsProvider(selected)`.
- States: no active staff → `EmptyView` "Hali xodim qo'shilmagan", action "Xodim qo'shish" → `Routes.staffNew`; no appointments → grid still shown with a small hint "Bu kunda yozuvlar yo'q"; errors per §7.4 (working-hours errors fall back to the default range silently).

Tests: `layout_test.dart` (lanes for 3 overlapping appointments → lanes 0,1,0 with counts; visible range from working hours 09:00-20:00 and an 08:30 appointment → 08:00-20:00; snap); `timetable_screen_test.dart` (two staff columns render names and a block text; empty staff shows the empty view).

### 9.4 `appointments` (Navbatlar / Qabullar / Ijaralar list, detail, create)

Files: `appointments_screen.dart`, `appointment_detail_screen.dart`, `appointment_create_screen.dart`, `providers.dart`, `actions.dart`, `widgets/appointment_tile.dart`, `widgets/filters_sheet.dart`, `widgets/slot_picker.dart`, `widgets/rental_picker.dart`, `widgets/client_picker.dart`.

Providers:

| Provider | Type | Endpoint |
|---|---|---|
| `appointmentsFilterProvider` | `NotifierProvider.autoDispose<AppointmentsFilterNotifier, AppointmentsFilter>` | `AppointmentsFilter{LocalDate from (today), LocalDate to (today+7), int? staffId, AppointmentStatus? status, String text}`; `initialStaffId` seeds `staffId` |
| `appointmentsListProvider` | `FutureProvider.autoDispose.family<List<Appointment>, ({LocalDate from, LocalDate to, int? staffId, AppointmentStatus? status})>` | `GET Endpoints.appointments` query `ApiQuery.appointments(from: from, to: to, timezone: a.timezone, staffId: staffId, status: status)` → `Appointment` (business shape: `client_name`, `client_phone`, `service_name`, `service_duration`, `staff_name`, `items`); watches appointmentsRevision |
| `appointmentDetailProvider` | `FutureProvider.autoDispose.family<Appointment, int>` | `GET Endpoints.appointment(id)` |
| `availabilityProvider` | `FutureProvider.autoDispose.family<Availability, ({int staffId, int serviceId, LocalDate date})>` | `GET Endpoints.availability(staffId)` query `ApiQuery.availability(date: date, serviceId: serviceId)`, `RequestAuth.none` → `{date, timezone, slots[{start_utc,end_utc,start_local}]}` |
| `bookedDaysProvider` | `FutureProvider.autoDispose.family<BookedDays, String>` (slug) | `GET Endpoints.siteBookedDays(slug)` query `ApiQuery.localDays(from: today, to: today+120)`, `RequestAuth.none` → `{booked:{date:[sessions]}}` |
| `clientSearchProvider` | `FutureProvider.autoDispose.family<List<Client>, String>` | `GET Endpoints.clients` query `{search: q, per_page: 8}` via `getPage` (items); empty q → 6 most recent (`per_page: 6`) |
| `initialClientProvider` | `FutureProvider.autoDispose.family<Client, int>` | `GET Endpoints.client(id)` → `ClientDetail.fromJson(...).client` (preselect from `initialClientId`) |
| `appointmentActionsProvider` | `Provider<AppointmentActions>` | see below |

`AppointmentActions`:
- `Future<Appointment> setStatus(int id, AppointmentStatus next)` → `PATCH Endpoints.appointment(id)` body `{"status": next.wire}`; bumps appointments + clients.
- `Future<ApiResponse<Appointment>> create(AdminBookingRequest req, String idempotencyKey)` → `POST Endpoints.appointments` body `req.toJson()`, header via `idempotencyKey`; 201 new / 200 replay; bumps appointments + clients.
- `Future<DepositCheckout> depositLink(int appointmentId)` → `POST Endpoints.paymentsDeposit` body `{"appointment_id": id, "provider": "payme"}`, `idempotencyKey: Idempotency.deposit(id)`, `RequestAuth.none`.

**AppointmentsScreen** (title = `a.appointmentsTerm`)
- Filter bar: date range chip ("17 okt – 24 okt", tap → range picker, max 62 days), staff dropdown ("Barcha xodimlar"), status dropdown ("Barcha holatlar"), search field (client-side match on `clientName`, `clientPhone`, `serviceName`).
- List grouped by local day (`UzDates.dayLabel` headers with a count). Tile: `UzDates.timeRange(start, end)`, `AppointmentStatusBadge`, client name + `PhoneLink`, service · staff; trailing icons: deposit required (`requiresDeposit`, warning) / paid (`paid`, success); rental adds session label and guests.
- Tap → `Routes.appointment(id)`. FAB "+ Yangi" (only with `appointments.manage`) → `Routes.appointmentNew()`.
- `PollWhileVisible` invalidates the current query. Empty: icon `event_busy`, "Bu davrda yozuvlar yo'q", action "Yangi yozuv".

**AppointmentDetailScreen**
- Header: status badge, `UzDates.weekdayDayMonth(date)` and the time range; rental: session label + "N mehmon".
- Sections: Mijoz (name, `PhoneLink`, button "Mijoz kartasi" → `Routes.client(clientId)` when `clientId != null` and `clients` allowed), Xizmat (service name, `UzDates.duration(serviceDuration)`), Xodim (staff name), Manba (`sourceLabel`), Izoh (notes), Qo'shimchalar (`items`: name, qty × `Money.format(price)` = total), To'lov (deposit `Money.format(depositTiyin)`, "To'langan" / "To'lanmagan").
- Status actions: one button per `status.adminNext` with `actionLabel` (canceled and no_show are outlined danger and ask `confirmAction`). Calls `setStatus`; success → snack "Holat yangilandi", re-read; 409 → snack with the server detail (`Holatni 'X' dan 'Y' ga o'zgartirib bo'lmaydi.`) and refetch. Terminal statuses show "Bu yozuv yakunlangan" and no buttons.
- Deposit: when `requiresDeposit` and status is live, button "To'lov havolasi (Payme)" → `depositLink` → bottom sheet with "Ochish" (`launchUrl(checkoutUrl, externalApplication)`) and "Nusxalash" (`Clipboard.setData`, snack "Havola nusxalandi"). 409/422 → snack `e.message`. Click is never offered.
- No reschedule/edit (no server support): footnote "Vaqtni o'zgartirish uchun yozuvni bekor qilib, yangisini yarating."
- States: loading, 404 "Yozuv topilmadi", errors per §7.4.

**AppointmentCreateScreen** (title "Yangi yozuv"; `MaxWidth` form)
1. Xodim: dropdown of active staff (required, "Xodimni tanlang"); prefilled from `initialStaffId`.
2. Xizmat: dropdown of active services, grouped by category, showing duration and price (required). For rental the label is "Buyum / zal".
3. Slot engines (slot, medical): Sana (date picker, default `initialDate ?? today`), then Vaqt:
   free slots from `availabilityProvider` as chips grouped "Ertalab / Kunduzi / Kechqurun"
   (`AvailabilitySlot.bucket`); chip "Boshqa vaqt" opens a 24 h time picker (admin mode skips the
   slot check). `initialTime` preselects the manual time. Empty slots: "Bo'sh vaqt yo'q. Boshqa
   vaqtni qo'lda tanlang." Selecting a slot sends `startsAt = slot.startUtc`; a manual time sends
   `Dates.localToUtc(date, time, a.timezone)`. A past time asks `confirmAction` "Bu vaqt o'tib
   ketgan. Baribir saqlansinmi?".
4. Rental engine: Sana with the booked days from `bookedDaysProvider(a.slug)` (fully booked days
   disabled, partly booked days marked); Seans segmented: "Ertalab (10:00–16:00)" / "Kechqurun
   (18:00–23:00)" / "Kun bo'yi" (sends `session: null`); taken sessions disabled; Mehmonlar soni
   (optional int 1..5000). Server always stores rental bookings as pending, so the status picker is hidden.
5. Mijoz: segmented "Mavjud mijoz" / "Yangi mijoz". Existing: search field (debounce 300 ms,
   `clientSearchProvider`), result tiles (name, phone, visits); `initialClientId` preselects the
   client loaded by `initialClientProvider`.
   New: Ism (required, ≤128), `PhoneField` (required).
6. Boshlang'ich holat (slot engines): segmented Kutilmoqda (default) / Tasdiqlangan / Keldi.
7. Izoh (optional, ≤500).
- Submit "Saqlash" → `AdminBookingRequest(staffId, serviceId, startsAt | date+session, guests, clientId | clientName+clientPhone, notes, status)` → `create(req, key)`. Success (201 or replay 200) → snack "Yozuv yaratildi" and `context.pushReplacement(Routes.appointment(created.id))`.
- Errors: 409 (`Tanlangan vaqt band.` / `Bu vaqt allaqachon band qilingan.` / `Bu sana allaqachon band.`) shown under the time section, availability refetched; 422 → field errors (pointers `phone`, `name`, `staff_id`, `service_id`, `starts_at`); 403 → banner `e.message`; network → banner, retry keeps the key.

Tests: list renders grouped tiles and filters by text; detail shows exactly the buttons of `confirmed.adminNext` (Keldi, Yakunlash, Kelmadi, Bekor qilish) and none for completed; create validates required fields and sends the expected body to a fake actions provider (slot and new-client case).

### 9.5 `orders` (Buyurtmalar board; manager and staff shells)

Files: `orders_board_screen.dart`, `providers.dart`, `actions.dart`, `widgets/order_card.dart`, `widgets/order_detail_sheet.dart`, `widgets/status_picker_sheet.dart`.

Providers:

| Provider | Type | Endpoint |
|---|---|---|
| `ordersRangeProvider` | `NotifierProvider.autoDispose<OrdersRange, DateRangeValue>` | default `last7`; presets today, last7, last30, custom (max 62 days) |
| `ordersTabProvider` | `NotifierProvider.autoDispose<OrdersTab, OrderStatus>` | default `OrderStatus.newOrder` |
| `ordersListProvider` | `FutureProvider.autoDispose.family<List<Order>, ({LocalDate from, LocalDate to})>` | `GET Endpoints.orders` query `ApiQuery.orders(from: from, to: to, timezone: a.timezone)` → `Order` (`id,status,total_tiyin,customer_name,customer_phone,note,source,created_at,items[{id,service_id,name,price_tiyin,qty}],items_count`), newest first; watches ordersRevision |
| `orderOverridesProvider` | `NotifierProvider.autoDispose<OrderOverrides, Map<int, Order>>` | optimistic status changes merged over the list |
| `orderActionsProvider` | `Provider<OrderActions>` | `Future<Order> setStatus(int id, OrderStatus s)` → `PATCH Endpoints.order(id)` body `{"status": s.wire}` (`cancelled` with two l's); bumps orders |

There is no `GET /v1/orders/{id}`: the detail is a bottom sheet over the list item.

Screen ("Buyurtmalar"):
- `PeriodChips`; search field (client-side on `#id`, customer name, phone).
- Scrollable `TabBar` over `OrderStatus.board` (6 tabs) with count badges; under the tabs the
  tab's total `Money.format`.
- Card: `#id`, `customerName`, `UzDates.dateTime(createdAt)`, first 3 items "Napoleon torti ×2"
  and "+N ta", total, source chip (`sourceLabel`), and a primary button `status.nextActionLabel`
  when `status.next != null`; overflow menu "Holatni o'zgartirish".
- Tap → `OrderDetailSheet`: customer name, `PhoneLink`, created time, items table (name, qty ×
  price = line total), note, total, `OrderStatusBadge`, primary next-step button and a status
  picker with all 6 statuses (the server has no transition rules); "Bekor qilish" asks
  `confirmAction(destructive: true)`.
- Status change is optimistic: override map first, PATCH, on success replace with the response
  and bump; on error revert + snack `e.message`.
- `PollWhileVisible` invalidates the list (overrides of finished calls are dropped on refetch).
- Empty tab: "Bu bo'limda buyurtmalar yo'q"; empty range: "Bu davrda buyurtmalar yo'q".
- Same widget in both shells; staff use is allowed by the server (`orders` permission).

Tests: tabs show counts from fixtures; tapping "Tasdiqlash" on a `new` order calls `setStatus(id, confirmed)` and moves it to the Tasdiqlangan tab; error reverts.

### 9.6 `clients` (Mijozlar)

Files: `clients_screen.dart`, `client_detail_screen.dart`, `client_form_screen.dart`, `providers.dart`, `actions.dart`, `widgets/client_tile.dart`, `widgets/tags_input.dart`, `widgets/categories_editor.dart`.

Providers:

| Provider | Type | Endpoint |
|---|---|---|
| `clientsQueryProvider` | `NotifierProvider.autoDispose<ClientsQuery, ({String search, String segment})>` | segment `''`, `new`, `repeat`, `lost` |
| `clientsPagedProvider` | `AsyncNotifierProvider.autoDispose.family<ClientsPaged, Paged<Client>, ({String search, String segment})>` | `GET Endpoints.clients` query `{search, segment, ...ApiQuery.page(n, perPage: 20)}` via `getPage` → rows `id,name,phone,email,birthday,tags,created_at,visits,spent_tiyin,last_visit,categories[{id,name,color}]`, meta `page,per_page,total,pages`; methods `loadMore()`, `refresh()`; watches clientsRevision |
| `clientDetailProvider` | `FutureProvider.autoDispose.family<ClientDetail, int>` | `GET Endpoints.client(id)` → `{client, categories, history (last 20 appointments), loyalty?{points, cashback_tiyin}}` |
| `clientCategoriesProvider` | `FutureProvider.autoDispose<List<ClientCategory>>` | `GET Endpoints.clientCategories` → `{id,name,color,sort}` |
| `clientActionsProvider` | `Provider<ClientActions>` | `create(Map body)` → `POST Endpoints.clients` → `Client` (201); `update(int id, Map body)` → `PATCH Endpoints.client(id)` → `Client`; `delete(int id)` → `DELETE Endpoints.client(id)` (204); `setCategories(int id, List<int> ids)` → `PUT Endpoints.clientCategoriesOf(id)` body `{"category_ids": [...]}` → `List<ClientCategory>`. All bump clients. Bodies from `Client.toInput()` keys: `name, phone, email, birthday, notes, tags` |

**ClientsScreen**: search (debounce 300 ms), segment chips "Barchasi / Yangi / Takroriy / Yo'qolgan",
total count from `meta.total` ("124 ta mijoz"), `PagedListView` rows: name, `Phone.format`,
"N tashrif · `Money.compact(spentTiyin)`", last visit `UzDates.dayLabel`, category chips (colour
dots). Tap → `Routes.client(id)`. FAB → `Routes.clientNew`. Empty: "Mijozlar topilmadi" (with
search) / "Hali mijozlar yo'q".

**ClientDetailScreen**: header (name, `PhoneLink`, email, birthday `UzDates.dayMonthYear`, tags
chips, notes); Loyallik card (Ballar `points`, Keshbek `Money.format(cashbackTiyin)`, or "Loyallik
hisobi yo'q"); Kategoriyalar (`FilterChip` per client category, toggling saves the full set
immediately via `setCategories`, revert on error); "Tashriflar tarixi" (history tiles: date,
service, staff, status badge; tap → `Routes.appointment(id)`; empty "Tashriflar yo'q"). App bar
actions: edit → `Routes.clientEdit(id)`, delete (`confirmAction` destructive "Mijoz o'chirilsinmi?
Tarixi saqlanadi." → delete → pop). Button "Yangi yozuv" → `Routes.appointmentNew(clientId: id)`
(only `hasAppointments`).

**ClientFormScreen**: Ism (required, ≤128), Telefon (`PhoneField`, required), Email (optional,
basic email regex), Tug'ilgan kun (date picker, not in the future), Izoh (multiline), Teglar
(`TagsInput`, each ≤32 chars, max 10). Save → create/update; 422 pointer `phone` shows "Bu
telefon raqam ushbu biznesda allaqachon mavjud." on the field. Success → pop to detail.

Tests: list renders from a fake paged notifier and loads more; detail toggling a category calls `setCategories` with the full id list; form validation (empty name, bad phone, future birthday).

### 9.7 `catalog` (Xizmatlar / Menyu / Buyumlar + categories)

Files: `services_screen.dart`, `service_form_screen.dart`, `service_categories_screen.dart`, `actions.dart`, `widgets/service_tile.dart`, `widgets/category_dialog.dart`.

Providers: shared `servicesListProvider`, `serviceCategoriesProvider`;
`catalogActionsProvider = Provider<CatalogActions>`:
- `createService(Map body)` → `POST Endpoints.services` → `Service` (201)
- `updateService(int id, Map body)` → `PATCH Endpoints.service(id)` → `Service`
- `deactivateService(int id)` → `DELETE Endpoints.service(id)` → `{deleted:true}` (soft: `is_active=false`)
- `createCategory({required String name, int sort = 0})` → `POST Endpoints.serviceCategories` → `ServiceCategory`
- `updateCategory(int id, {String? name, int? sort})` → `PATCH Endpoints.serviceCategory(id)`
- `deleteCategory(int id)` → `DELETE Endpoints.serviceCategory(id)` (hard; services become uncategorised, FK SET NULL)
- all bump services. Service bodies use `Service.toInput()` keys: `name, category_id, duration_min, price_tiyin, deposit_tiyin, is_active, online_bookable, image, description, gallery` (image/gallery passed through unchanged).

**ServicesScreen** (title `engine.servicesTerm`): sections per category (sorted) + "Kategoriyasiz";
switch "Nofaollarni ko'rsatish" (default off). Tile: name, `UzDates.duration(durationMin)` (hidden
for catalog), `Money.format(priceTiyin)`, chips "Depozit `Money.compact`" and "Onlayn" /
"Faqat admin" (online_bookable false), inactive tiles muted with "Nofaol". Image thumbnail via
`CachedNetworkImage` when `image` set. Tap → `Routes.service(id)`. App bar action "Kategoriyalar"
→ `Routes.serviceCategories`. FAB → `Routes.serviceNew`. Empty: "Hali xizmatlar yo'q".

**ServiceFormScreen**: Nomi (required, ≤128); Kategoriya dropdown ("Kategoriyasiz" + list);
Davomiyligi, daqiqa (int 1..1440, default 30; hidden for catalog engine, which still sends the
current value); Narxi (`SomField`, required, ≥0); Oldindan to'lov (`SomField`, optional, ≥0; helper
"No-show'ni kamaytiradi"; warn if > price); Faol (switch, default on); Onlayn bron qilish mumkin
(switch, default on; hidden for catalog); Tavsif (multiline); image preview read-only with note
"Rasmni web kabinetda o'zgartiring" (no image picker in this iteration). Edit mode adds
"Faolsizlantirish" (`confirmAction`) → `deactivateService`. 422 field errors by pointer.

**ServiceCategoriesScreen**: list sorted by `sort` (name, sort badge, item count from the service
list); add/edit via `CategoryDialog` (Nomi required ≤96, Tartib int ≥0); delete confirm "Kategoriya
o'chirilsinmi? Undagi xizmatlar kategoriyasiz qoladi.".

Tests: grouped sections render; form computes `price_tiyin` 15000000 from input "150 000"; deactivate calls the action after confirm.

### 9.8 `staff_admin` (Ustalar / Xodimlar / Shifokorlar, working hours, time-off)

Files: `staff_list_screen.dart`, `staff_form_screen.dart`, `staff_detail_screen.dart`, `actions.dart`, `widgets/staff_info_tab.dart`, `widgets/working_hours_editor.dart`, `widgets/time_off_tab.dart`, `widgets/time_off_dialog.dart`, `hours_model.dart` (pure editor model + validation).

Providers: shared `staffListProvider`, `workingHoursProvider(staffId)`, `timeOffProvider(staffId)`;
`staffActionsProvider = Provider<StaffActions>`:
- `create(Map body)` → `POST Endpoints.staff` → `Staff` (201); body from `Staff.toInput()`: `name, specialization, is_active, commission_percent`
- `update(int id, Map body)` → `PATCH Endpoints.staffById(id)` → `Staff`
- `deactivate(int id)` → `DELETE Endpoints.staffById(id)` (soft: `is_active=false`)
- `saveWorkingHours(int staffId, WorkingHoursInput input)` → `PUT Endpoints.workingHours(staffId)` body **`{"items":[{"weekday":1..7,"start_time":"09:00:00","end_time":"18:00:00"}]}`** → `List<WorkingHours>`; replaces the whole week
- `addTimeOff(int staffId, TimeOffInput input)` → `POST Endpoints.timeOff(staffId)` body `{"date","start_time"?,"end_time"?,"reason"?}` → `TimeOff` (201)
- `deleteTimeOff(int staffId, int id)` → `DELETE Endpoints.timeOffItem(staffId, id)` → `{deleted:true}`
- staff writes bump staff; schedule writes bump schedule.

**StaffListScreen** (title `engine.staffTerm`): tiles (name, specialization, "Komissiya N%",
"Hisob bog'langan" chip when `userId != null`, inactive muted); switch "Nofaollarni ko'rsatish".
Tap → `Routes.staffDetail(id)`. FAB → `Routes.staffNew`. Empty: "Hali xodimlar yo'q".

**StaffFormScreen** (create): Ism (required ≤128), Mutaxassislik (≤96), Komissiya % (int 0..100,
default 0), Faol (default on). Success → `context.pushReplacement(Routes.staffDetail(id, tab: 1))`
so the owner sets working hours next.

**StaffDetailScreen**: `TabBar` "Ma'lumot / Ish vaqti / Dam olish" (`initialTab`).
- Ma'lumot: the same fields as the form (PATCH), login link status ("Tizimga kirish hisobi:
  bog'langan / bog'lanmagan. Jamoa bo'limida bog'lang." with a button → `Routes.team`), and
  "Faolsizlantirish" (confirm) → `deactivate`.
- Ish vaqti: 7 rows Dushanba..Yakshanba (**weekday 1..7, never 0**), each with a switch (ish
  kuni / dam olish) and one or more intervals (start/end `HmTime` via 24 h pickers, "+ oraliq");
  button "Dushanbani ish kunlariga nusxalash" (copies Monday to Tue-Sat); "Standart jadval" fills
  Mon-Sat 09:00-18:00 when the staff has no rows. Validation: `start < end`, no overlapping
  intervals in a day (error text on the row "Oraliqlar kesishmasligi kerak"); all days off asks
  `confirmAction` "Barcha ish vaqtlari o'chiriladi. Davom etasizmi?" (the server deletes all rows
  when `items` is empty). Save → `saveWorkingHours`; 422 pointers `items[i].start_time` map back
  to the row of the i-th item. Dirty state guarded on leave.
- Dam olish: upcoming (date ≥ today) list, past collapsed ("O'tganlar"); tile: date
  `UzDates.weekdayDayMonth`, "Kun bo'yi" or "10:00 – 14:00", reason; delete (confirm). FAB opens
  `TimeOffDialog`: Sana (required, ≥ today), switch "Kun bo'yi" (default on) else start/end times
  (`start < end`), Sabab (≤160). Body via `TimeOffInput` (times as `HH:MM:SS`).

Tests: `hours_model_test.dart` (overlap and start<end validation, toInput yields `{items:[...]}` with weekday 7 for Sunday); editor renders 7 rows from fixture hours; time-off dialog requires a date.

### 9.9 `money` (Moliya, Ish haqi)

Files: `finance_screen.dart`, `payroll_screen.dart`, `providers.dart`, `actions.dart`, `widgets/transaction_tile.dart`, `widgets/finance_filters.dart`, `widgets/commission_dialog.dart`.

Providers:

| Provider | Type | Endpoint |
|---|---|---|
| `financeRangeProvider` | `NotifierProvider.autoDispose<FinanceRange, DateRangeValue>` | default `last30` |
| `financeFiltersProvider` | `NotifierProvider.autoDispose<FinanceFilters, ({String? provider, String? type, String? status})>` | provider `payme`/`click` (read-only history may contain click), type `deposit`/`refund`/`float`, status `created`/`pending`/`paid`/`canceled`/`refunded` |
| `financeSummaryProvider` | `FutureProvider.autoDispose.family<FinanceSummary, ({LocalDate from, LocalDate to})>` | `GET Endpoints.financeSummary` query `ApiQuery.utcDays(from: from, to: to)` → `from,to,income_tiyin,refunds_tiyin,net_tiyin,count,by_provider[{provider,amount_tiyin,count}]` |
| `financeTransactionsProvider` | `AsyncNotifierProvider.autoDispose.family<FinanceTransactionsPaged, Paged<FinanceTransaction>, ({LocalDate from, LocalDate to, String? provider, String? type, String? status})>` | `GET Endpoints.financeTransactions` query `utcDays + {provider,type,status} + ApiQuery.page(n)` → rows `id,provider,type,status,amount_tiyin,created_at,appointment_id,client_name,service_name`, meta; `loadMore()` |
| `payrollRangeProvider` | `NotifierProvider.autoDispose<PayrollRange, DateRangeValue>` | default `month` (1st of month .. today) |
| `payrollProvider` | `FutureProvider.autoDispose.family<PayrollReport, ({LocalDate from, LocalDate to})>` | `GET Endpoints.payroll` query `ApiQuery.utcDays(from: from, to: to)` → `staff[{staff_id,name,commission_percent,appointments,revenue_tiyin,earnings_tiyin}]`, `totals{revenue_tiyin,earnings_tiyin}`; watches staff + appointments revisions |
| `moneyActionsProvider` | `Provider<MoneyActions>` | `setCommission(int staffId, int percent)` → `PATCH Endpoints.staffById(staffId)` body `{"commission_percent": percent}` → `Staff`; bumps staff |

**FinanceScreen** ("Moliya"): `PeriodChips` (last7, last30, last90, custom); KPI cards "Kirim"
(`income_tiyin`), "Qaytarishlar" (`refunds_tiyin`), "Sof" (`net_tiyin`), "Tranzaksiyalar"
(`count`); "To'lov tizimlari" rows (`by_provider`: provider name capitalised, amount, count);
filter chips (type, status, provider) opening `FinanceFilters`; `PagedListView` of
`TransactionTile` (date `UzDates.dateTime(createdAt)`, client name, service, `typeLabel`,
provider, amount coloured by type: refund negative, status chip `statusLabel`); tile with
`appointmentId` → `Routes.appointment(id)`. No refund button (the server refund is a stub).
Footnote "Sanalar UTC kunlari bo'yicha." Empty: "Bu davrda to'lovlar yo'q".

**PayrollScreen** ("Ish haqi"): `PeriodChips` (month default, prevMonth, custom); totals card
("Jami tushum" `totals.revenue_tiyin`, "Jami ish haqi" `totals.earnings_tiyin`); rows per staff:
name, "N ta yakunlangan", tushum, "Komissiya N%" (tap → `CommissionDialog` int 0..100 →
`setCommission` → refetch), ish haqi bold. Formula footnote: "Ish haqi = tushum × komissiya %;
tushum yakunlangan yozuvlarning xizmat narxlari bo'yicha." Rental footnote as in §9.2.
Empty: "Faol xodimlar yo'q".

Tests: finance KPIs and a paged list render; payroll commission dialog rejects 101 and sends `{"commission_percent": 40}`.

### 9.10 `reviews` (Sharhlar)

Files: `reviews_screen.dart`, `providers.dart`, `actions.dart`, `widgets/review_card.dart`, `widgets/reply_sheet.dart`, `widgets/rating_summary_card.dart`.

Providers:

| Provider | Type | Endpoint |
|---|---|---|
| `reviewsFilterProvider` | `NotifierProvider.autoDispose<ReviewsFilter, ({int? rating, bool? hasReply})>` | |
| `reviewsPagedProvider` | `AsyncNotifierProvider.autoDispose.family<ReviewsPaged, ReviewsPage, ({int? rating, bool? hasReply})>` | `GET Endpoints.reviews` query `{rating, has_reply: hasReply (bool → 1/0), ...ApiQuery.page(n)}`; `ReviewsPage = ({Paged<Review> page, RatingSummary summary})` with `RatingSummary.fromMeta(meta)` (`avg`, `count`, `distribution`); `loadMore()`, `replaceItem(Review)` |
| `reviewActionsProvider` | `Provider<ReviewActions>` | `reply(int id, String text)` → `POST Endpoints.reviewReply(id)` body `{"reply": text}` → `Review` |

Screen ("Sharhlar"): `RatingSummaryCard` (big avg with `StarRating`, "N ta sharh", 5 distribution
bars using `summary.share(stars)`); filter chips "Hammasi / Javobsiz / Javob berilgan" and star
chips 5..1; `PagedListView` of `ReviewCard`: stars, author name, `UzDates.ago(createdAt)`,
"service · staff", comment, "Yashirilgan" badge when `status == hidden`, reply block (muted
background, "Sizning javobingiz", `UzDates.ago(repliedAt)`). Button "Javob berish" / "Javobni
tahrirlash" → `ReplySheet` (multiline, required, 1..1000 chars with counter) → `reply` →
`replaceItem`; 422 pointer `reply` on the field. Empty: "Hali sharhlar yo'q. Mijozlar Bizcat
ilovasi orqali sharh qoldiradi."

Tests: summary bars and cards render; reply sheet validates empty text and replaces the card's reply after success.

### 9.11 `settings` (Onlayn-yozuv sozlamalari)

Files: `booking_settings_screen.dart`, `providers.dart`, `widgets/booking_section.dart`, `widgets/profile_section.dart`, `widgets/location_section.dart`, `widgets/brand_section.dart`, `widgets/telegram_section.dart`.

Providers: `bookingSettingsProvider = AsyncNotifierProvider.autoDispose<BookingSettingsNotifier, BookingSettings>`:
- `build()` → `GET Endpoints.bookingSettings` → `BookingSettings` (`name, phone, tagline, slug, online_booking_enabled, booking_lead_min, booking_horizon_days, logo, cover, brand_color, brand_color_2, telegram_connected, telegram_bot_username, address, map_url, city, district, lat, lng, description, is_listed, rating_avg, rating_count`)
- `Future<BookingSettings> save(BookingSettings edited)` → body `edited.diff(original)`; empty diff → no request; `PUT Endpoints.bookingSettings` → new state
- `Future<BookingSettings> connectTelegram(String token)` / `disconnectTelegram()` → `PUT` body `BookingSettings.telegramTokenBody(token)` / `('')`; response adds `telegram_webhook_ok`, `telegram_error`

Screen: sections as `SectionCard`s, each with its own "Saqlash" (sends only that section's diff):
1. **Onlayn yozuv**: switch "Onlayn yozilish yoqilgan" (`online_booking_enabled`), "Eng kamida
   necha daqiqa oldin" (`booking_lead_min`, int 0..10080), "Necha kun oldinga" (`booking_horizon_days`,
   int 1..365), Slug (`^[a-z0-9-]{3,80}$`, preview `https://{slug}.tizbiz.uz`, warning "Slugni
   o'zgartirsangiz eski havolalar ishlamay qoladi"; 422 pointer `slug` shows the server text).
2. **Biznes ma'lumotlari**: Nomi (required ≤128), Telefon (`PhoneField`, optional), Shior
   (`tagline`, ≤160), Tavsif (`description`, ≤2000, counter).
3. **Manzil va katalog**: Manzil, Shahar, Tuman, Xarita havolasi (`map_url`, must start with
   `http`), Kenglik/Uzunlik (`lat` -90..90, `lng` -180..180, decimal), switch "Bizcat katalogida
   ko'rsatish" (`is_listed`). Clearing a field sends null (handled by `diff`).
4. **Brend**: logo and cover previews read-only ("Rasmlarni web kabinetda yuklang"), Asosiy rang /
   Ikkinchi rang (`brand_color`, `brand_color_2`, `^#[0-9A-Fa-f]{6}$`) with 8 preset swatches
   (`#1E1B4B #2563EB #0EA5E9 #10B981 #F59E0B #F97316 #EF4444 #8B5CF6`) and a small preview chip.
5. **Telegram bot**: status "Ulangan: @username" / "Ulanmagan"; token field (obscured, write-only,
   never prefilled) + "Ulash" → `connectTelegram`; "Uzish" (confirm) → `disconnectTelegram`; when
   `telegramWebhookOk == false` show a warning with `telegramError`. Hint: "@BotFather'dan olingan
   token. Webhook faqat https serverda ishlaydi."
6. **Reyting** (read-only): `StarRating(ratingAvg)`, "N ta sharh", link "Sharhlar" → `Routes.reviews`.

States: loading, errors per §7.4; 403 → forbidden view. Tests: diff of an edited tagline sends only `{"tagline": ...}` through a fake notifier; slug validation; telegram warning renders.

### 9.12 `team` (Jamoa)

Files: `team_screen.dart`, `providers.dart`, `actions.dart`, `widgets/member_tile.dart`, `widgets/member_form_sheet.dart`.

Providers:

| Provider | Type | Endpoint |
|---|---|---|
| `teamProvider` | `FutureProvider.autoDispose<List<TeamMember>>` | `GET Endpoints.team` → `[{user_id,name,phone,role,staff_id}]`; watches staff revision |
| shared `staffListProvider` | | to show and pick the linked staff row |
| `teamActionsProvider` | `Provider<TeamActions>` | `add(TeamMemberInput in)` → `POST Endpoints.team` body `{"phone","name","role","password"?,"staff_id"?}` → `TeamMember` (201); `patch(int userId, TeamMemberPatch p)` → `PATCH Endpoints.teamMember(userId)` body `{"role"?,"staff_id"?}` (`staff_id: null` = unlink) → `TeamMember` (partial: `user_id, role, staff_id`); `remove(int userId)` → `DELETE Endpoints.teamMember(userId)` (204). All bump staff (links change `staff.user_id`). |

Screen ("Jamoa"): member tiles: name, `Phone.format(phone)`, role badge (`BizRole.label`),
linked staff ("Xodim: Usta Jahongir" or "Xodimga bog'lanmagan" muted), "Siz" chip for the current
user. Owner only (`team.manage`): FAB "+ A'zo qo'shish", tile menu "Tahrirlash" / "Chiqarish".
Admin sees the list read-only with a note "Faqat biznes egasi jamoani o'zgartira oladi."

`MemberFormSheet`:
- Add: Telefon (required), Ism (required ≤128), Rol (Xodim default / Administrator / Egasi),
  Parol (optional; helper "Yangi foydalanuvchi uchun majburiy"; when given ≥ 6 chars), Xodim
  profili (dropdown: "Bog'lamaslik" + active staff rows whose `userId == null`; shown for any role).
- Edit: Rol and Xodim profili (rows with `userId == null` or `== member.userId`; "Bog'lamaslik"
  sends `TeamMemberPatch(unlinkStaff: true)`).
- Errors: 400 `Yangi foydalanuvchi uchun parol talab qilinadi.` → on the password field; 409
  `Bu foydalanuvchi allaqachon jamoa a'zosi.` / `Bu xodim boshqa hisobga bog'langan.` → banner;
  422 pointers `staff_id`, `role` (last owner) → field.
- Remove: `confirmAction(destructive)` "A'zoni jamoadan chiqarasizmi? U darhol tizimdan chiqariladi."
- After changing the current user's own role or link → `session.refreshMe()`.

Tests: admin sees no FAB; owner add form requires phone and name; editing the link sends `{"staff_id": 2}`.

---

## 10. Staff features

All staff screens first check `active.hasStaffProfile`. When false they render
`StaffNotLinkedView` and make **no** `/v1/me/*` call. A 404 with detail `Hisobingiz xodim
profiliga bog'lanmagan.` from any `/v1/me/*` call also renders `StaffNotLinkedView` and calls
`session.onForbidden()` (refreshes `active.staff_id`).

### 10.1 `me_day` (Mening kunim + my appointment detail)

Files: `my_day_screen.dart`, `my_appointment_detail_screen.dart`, `providers.dart`, `actions.dart`, `widgets/my_appointment_card.dart`, `widgets/today_header.dart`.

Providers:

| Provider | Type | Endpoint |
|---|---|---|
| `myDayRangeProvider` | `NotifierProvider.autoDispose<MyDayRange, MyDayView>` | `enum MyDayView { today, tomorrow, week }`; week = today..today+6 |
| `myAppointmentsProvider` | `FutureProvider.autoDispose.family<List<Appointment>, ({LocalDate from, LocalDate to})>` | `GET Endpoints.meAppointments` query `ApiQuery.localDays(from: from, to: to)` → business-shape items, `starts_at` ASC, own staff only; watches appointments revision |
| `myTodayStatsProvider` | `FutureProvider.autoDispose<MeStats>` | `GET Endpoints.meStats` query `ApiQuery.localDays(from: today, to: today)` → uses `today{total,completed,next_at}`, `earnings_tiyin` |
| `myAppointmentProvider` | `FutureProvider.autoDispose.family<Appointment, int>` | `GET Endpoints.meAppointment(id)` (404 `Bron topilmadi.` if not mine) |
| `myAppointmentActionsProvider` | `Provider<MyAppointmentActions>` | `setStatus(int id, AppointmentStatus next)` → `PATCH Endpoints.meAppointment(id)` body `{"status": next.wire}` → `Appointment`; bumps appointments |

**MyDayScreen** ("Mening kunim"):
- `TodayHeader`: greeting "Salom, `<first name>`", `UzDates.weekdayDayMonth(today)`, three
  counters "Bugun N ta", "Yakunlandi N ta", "Bugungi daromadim `Money.compact(earnings_tiyin)`",
  and "Keyingi: 10:30" from `today.next_at` (or "Bugun boshqa yozuv yo'q").
- Segmented "Bugun / Ertaga / Hafta"; week view groups by day headers.
- `MyAppointmentCard`: time range, status badge, client name, `PhoneLink` (call button), service +
  `UzDates.duration`, notes preview, rental session/guests; action buttons for
  `status.staffNext` (pending → Tasdiqlash, Keldi, Yakunlash, Kelmadi; confirmed → Keldi,
  Yakunlash, Kelmadi; arrived → Yakunlash, Kelmadi). **Never a cancel button** (the staff table
  has no `canceled`). "Kelmadi" asks `confirmAction`. Optimistic update of the card, revert on
  error; 409 → snack server detail and refetch.
- Tap card → `Routes.myAppointment(id)`.
- `PollWhileVisible` invalidates the list and `myTodayStatsProvider`.
- Empty: icon `free_breakfast_outlined`, "Bugun yozuvlar yo'q" / "Ertaga yozuvlar yo'q" / "Bu
  hafta yozuvlar yo'q".

**MyAppointmentDetailScreen**: same sections as the manager detail minus deposit link, client
card link and source; status buttons from `staffNext`; terminal → "Bu yozuv yakunlangan".

Tests: not-linked active renders `StaffNotLinkedView` and performs no request; a confirmed card shows Keldi/Yakunlash/Kelmadi and no "Bekor qilish"; tapping Keldi calls `setStatus(id, arrived)`.

### 10.2 `me` (Statistikam, Jadvalim, Profil)

Files: `my_stats_screen.dart`, `my_schedule_screen.dart`, `profile_screen.dart`, `providers.dart`, `widgets/earnings_chart.dart`, `widgets/week_hours_table.dart`.

Providers:

| Provider | Type | Endpoint |
|---|---|---|
| `myStatsRangeProvider` | `NotifierProvider.autoDispose<MyStatsRange, DateRangeValue>` | default `month`; presets today, week, month, prevMonth, custom (max 366) |
| `myStatsProvider` | `FutureProvider.autoDispose.family<MeStats, ({LocalDate from, LocalDate to})>` | `GET Endpoints.meStats` query `ApiQuery.localDays(from: from, to: to)` → `range{from,to,timezone}`, `staff{id,name,commission_percent}`, `appointments{total,pending,confirmed,arrived,completed,no_show,canceled}`, `revenue_tiyin`, `earnings_tiyin`, `clients_served`, `series[{date,count,completed,revenue_tiyin,earnings_tiyin}]`, `today{...}`; watches appointments revision |
| `myScheduleProvider` | `FutureProvider.autoDispose<MeSchedule>` | `GET Endpoints.meSchedule` query `ApiQuery.localDays(from: today, to: today+60)` → `working_hours[{id,weekday,start_time,end_time}]`, `time_off[{id,date,start_time,end_time,reason}]` |
| `meStaffProvider` | `FutureProvider.autoDispose<Staff>` | `GET Endpoints.meStaff` → `{id,business_id,name,specialization,commission_percent,is_active,business{id,name,slug,engine,timezone,logo}}` |

**MyStatsScreen** ("Statistikam"): `PeriodChips`; KPI grid "Yakunlangan" (`appointments.completed`),
"Tushum" (`revenue_tiyin`), "Ish haqim" (`earnings_tiyin`, sub "komissiya N%"), "Mijozlar"
(`clients_served`), "Kelmadi" (`no_show`), "Bekor qilingan" (`canceled`); `EarningsChart` (bar per
day of `series.earnings_tiyin`, tooltip with count/completed); status breakdown list. Footnote:
"Ish haqi = yakunlangan xizmatlar narxi × komissiya %." Empty series (all zero): "Bu davrda
yakunlangan yozuvlar yo'q".

**MyScheduleScreen** ("Jadvalim"): `WeekHoursTable` Dushanba..Yakshanba with intervals
("09:00 – 20:00", several per day joined) or "Dam olish kuni"; today's row highlighted. "Dam olish
kunlari" list (next 60 days): date, "Kun bo'yi" or the time range, reason. Read-only note
"Jadvalni o'zgartirish uchun rahbaringizga murojaat qiling." Empty hours: "Ish vaqti
belgilanmagan".

**ProfileScreen** ("Profil"): user card (name, `Phone.format`), business card (`BusinessAvatar`,
name, role "Xodim"), staff card from `meStaffProvider` (name, specialization, "Komissiya N%")
or `StaffNotLinkedView` (compact) on 404/no link; "Biznesni almashtirish" (when >1 business) →
`Routes.pickBusiness`; theme segmented control; "Chiqish" (confirm) → `logout()`; app version.
No password change (no endpoint): note "Parolni o'zgartirish uchun biznes egasiga murojaat qiling."

Tests: stats KPIs from a fixture; schedule renders "Dam olish kuni" for a missing weekday and weekday 7 as Yakshanba; profile logout calls `FakeSessionNotifier.logout()`.

---

## 11. Server behaviour the UI must respect

| Topic | Rule |
|---|---|
| Appointment transitions (manager) | `AppointmentStatus.adminNext` = server `TRANSITIONS`: pending → confirmed, arrived, completed, no_show, canceled; confirmed → arrived, completed, no_show, canceled; arrived → completed, no_show, canceled; terminal → none. Never offer "→ pending". |
| Appointment transitions (staff) | `staffNext` = the same minus canceled (BP §4.3). |
| Orders | No transition rules on the server; any of the 6 statuses; spelling `cancelled`. |
| Staff tokens | The staff shell calls exactly: `POST /v1/auth/login`, `GET /v1/auth/me`, `POST /v1/auth/switch/{id}`, `GET/PATCH /v1/me/*`, `GET /v1/orders`, `PATCH /v1/orders/{id}` (BP §2b/§2.9). Everything else answers 403 to a staff token by design, including `GET /v1/staff`, `/v1/services`, `/v1/service-categories`, working-hours/time-off GETs, `GET /v1/settings/booking` and `POST /v1/uploads`. `active.permissions` for staff is `["orders","me"]`. No staff-shell provider may read the shared `staffListProvider`/`servicesListProvider`/`workingHoursProvider`. |
| Ranges | appointments: `ApiQuery.appointments` (UTC datetimes); orders: `ApiQuery.orders` (unix); analytics/payroll/finance: `ApiQuery.utcDays` (UTC days); `/v1/me/*`, booked-days: `ApiQuery.localDays`. |
| Staff list | Includes inactive rows; pickers and the timetable filter `isActive`. |
| Working hours | PUT replaces the whole week; empty `items` deletes everything; weekday 1..7; the server does not check `start < end` (the app must). |
| Availability | Empty `slots` when online booking is off or the service is not bookable: the admin manual-time path still works. |
| Rental | A booking without `session` covers 10:00-23:00 and blocks both sessions; status is always pending. Analytics/payroll revenue ignores guests. |
| Payments | Payme only; deposit key `dep-<id>-payme`; no refunds from the app (server refund is a stub). |
| Not supported now | rescheduling/editing an appointment, image upload (no picker dependency), password change, loyalty/certificates/deposits/inventory screens (web only), push notifications. |

---

## 12. Tests

Run from `mobile-app/`: `flutter analyze` (zero issues) and `flutter test` (all green, no network).

### 12.1 Test harness (skeleton, `test/support/`)

- `test_app.dart`
  ```dart
  /// Pumps [child] inside ProviderScope + MaterialApp (material_ui) with the app theme, uz locale,
  /// pollingEnabledProvider=false, clockProvider fixed to 2026-10-17 07:00Z, and a FakeSessionNotifier.
  Future<FakeSessionNotifier> pumpScreen(WidgetTester tester, Widget child, {
    BizRole role = BizRole.owner, Engine engine = Engine.slot, int? staffId, String category = 'barber',
    List<Override> overrides = const [], ThemeMode themeMode = ThemeMode.light});
  /// Same but boots the real router at [location] (for route/redirect smoke tests).
  Future<void> pumpRouterAt(WidgetTester tester, String location, {BizRole role, Engine engine, int? staffId, List<Override> overrides});
  ```
- `fake_session.dart`: `FakeSessionNotifier extends SessionNotifier` with a fixed initial state and
  recorded calls (`loginCalls`, `switchCalls`, `logoutCount`, `refreshMeCount`, `forbiddenCount`).
- `fake_http.dart`: `FakeHttp implements HttpClientAdapter` (dio) with `on(String method, String path, {int status = 200, Object? body, Map<String, String> headers})`, unmatched requests → 404; records requests (method, path, query, decoded body, headers). Helper `ApiClient fakeApi(FakeHttp http, {String? token})` (biz token built from base64url JSON, no real signature) for `apiClientProvider.overrideWithValue(...)`.
- `fixtures.dart`: builders returning core models via `fromJson` of JSON copied from BP §4 and CS
  fixtures: `fxAuthSession({role, engine, staffId, businesses})`, `fxAppointment({id, status, startsAt, staffId, ...})`,
  `fxOrder`, `fxClient`, `fxClientDetail`, `fxService`, `fxCategory`, `fxStaff`, `fxWorkingHours`, `fxTimeOff`,
  `fxAnalytics`, `fxPayroll`, `fxFinanceSummary`, `fxTransactions`, `fxReview`, `fxRatingSummary`,
  `fxSettings`, `fxTeam`, `fxMeStats`, `fxMeSchedule`, `fxMeStaff`.

Feature tests override their own providers (`provider.overrideWith((ref, arg) async => fixture)`,
or a fake `XActions` via `xActionsProvider.overrideWithValue(FakeXActions())`), or use
`apiClientProvider` backed by `FakeHttp` when the JSON path itself is under test.

### 12.2 Skeleton tests

| File | Covers |
|---|---|
| `test/app/redirect_test.dart` | table of (state, active, location) → expected: booting → /splash; signed out on /o/clients → /login; no businesses → /no-business; needsPicker → /pick-business; owner on / → /o/dashboard; catalog owner on / → /o/orders; catalog owner on /o/timetable → /o/orders; slot owner on /o/orders → /o/dashboard; admin on /o/more/team stays (team.read) ; staff on /o/dashboard → /s/today; staff without staff_id in catalog on / → /s/orders; linked staff in catalog on / → /s/orders; linked catalog staff on /s/today → /s/orders; staff on /appointment/5 → /s/today; owner on /s/today → /o/dashboard; manager without `finance` on /o/more/finance → home |
| `test/app/nav_items_test.dart` | manager items per engine (slot 5 with "Navbatlar", rental "Ijaralar", medical has Buyurtmalar and no Mijozlar, catalog 4 items); staff items: slot (Mening kunim, Statistikam, Jadvalim, Profil), medical (all five), catalog (Jadvalim, Buyurtmalar, Profil) |
| `test/app/routes_smoke_test.dart` | every route in §6.2 builds its screen class with placeholder content (owner, staff, catalog variants) |
| `test/core/session_notifier_test.dart` (FakeHttp) | boot without token → SignedOut; boot with token + me 200 → SignedIn(epoch 1); me 401 → SignedOut with message; offline boot with cache → fromCache; login stores the token, normalized phone in the body, `needsPicker` when 2 businesses; login 401 rethrows and does not log out; switch replaces the token and bumps epoch; a 401 on any later request → SignedOut('Sessiya tugadi. Qaytadan kiring.') |
| `test/shared/widgets_test.dart` | AsyncBody (loading, data, empty, network error → "Internet aloqasi yo'q", stale banner); PhoneField formatting "901234567" → "90 123 45 67"; SomField "150 000" → 15000000; status badges' labels; StaffNotLinkedView text; PollWhileVisible does not tick when disabled |
| `test/app/theme_test.dart` | light/dark build with accent; AppColors present |

### 12.3 Feature tests (one smoke test per main screen at least)

Each main screen: (1) data renders the key texts, (2) empty state text, (3) offline error shows
"Internet aloqasi yo'q", (4) the primary action calls the right method/endpoint with the exact
body. Specific cases are listed per feature in §9 and §10. File names:
`test/features/<feature>/<screen>_test.dart`, pure logic tests `test/features/<feature>/<file>_test.dart`.

---

## 13. Skeleton deliverables (agent S)

1. Project + platform identifiers + pubspec + analysis options + assets (§1).
2. `lib/main.dart`, `lib/app/**`, `lib/core/**`, `lib/shared/**` exactly as specified (§3-§8).
3. **One placeholder file per route** at the paths of §6.2 with the final class name and the exact
   constructor, body `PlaceholderScreen(title: '<Uzbek title>')`, e.g.:
   ```dart
   import 'package:material_ui/material_ui.dart';
   import 'package:tizbiz_biznes/shared/widgets/placeholder_screen.dart';

   class AppointmentDetailScreen extends StatelessWidget {
     const AppointmentDetailScreen({super.key, required this.appointmentId});
     final int appointmentId;
     @override
     Widget build(BuildContext context) => PlaceholderScreen(title: 'Yozuv #$appointmentId');
   }
   ```
   plus an empty `test/features/<feature>/.gitkeep` per feature.
4. `MoreMenuScreen`, `SplashScreen` (logo + spinner), `NotFoundScreen` ("Sahifa topilmadi" + "Bosh
   sahifa" → `Routes.homeFor`) are final, not placeholders.
5. Test harness and skeleton tests (§12.1, §12.2).
6. `README.md`: run/build commands, dart-defines, demo credentials (BP §6.3), folder ownership rules.
7. Verify: `flutter pub get && flutter analyze && flutter test && flutter build web --release --dart-define=API_BASE=https://api.tizbiz.uz`.

---

## 14. Rules for feature agents

1. Replace only the placeholder files of your feature and add any files under
   `lib/features/<feature>/` and `test/features/<feature>/`. Keep each screen's class name, file
   path and constructor exactly (§6.2). You may change `StatelessWidget` to `ConsumerWidget` /
   `ConsumerStatefulWidget`.
2. Do not edit `pubspec.yaml`, `lib/app/**`, `lib/core/**`, `lib/shared/**`, other features, or
   `mobile/tizbiz_core`. If you need a shared widget that does not exist, write a private one in
   your folder and list it in your final report as a promotion candidate. If the core lacks a
   model field or endpoint, stop and report it.
3. Navigate only with `Routes.*`; refresh other features' data only with the revision providers.
4. Every provider that reads tenant data calls `requireActive(ref)` first.
5. Use the shared widgets for states (§7.4), polling (§7.5) and forms (§7.6).
6. Before finishing: `flutter analyze` (zero issues for the whole app), `flutter test`
   (whole suite green), `grep -rn "package:flutter/material.dart" lib test` empty, and
   `git status --porcelain mobile-app` lists only paths inside your feature folders.
7. Final report: files created, tests added, deviations, promotion candidates.

---

## 15. Feature ownership

Order: **S first (blocking)**, then all feature agents in parallel.

| Feature id | Folder | Files (lib/features/<folder>/ unless absolute) | Routes | Agent |
|---|---|---|---|---|
| skeleton | everything outside `lib/features/` and `test/features/`, plus the initial placeholder of every route | §2, §13 | 1, 10, not-found | **S** |
| auth | `auth/` | `login_screen.dart`, `business_picker_screen.dart`, `no_business_screen.dart`, `widgets/demo_login_chips.dart` | 2, 3, 4 | A1 |
| dashboard | `dashboard/` | `dashboard_screen.dart`, `providers.dart`, `widgets/{today_card,revenue_chart,appointments_bar_chart,top_services_card,staff_load_card,orders_summary_section}.dart` | 5 | A2 |
| timetable | `timetable/` | `timetable_screen.dart`, `providers.dart`, `layout.dart`, `widgets/{day_grid,appointment_block,staff_header}.dart` | 6 | A3 |
| appointments | `appointments/` | `appointments_screen.dart`, `appointment_detail_screen.dart`, `appointment_create_screen.dart`, `providers.dart`, `actions.dart`, `widgets/{appointment_tile,filters_sheet,slot_picker,rental_picker,client_picker}.dart` | 7, 23, 24 | A4 |
| orders | `orders/` | `orders_board_screen.dart`, `providers.dart`, `actions.dart`, `widgets/{order_card,order_detail_sheet,status_picker_sheet}.dart` | 8, 31 | A5 |
| clients | `clients/` | `clients_screen.dart`, `client_detail_screen.dart`, `client_form_screen.dart`, `providers.dart`, `actions.dart`, `widgets/{client_tile,tags_input,categories_editor}.dart` | 9, 25, 26, 27 | A6 |
| catalog | `catalog/` | `services_screen.dart`, `service_form_screen.dart`, `service_categories_screen.dart`, `actions.dart`, `widgets/{service_tile,category_dialog}.dart` | 11, 12, 13, 14 | A7 |
| staff_admin | `staff_admin/` | `staff_list_screen.dart`, `staff_form_screen.dart`, `staff_detail_screen.dart`, `actions.dart`, `hours_model.dart`, `widgets/{staff_info_tab,working_hours_editor,time_off_tab,time_off_dialog}.dart` | 15, 16, 17 | A8 |
| money | `money/` | `finance_screen.dart`, `payroll_screen.dart`, `providers.dart`, `actions.dart`, `widgets/{transaction_tile,finance_filters,commission_dialog}.dart` | 18, 19 | A9 |
| reviews | `reviews/` | `reviews_screen.dart`, `providers.dart`, `actions.dart`, `widgets/{review_card,reply_sheet,rating_summary_card}.dart` | 20 | A10 |
| settings | `settings/` | `booking_settings_screen.dart`, `providers.dart`, `widgets/{booking_section,profile_section,location_section,brand_section,telegram_section}.dart` | 21 | A11 |
| team | `team/` | `team_screen.dart`, `providers.dart`, `actions.dart`, `widgets/{member_tile,member_form_sheet}.dart` | 22 | A12 |
| me_day | `me_day/` | `my_day_screen.dart`, `my_appointment_detail_screen.dart`, `providers.dart`, `actions.dart`, `widgets/{my_appointment_card,today_header}.dart` | 28, 33 | A13 |
| me | `me/` | `my_stats_screen.dart`, `my_schedule_screen.dart`, `profile_screen.dart`, `providers.dart`, `widgets/{earnings_chart,week_hours_table}.dart` | 29, 30, 32 | A14 |

Each feature's tests live in `test/features/<folder>/`.

If fewer agents are available, these groupings never share a file: {A1 auth, A12 team, A11 settings},
{A2 dashboard, A9 money, A10 reviews}, {A3 timetable, A8 staff_admin}, {A4 appointments},
{A5 orders, A6 clients}, {A7 catalog}, {A13 me_day, A14 me}.

---

## 16. Done criteria

1. `flutter analyze` zero issues; `flutter test` green; `flutter build web --release` succeeds.
2. `grep -rn "package:flutter/material.dart" lib test` is empty; no hand-written `/v1/` path in
   `lib/` (`grep -rn "'/v1/" lib` empty).
3. Every route of §6.2 resolves to its final screen (no `PlaceholderScreen` left in `lib/features`).
4. Manual smoke against the local API (`php -S 127.0.0.1:8899 ...`, `flutter run -d chrome`):
   owner +998901111111 sees the slot manager shell; +998902222222 sees the catalog shell (no
   Jadval); staff +998931110001 sees Mening kunim with own bookings and can mark one Keldi; staff
   +998932220001 sees the Buyurtmalar tab and can move an order; removing a member in Jamoa logs
   that member out on their next request.
