# Bizcat spec: consumer Flutter app (`bizcat/`)

Status: **source of truth** for the skeleton agent (S0) and the feature agents (A1 to A10) that build
the consumer app "Bizcat" at `/Users/jahongirxushboqov/Sites/startup/bizcat`. Written 2026-10-17.

Where the other contracts live:

- `docs/mobile/BACKEND-PLAN.md` (**BP**): every endpoint, request and response field, error text.
- `docs/mobile/CORE-SPEC.md` (**CORE**): `package:tizbiz_core` (ApiClient, Endpoints, ApiQuery,
  models, Money, Phone, Dates, UzDates, Idempotency). Bizcat **never** re-declares a model, an
  endpoint path or a date encoding. If something is missing in core, ask the orchestrator. Do not
  add it to the app.
- The web storefront `apps/booking/src` is the reference for the booking flows. This spec ports it
  and cites file:line where behavior is copied.

Hard rules (all agents):

1. **Parallel-safe ownership.** S0 creates every file outside `lib/features/**` and
   `test/features/**`, plus one placeholder screen per route. A feature agent edits **only** inside
   its own `lib/features/<feature>/` and `test/features/<feature>/` folders (§14). Never edit
   `pubspec.yaml`, `lib/app/**`, `lib/core/**`, `lib/data/**`, `lib/shared/**`, `lib/theme/**` or
   `test/support/**`. If a feature needs a change there, it reports it to the orchestrator.
2. **No cross-feature imports.** A file in `lib/features/a/` may import `package:bizcat/app/routes.dart`,
   `package:bizcat/core/...`, `package:bizcat/data/...`, `package:bizcat/shared/...`,
   `package:bizcat/theme/...` and `package:tizbiz_core/tizbiz_core.dart`. It may not import from
   `lib/features/b/`. Features talk through **route paths** (`AppRoutes`) and shared providers only.
3. **Keep the screen class names and constructors exactly as in §5.** The router (S0) builds them.
4. **Packages: only the ones in §2.** No code generation (no freezed, json_serializable,
   riverpod_generator or build_runner).
5. **UI text is Uzbek Latin** with the ASCII apostrophe `'` (as the server writes it: `noto'g'ri`).
   Dart strings containing `'` use double quotes. No emoji in the UI. Use Material icons.
6. **Brand rules are strict (§3).** Apricot is for the main CTA button and map pins only. Never use
   it for text, never for small elements carrying text, and on apricot use indigo text.
7. **Money** comes in tiyin; show it only through `Money.format`. **Time**: parse with core, and show
   it in the business timezone (`business.timezone`, fallback `Asia/Tashkent`), never the device zone.
8. **Phones** sent to the API always go through `Phone.normalize` first.
9. **One Material library: `package:material_ui/material_ui.dart`** (and `package:cupertino_ui` if
   ever needed). On Flutter 3.47, go_router 18 and cached_network_image 4 import the decoupled
   `material_ui` package, while the SDK's `package:flutter/material.dart` is a separate copy with
   its own `Theme`/`MaterialApp`/localizations types. Never import `package:flutter/material.dart`
   in `lib/` or `test/` (the same rule as BIZNES-SPEC hard rule 3). Widgets-only imports
   (`package:flutter/widgets.dart`, `services.dart`, `foundation.dart`) are fine.

---

## 1. Product scope (MVP)

From the consumer-tz map (MVP list), within the fixed decisions:

| # | Capability | Feature folder |
|---|---|---|
| 1 | Splash, first-run onboarding with optional city pick, city picker | `onboarding` |
| 2 | OTP login (phone, then code, then an optional name) that gates booking, ordering, reviews and favorites | `auth` |
| 3 | Home: search bar, categories grid, the next upcoming booking, "Siz borgan joylar" revisit cards with one-tap rebook, featured and top-rated lists | `home` |
| 4 | Directory: search, category and city filters, sort, infinite list | `directory` |
| 5 | Business detail: cover, logo, rating, address with "Xaritada ochish", call, Telegram, favorite, hours, offerings by engine, reviews tab, all-reviews screen | `business` |
| 6 | Slot booking (slot engine, and medical when its payload has staff): service, staff, date strip with slots, confirm | `booking_slot` |
| 7 | Rental booking: session, guests, month calendar, confirm | `booking_rental` |
| 8 | Catalog ordering (catalog engine, and medical without staff): menu, cart, checkout | `booking_catalog` |
| 9 | My bookings and orders: upcoming/past and active/past, details, status chips, cancel, Payme deposit, review entry | `bookings` |
| 10 | Favorites | `favorites` |
| 11 | Loyalty wallet: points, cashback and deposit balance per business | `loyalty` |
| 12 | Profile: view, name and other fields edit, logout, delete account | `profile` |
| 13 | Reviews: compose and edit, my reviews | `reviews` |

Out of scope in this iteration: push notifications (polling and pull-to-refresh instead), Click
payments, referral, QR table ordering, map view, Russian UI (the locale code is ready; strings are
Uzbek only), deep links / app links, premium.

**Engine to flow decision (verified in code).** `MedicalEngine extends CatalogEngine`
(`common/engines/MedicalEngine.php`), so `GET /v1/site/{slug}` for a clinic returns
`categories/items` and **no `staff`**. The web routes `medical` to the catalog app
(`apps/booking/src/App.vue:14`). Bizcat picks the flow from the **payload shape**
(`bookingFlowFor`, §6.6): medical uses the slot flow only when the payload carries both `services`
and `staff`; otherwise it uses the catalog flow, the same as the web. This keeps the
"slot/medical" requirement working the day a medical payload starts exposing staff.

---

## 2. Project setup (S0)

### 2.1 Create

```bash
cd /Users/jahongirxushboqov/Sites/startup/bizcat        # bizcat-brand/ already lives here; keep it
~/development/flutter/bin/flutter create --org uz.tizbiz --project-name bizcat \
  --platforms android,ios,web --description "Bizcat: shahar biznes katalogi" .
~/development/flutter/bin/dart fix --apply --code=migrate_design_widgets   # flutter/material -> material_ui
mkdir -p assets/brand/png
cp bizcat-brand/*.svg assets/brand/ && cp bizcat-brand/png/*.png assets/brand/png/
```

Result: Android `applicationId uz.tizbiz.bizcat`, iOS bundle id `uz.tizbiz.bizcat`.

Then:
- Android `android/app/src/main/AndroidManifest.xml`: `android:label="Bizcat"`; add
  `<uses-permission android:name="android.permission.INTERNET"/>` (release needs it); add a
  `<queries>` block with intents for `VIEW https`, `VIEW tel` and `DIAL` (url_launcher on Android 11+).
- `android/app/src/debug/AndroidManifest.xml`: `android:usesCleartextTraffic="true"` on
  `<application>` (debug only, for `http://` local APIs).
- iOS `ios/Runner/Info.plist`: `CFBundleDisplayName` = `Bizcat`; `LSApplicationQueriesSchemes` =
  `tel`, `https`.
- Web `web/index.html`: `<title>Bizcat</title>`, `<meta name="theme-color" content="#1E1B4B">`,
  body background `#FAF6F0`, favicon `assets/brand/png/bizcat-favicon-48.png` (copy it to
  `web/favicon.png`). `web/manifest.json`: name and short_name `Bizcat`, `background_color`
  `#FAF6F0`, `theme_color` `#1E1B4B`; icons from `bizcat-app-icon-192.png` / `-512.png`.
- App icons: run `dart run flutter_launcher_icons` with the pubspec config below. If it fails
  without platform SDKs, copy the PNGs by hand (Android `mipmap-*`, web `icons/`) and note it.

### 2.2 `pubspec.yaml`

```yaml
name: bizcat
description: "Bizcat: shahar biznes katalogi (TizBiz consumer app)."
publish_to: none
version: 0.1.0+1

environment:
  sdk: ^3.9.0              # local toolchain: Flutter 3.47.7 / Dart 3.13.5

dependencies:
  flutter:
    sdk: flutter
  material_ui: ^1.6.0      # 1.6.0 is in the local pub cache; ships GlobalMaterialLocalizations
  cupertino_ui: ^1.1.0     # 1.1.2 in the cache; required transitively by go_router 18
  tizbiz_core:
    path: ../mobile/tizbiz_core
  flutter_riverpod: ^3.4.3
  go_router: ^18.0.2
  dio: ^5.9.0              # only so tests can inject a Dio; lib/ uses tizbiz_core's ApiClient
  flutter_svg: ^2.3.0
  google_fonts: ^6.3.3     # 6.3.3 is in the local pub cache; a newer major is fine if it resolves
  intl: any                # pinned transitively (material_ui -> flutter_localizations)
  url_launcher: ^6.3.2
  cached_network_image: ^4.0.4
  flutter_secure_storage: ^11.2.0   # if resolution fails, use the newest version that resolves (API used: read/write/delete only)
  shared_preferences: ^2.5.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  flutter_launcher_icons: ^0.14.4

flutter:
  uses-material-design: true
  assets:
    - assets/brand/
    - assets/brand/png/

flutter_launcher_icons:
  android: true
  ios: true
  image_path: assets/brand/png/bizcat-app-icon-1024.png
  remove_alpha_ios: true
  web:
    generate: true
    image_path: assets/brand/png/bizcat-app-icon-512.png
    background_color: "#FAF6F0"
    theme_color: "#1E1B4B"
```

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
    - avoid_print
    - unawaited_futures
    - always_declare_return_types
    - directives_ordering
```

### 2.3 Riverpod 3 / go_router 18 ground rules

- Only `Provider`, `FutureProvider`, `StreamProvider`, `NotifierProvider` and `AsyncNotifierProvider`
  (plus `.autoDispose` and `.family`). Never import `package:flutter_riverpod/legacy.dart`
  (`StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider`).
- Family notifiers get their argument **through the constructor**:
  `AsyncNotifierProvider.autoDispose.family<C, T, A>(C.new)` with `class C extends AsyncNotifier<T> { C(this.arg); final A arg; ... }`.
- Family keys are values with `==`/`hashCode`: a `String`, an `int`, a Dart record such as
  `(int staffId, int serviceId, LocalDate date)`, or a class with `==` (e.g. `DirectoryQuery`).
- Use `AsyncValue.value`, `.hasValue`, `.isLoading`, `.when(...)` and `requireValue`. Check
  `ref.mounted` after every `await` inside notifiers before setting `state`.
- Automatic retry is **off** app-wide: `ProviderScope(retry: (_, __) => null, ...)`. A screen
  offers "Qayta urinish" instead.
- go_router: `GoRouterState.uri.queryParameters` / `pathParameters`. Use `context.push(...)` to
  open a detail page over the current tab, and `context.go(...)` to replace the stack after a
  finished flow. Only build paths with the `AppRoutes` helpers (§5.2); never hand-type them.

### 2.4 Running

```bash
# local API (BP §7.2): php -S 127.0.0.1:8899 -t api/web api/web/router.php
cd /Users/jahongirxushboqov/Sites/startup/bizcat
~/development/flutter/bin/flutter pub get
~/development/flutter/bin/flutter run -d chrome --web-port 5180 --dart-define=API_BASE=http://127.0.0.1:8899
~/development/flutter/bin/flutter analyze
~/development/flutter/bin/flutter test
~/development/flutter/bin/flutter build web --release --dart-define=API_BASE=http://127.0.0.1:8899
```

`API_BASE` is read by `ApiConfig.fromEnvironment()` (CORE §3.1). The default is
`https://api.tizbiz.uz`. Production does not have the consumer endpoints until the orchestrator
deploys BP; develop against the local API.

Demo logins (BP §6.3): `+998900000001` (rich data), `+998900000002` (rental booking),
`+998900000003` (empty), all with OTP `1111`.

---

## 3. Theme (S0, `lib/theme/`)

### 3.1 Tokens (`lib/theme/tokens.dart`)

```dart
abstract final class BzColors {
  // brand (bizcat-brand/BRAND.md)
  static const indigo = Color(0xFF1E1B4B);      // primary: app bar text, body text, primary buttons
  static const indigo700 = Color(0xFF312E81);   // pressed/hover of indigo
  static const apricot = Color(0xFFFF8A5B);     // CTA background + map pins ONLY
  static const apricot600 = Color(0xFFF26A35);  // pressed CTA
  static const cream = Color(0xFFFAF6F0);       // page background
  static const white = Color(0xFFFFFFFF);       // cards, sheets, nav bar
  static const muted = Color(0xFF5B5785);       // secondary text
  static const border = Color(0xFFECE5DA);      // card/input borders, dividers
  // derived (not brand colors; functional)
  static const indigo50 = Color(0xFFECEBFA);    // selected chip bg tint, nav indicator, info chip bg
  static const success = Color(0xFF15803D);  static const successBg = Color(0xFFE7F6EC);
  static const warning = Color(0xFFB45309);  static const warningBg = Color(0xFFFDF1E1);
  static const danger  = Color(0xFFB91C1C);  static const dangerBg  = Color(0xFFFDECEC);
  static const neutral = Color(0xFF6B6880);  static const neutralBg = Color(0xFFF1EEE8);
  // dark scheme (derived from indigo; brand defines none)
  static const darkBg = Color(0xFF121027);
  static const darkSurface = Color(0xFF1B1838);
  static const darkBorder = Color(0xFF2E2A55);
  static const darkText = Color(0xFFF4F2FF);
  static const darkMuted = Color(0xFFA9A5CF);
  static const darkPrimary = Color(0xFFC7C5F7);  // primary buttons/selection in dark; text on it = indigo
}

abstract final class BzSpace { static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0; static const gutter = 16.0; }
abstract final class BzRadius { static const s = 8.0, m = 12.0, l = 16.0, xl = 20.0, pill = 999.0; }
```

### 3.2 `AppTheme` (`lib/theme/app_theme.dart`)

```dart
abstract final class AppTheme {
  /// [googleFonts] false in tests (no runtime font fetching): falls back to the default family.
  static ThemeData light({bool googleFonts = true});
  static ThemeData dark({bool googleFonts = true});
}
```

Fonts: use only the `TextStyle`-returning helpers `GoogleFonts.sora(...)` / `GoogleFonts.manrope(...)`
(or their `fontFamily`) to build the `TextTheme` by hand. Never call `GoogleFonts.*TextTheme()`:
google_fonts 6.3.3 imports `package:flutter/material.dart`, so its `TextTheme` is the SDK type, not
the `material_ui` one (`TextStyle` comes from `painting` and is shared, so it is safe).

Material 3. Light `ColorScheme`: `primary` indigo, `onPrimary` white, `primaryContainer` indigo50,
`onPrimaryContainer` indigo, `secondary` apricot, `onSecondary` indigo, `surface` white,
`onSurface` indigo, `onSurfaceVariant` muted, `outline` border, `outlineVariant` border, `error`
danger. `scaffoldBackgroundColor` cream. Dark: `surface` darkSurface, `onSurface` darkText,
`primary` darkPrimary, `onPrimary` indigo, `secondary` apricot, `onSecondary` indigo, scaffold
darkBg, outline darkBorder. `MaterialApp.themeMode = ThemeMode.system`.

Typography (Sora for display/headline/title-large, Manrope for the rest):

| Style | Font | Size/weight |
|---|---|---|
| displaySmall | Sora | 28 / 700 |
| headlineSmall | Sora | 22 / 700 |
| titleLarge | Sora | 18 / 600 |
| titleMedium | Manrope | 16 / 700 |
| bodyLarge | Manrope | 16 / 500 |
| bodyMedium | Manrope | 15 / 500 |
| bodySmall | Manrope | 13 / 500, color `onSurfaceVariant` |
| labelLarge | Manrope | 15 / 700 (buttons) |
| labelMedium | Manrope | 13 / 700 |
| labelSmall | Manrope | 12 / 700 (chips, nav labels) |

Component themes:
- AppBar: background = scaffold color, foreground indigo, elevation 0, `scrolledUnderElevation` 0.5,
  title `titleLarge`, `centerTitle: false`.
- Card: white, elevation 0, radius `BzRadius.l`, side 1 px border.
- FilledButton (default) = **indigo** bg with white text, height 52, radius `BzRadius.m`,
  `labelLarge`. OutlinedButton: indigo text, 1.2 px indigo side. TextButton: indigo.
- The apricot CTA is **not** a theme default. It exists only as the `CtaButton` widget (§7).
- InputDecoration: filled white, radius `m`, enabled border = border color, focused = indigo 1.5 px,
  error = danger, `contentPadding` 14/16, `helperMaxLines: 2`, error text Manrope 13 danger.
- Chip / ChoiceChip: unselected white with border-color side and indigo text; selected indigo bg
  with white text; radius pill; label `labelMedium`.
- NavigationBar: white, height 68, indicator indigo50, selected icon indigo, unselected muted,
  labels `labelSmall`, always shown.
- BottomSheet: white, top radius `xl`, drag handle shown. Dialog: radius `xl`.
- SnackBar: floating, indigo bg, white text, radius `m`.
- Divider: border color, thickness 1. ProgressIndicator: indigo.
- `visualDensity: standard`; minimum tap target 48.

### 3.3 Brand usage rules (every agent)

| Element | Color |
|---|---|
| Main CTA per screen (`CtaButton`): Kod olish, Tasdiqlash, Band qilish, Bron qilish, Buyurtma berish, Payme orqali to'lash, Yuborish (review), Boshlash (onboarding) | apricot bg, **indigo** text and icon |
| Every other button | indigo filled / outlined / text |
| Map pin icon in `LocationCard` and the address row | apricot icon (an icon, not text) |
| Selected chips, the selected slot, the selected day, the selected calendar date | indigo bg, white text |
| Rating stars | indigo (filled) on border-color (empty). Never apricot, never gold |
| Prices | indigo `titleMedium` |
| Links, secondary text | indigo / muted |
| Badges on apricot (the cart count) | indigo text |

At most **one** `CtaButton` is visible per screen. Lists with per-item actions use indigo outlined
buttons.

Logos (`lib/shared/widgets/brand.dart`): `BrandLogo({BrandLogoVariant variant = onLight, double width = 132})`
renders `assets/brand/bizcat-logo-on-light.svg` / `-on-dark.svg`. The width is never below 120
(brand minimum). `BrandMark({double size = 32})` renders `bizcat-mark.svg`, minimum 24. Below
32 px use `bizcat-favicon.svg`. Never recolor, stretch or add a shadow; keep clear space of at
least one third of the mark width.

---

## 4. Folder layout

```
bizcat/
  pubspec.yaml  analysis_options.yaml  README.md (S0: how to run, demo logins)
  assets/brand/*.svg  assets/brand/png/*.png
  bizcat-brand/                      # untouched originals
  lib/
    main.dart                        # S0
    app/                             # S0
      app.dart                       # BizcatApp (MaterialApp.router)
      router.dart                    # routerProvider: every route, redirects, shell
      routes.dart                    # AppRoutes: path constants + builders, routeRequiresAuth()
      shell.dart                     # MainShell (NavigationBar, 5 branches)
    core/                            # S0: app-wide state and services (fully implemented)
      api.dart                       # apiConfigProvider, apiProvider
      secure_token_store.dart        # SecureTokenStore implements TokenStore
      prefs.dart                     # prefsProvider (SharedPreferences), AppPrefs
      session.dart                   # SessionState, SessionController, sessionProvider, helpers
      city.dart                      # kCities, cityProvider
      favorites.dart                 # FavoritesState, FavoritesController, favoritesProvider
      revisions.dart                 # bookingsRevisionProvider, reviewsRevisionProvider
      deposit.dart                   # DepositService, depositServiceProvider
      launcher.dart                  # UrlOpener, urlOpenerProvider, openMap/callPhone/openTelegram
      booking_flow.dart              # BookingFlow, bookingFlowFor(), bookingEntryPath(), ctaLabelFor()
      rental_pricing.dart            # RentalPricing (session prices, tables, limits)
      errors.dart                    # errorText(), isOffline()
      messenger.dart                 # scaffoldMessengerKey, showSnack(), showErrorSnack()
      images.dart                    # netImagesEnabledProvider
    data/                            # S0: read providers shared by 2+ features
      directory_query.dart           # DirectoryQuery
      directory_providers.dart       # categoriesProvider, businessListProvider, businessPageProvider
      storefront_providers.dart      # storefrontProvider
    theme/                           # S0
      tokens.dart  app_theme.dart
    shared/                          # S0: reusable widgets (§7)
      widgets/*.dart
      screens/placeholder_screen.dart  screens/not_found_screen.dart
    features/                        # one folder per feature; S0 writes the placeholder screens
      onboarding/  auth/  home/  directory/  business/  booking_slot/  booking_rental/
      booking_catalog/  bookings/  favorites/  loyalty/  profile/  reviews/
  test/
    support/                         # S0: fake_api.dart, fixtures.dart, pump.dart, fake_opener.dart
    app/                             # S0: router_test.dart, session_test.dart, favorites_test.dart, theme_test.dart, shared_widgets_test.dart
    features/<feature>/              # feature agents
```

Inside a feature folder (a convention, not enforced): `<name>_screen.dart` files (fixed paths
from §5), `providers.dart` (or `controller.dart`), `widgets/`. A feature may add any file inside
its folder.

---

## 5. Routes

### 5.1 Route table

Auth column: **none** = public; **soft** = public route whose screen shows `LoginPromptView`
when signed out (no redirect); **required** = the router redirects signed-out users to
`/login?from=<location>`.

| # | Path | Name | Screen class (constructor) | File | Feature | Auth | Params |
|---|---|---|---|---|---|---|---|
| 1 | `/splash` | `splash` | `SplashScreen()` | `lib/features/onboarding/splash_screen.dart` | onboarding | none | query `from` (kept by the router, not read by the screen) |
| 2 | `/onboarding` | `onboarding` | `OnboardingScreen({String? from})` | `lib/features/onboarding/onboarding_screen.dart` | onboarding | none | query `from` |
| 3 | `/city` | `city` | `CityPickerScreen()` | `lib/features/onboarding/city_picker_screen.dart` | onboarding | none | none |
| 4 | `/login` | `login` | `LoginPhoneScreen({String? from, bool expired = false})` | `lib/features/auth/login_phone_screen.dart` | auth | none | query `from`, `expired=1` |
| 5 | `/login/code` | `loginCode` | `OtpCodeScreen({required String phone, String? from})` | `lib/features/auth/otp_code_screen.dart` | auth | none | query `phone` (normalized, required; missing → redirect `/login`), `from` |
| 6 | `/login/name` | `loginName` | `LoginNameScreen({String? from})` | `lib/features/auth/login_name_screen.dart` | auth | required | query `from` |
| 7 | `/home` | `home` | `HomeScreen()` | `lib/features/home/home_screen.dart` | home | none | none (shell tab 0) |
| 8 | `/explore` | `explore` | `DirectoryScreen({String? q, String? category, String? sort, bool focus = false})` | `lib/features/directory/directory_screen.dart` | directory | none | query `q`, `category`, `sort`, `focus=1` (shell tab 1) |
| 9 | `/bookings` | `bookings` | `MyBookingsScreen({String? tab})` | `lib/features/bookings/my_bookings_screen.dart` | bookings | soft | query `tab` = `appointments` (default) or `orders` (shell tab 2) |
| 10 | `/bookings/a/:id` | `appointment` | `AppointmentDetailScreen({required int id, bool justCreated = false})` | `lib/features/bookings/appointment_detail_screen.dart` | bookings | required | path `id` (int), query `new=1` |
| 11 | `/bookings/o/:id` | `order` | `OrderDetailScreen({required int id, bool justCreated = false})` | `lib/features/bookings/order_detail_screen.dart` | bookings | required | path `id` (int), query `new=1` |
| 12 | `/favorites` | `favorites` | `FavoritesScreen()` | `lib/features/favorites/favorites_screen.dart` | favorites | soft | none (shell tab 3) |
| 13 | `/profile` | `profile` | `ProfileScreen()` | `lib/features/profile/profile_screen.dart` | profile | soft | none (shell tab 4) |
| 14 | `/profile/edit` | `profileEdit` | `ProfileEditScreen()` | `lib/features/profile/profile_edit_screen.dart` | profile | required | none |
| 15 | `/profile/wallet` | `wallet` | `LoyaltyWalletScreen()` | `lib/features/loyalty/loyalty_wallet_screen.dart` | loyalty | required | none |
| 16 | `/profile/reviews` | `myReviews` | `MyReviewsScreen()` | `lib/features/reviews/my_reviews_screen.dart` | reviews | required | none |
| 17 | `/b/:slug` | `business` | `BusinessScreen({required String slug, String? tab})` | `lib/features/business/business_screen.dart` | business | none | path `slug`; query `tab` = `offer` (default), `reviews`, `info` |
| 18 | `/b/:slug/reviews` | `businessReviews` | `BusinessReviewsScreen({required String slug})` | `lib/features/business/business_reviews_screen.dart` | business | none | path `slug` |
| 19 | `/b/:slug/book` | `bookSlot` | `SlotBookingScreen({required String slug, int? serviceId, int? staffId})` | `lib/features/booking_slot/slot_booking_screen.dart` | booking_slot | required | path `slug`; query `service`, `staff` (ints) |
| 20 | `/b/:slug/rent` | `bookRental` | `RentalBookingScreen({required String slug})` | `lib/features/booking_rental/rental_booking_screen.dart` | booking_rental | required | path `slug` |
| 21 | `/b/:slug/menu` | `menu` | `MenuScreen({required String slug, int? reorderOrderId})` | `lib/features/booking_catalog/menu_screen.dart` | booking_catalog | none | path `slug`; query `reorder` (order id) |
| 22 | `/b/:slug/cart` | `cart` | `CartScreen({required String slug})` | `lib/features/booking_catalog/cart_screen.dart` | booking_catalog | none | path `slug` |
| 23 | `/b/:slug/checkout` | `checkout` | `CheckoutScreen({required String slug})` | `lib/features/booking_catalog/checkout_screen.dart` | booking_catalog | required | path `slug` |
| 24 | `/review/new` | `reviewNew` | `ReviewComposeScreen({int? appointmentId, int? orderId, int? reviewId, String? businessName})` | `lib/features/reviews/review_compose_screen.dart` | reviews | required | query `appointment` or `order` (exactly one), `bname` |
| 25 | `/review/:id/edit` | `reviewEdit` | same class, `reviewId` set | same file | reviews | required | path `id` (int) |
| — | `/` | — | redirect to `/home` | `router.dart` | S0 | — | — |
| — | unknown or bad int | — | `NotFoundScreen()` (`errorBuilder`) | `lib/shared/screens/not_found_screen.dart` | S0 | — | — |

Navigator placement:
- Rows 7-16 live inside a `StatefulShellRoute.indexedStack` with 5 branches: home `/home`;
  explore `/explore`; bookings `/bookings` (children `a/:id`, `o/:id`); favorites `/favorites`;
  profile `/profile` (children `edit`, `wallet`, `reviews`). The bottom bar stays visible there.
- Rows 1-6 and 17-25 are top-level routes on the root navigator (full screen, no bottom bar).
  `/b/:slug` has children `reviews`, `book`, `rent`, `menu`, `cart`, `checkout`.
- Open business pages with `context.push(AppRoutes.business(slug))` so Back returns to the tab.
- A finished booking or order calls `context.go(AppRoutes.appointment(id, created: true))` /
  `context.go(AppRoutes.order(id, created: true))`. This replaces the stack; Back then lands on
  `/bookings`.

Integer params are parsed with `int.tryParse`. A non-int path id shows `NotFoundScreen`. A bad
optional query int is treated as null. `/review/new` with neither or both ids shows `NotFoundScreen`.

### 5.2 `AppRoutes` (`lib/app/routes.dart`, S0)

```dart
abstract final class AppRoutes {
  static const splash = '/splash', onboarding = '/onboarding', city = '/city';
  static const login = '/login', loginCode = '/login/code', loginName = '/login/name';
  static const home = '/home', explore = '/explore', bookings = '/bookings', favorites = '/favorites', profile = '/profile';
  static const profileEdit = '/profile/edit', wallet = '/profile/wallet', myReviews = '/profile/reviews';

  static String loginWith({String? from, bool expired = false});        // '/login?from=%2Fb%2Fx%2Fbook&expired=1'
  static String loginCodeWith({required String phone, String? from});
  static String loginNameWith({String? from});
  static String onboardingWith({String? from});
  static String exploreWith({String? q, String? category, String? sort, bool focus = false});
  static String bookingsWith({String tab = 'appointments'});           // 'orders' for the orders tab
  static String business(String slug, {String? tab});
  static String businessReviews(String slug);
  static String bookSlot(String slug, {int? serviceId, int? staffId});
  static String bookRental(String slug);
  static String menu(String slug, {int? reorder});
  static String cart(String slug);
  static String checkout(String slug);
  static String appointment(int id, {bool created = false});           // '/bookings/a/5012?new=1'
  static String order(int id, {bool created = false});
  static String reviewNew({int? appointmentId, int? orderId, String? businessName});
  static String reviewEdit(int id);
}

/// true for rows marked "required" in §5.1 (tested in test/app/router_test.dart).
bool routeRequiresAuth(Uri uri);
// required patterns: ^/login/name$, ^/bookings/[ao]/\d+$, ^/profile/(edit|wallet|reviews)$,
// ^/b/[^/]+/(book|rent|checkout)$, ^/review/(new|\d+/edit)$
```

Every builder omits null or empty query values and URL-encodes them (`Uri(path:, queryParameters:)`).

### 5.3 Redirect rules (`router.dart`, S0)

`routerProvider` is a `Provider<GoRouter>` with `initialLocation: '/splash'`, `refreshListenable`
set to a `ChangeNotifier` that S0 bumps from `ref.listen(sessionProvider, ...)`, and
`redirect(context, state)` applied in this order (`loc = state.uri`):

1. `loc.path == '/'` → `/home`.
2. Session `SessionUnknown` (restore still running): when not on `/splash`, go to
   `/splash?from=<loc>`. When already on `/splash`, stay.
3. On `/splash` once the session is known: if `!prefs.onboarded` → `AppRoutes.onboardingWith(from: from)`,
   else → `from ?? '/home'`. `from` must start with `/` and must not start with `/splash` or
   `/login` (otherwise `/home`).
4. `routeRequiresAuth(loc)` and not signed in → `AppRoutes.loginWith(from: loc.toString(), expired: lastSignOutReason == expired)`.
5. Signed in and `loc.path` is `/login` or `/login/code` → `from ?? '/home'` (same `from` check as rule 3).
   `/login/name` is allowed while signed in.
6. Otherwise null.

Onboarding is shown once, only when leaving the splash on first run. It is never forced on deep
routes.

### 5.4 Shell (`lib/app/shell.dart`, S0)

`MainShell({required StatefulNavigationShell navigationShell})`: a `Scaffold` with
`navigationShell` as body and a `NavigationBar` of 5 destinations. Tapping the current tab calls
`navigationShell.goBranch(i, initialLocation: true)` (pops to the tab root).

| i | Label | Icon / selected icon |
|---|---|---|
| 0 | Asosiy | `home_outlined` / `home` |
| 1 | Katalog | `search` / `manage_search` |
| 2 | Bronlarim | `event_note_outlined` / `event_note` |
| 3 | Sevimlilar | `favorite_border` / `favorite` |
| 4 | Profil | `person_outline` / `person` |

---

## 6. Core services and shared state (S0, fully implemented)

These are **working code, not stubs**. Feature agents depend on them from day one.

### 6.1 `main.dart`, `BizcatApp`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    retry: (_, __) => null,
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const BizcatApp(),
  ));
}

class BizcatApp extends ConsumerWidget {
  const BizcatApp({super.key, this.googleFonts = true});
  final bool googleFonts;               // tests pass false
  // MaterialApp.router(title: 'Bizcat', routerConfig: ref.watch(routerProvider),
  //   theme: AppTheme.light(googleFonts: googleFonts), darkTheme: AppTheme.dark(googleFonts: googleFonts),
  //   themeMode: ThemeMode.system, scaffoldMessengerKey: scaffoldMessengerKey,
  //   locale: const Locale('uz'), supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
  //   localizationsDelegates: GlobalMaterialLocalizations.delegates /* from material_ui */, debugShowCheckedModeBanner: false)
}
```

### 6.2 API (`core/api.dart`, `core/secure_token_store.dart`)

```dart
final apiConfigProvider = Provider<ApiConfig>((ref) => ApiConfig.fromEnvironment(log: kDebugMode ? debugPrint : null));
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore(const FlutterSecureStorage(), 'bizcat_consumer_token'));
final apiProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    config: ref.watch(apiConfigProvider),
    tokenKind: TokenKind.consumer,
    tokenStore: ref.watch(tokenStoreProvider),
    onUnauthorized: (_) => ref.read(sessionProvider.notifier).handleUnauthorized(),
  );
  ref.onDispose(client.close);
  return client;
});
```

`SecureTokenStore` is exactly CORE §4.1. Tests override `apiProvider` (§13).

**401 hook, end to end.** Any request that carried the consumer token and got a 401 makes core
(a) clear the token, (b) call `onUnauthorized` once per token value and (c) throw. Then
`handleUnauthorized()` sets `SessionSignedOut(reason: expired)`, clears the cached profile and
the favorites, and shows the snackbar `Sessiya tugadi. Qaytadan kiring.` once. The router
refreshes: on a **required** route this redirects to `/login?from=...&expired=1`. On soft tabs the
screens rebuild into `LoginPromptView`. On public routes nothing moves. Every consumer-scoped
provider watches `consumerIdProvider`, so it is rebuilt or emptied automatically.

### 6.3 Prefs (`core/prefs.dart`)

```dart
final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('override in main'));
final appPrefsProvider = Provider<AppPrefs>((ref) => AppPrefs(ref.watch(prefsProvider)));

final class AppPrefs {
  bool get onboarded;                           // 'bizcat.onboarded'
  Future<void> setOnboarded(bool v);
  String? get city;                             // 'bizcat.city'; null/'' = all cities
  Future<void> setCity(String? v);
  ConsumerUser? get cachedProfile;              // 'bizcat.profile' (ConsumerUser.toJson string)
  Future<void> setCachedProfile(ConsumerUser? u);
  List<String> get recentSearches;              // 'bizcat.recent_searches', most recent first, max 8
  Future<void> addRecentSearch(String q);       // trims, dedups (case-insensitive), ignores < 2 chars
  Future<void> clearRecentSearches();
}
```

Every read is wrapped in try/catch and falls back to the default.

### 6.4 Session (`core/session.dart`)

```dart
enum SignOutReason { none, user, expired, deleted }

sealed class SessionState { const SessionState(); }
final class SessionUnknown extends SessionState { const SessionUnknown(); }
final class SessionSignedOut extends SessionState { const SessionSignedOut([this.reason = SignOutReason.none]); final SignOutReason reason; }
final class SessionSignedIn extends SessionState {
  const SessionSignedIn(this.consumer, {this.stale = false});
  final ConsumerUser consumer;
  final bool stale;                 // true when restored offline from cache
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  @override SessionState build();   // returns SessionUnknown() and schedules restore() (Future.microtask)
  Future<void> restore();
  Future<void> signIn(ConsumerSession s);
  void updateConsumer(ConsumerUser c);         // after PATCH /me or GET /me; also refreshes the cache
  Future<void> refreshProfile();               // GET /v1/consumer/me -> updateConsumer; errors ignored except 401
  Future<void> signOut({SignOutReason reason = SignOutReason.user});
  void handleUnauthorized();                   // the 401 hook (above)
}

final isSignedInProvider = Provider<bool>((ref) => ref.watch(sessionProvider) is SessionSignedIn);
final currentConsumerProvider = Provider<ConsumerUser?>(...);   // null unless signed in
/// Key for consumer-scoped providers: changes on sign-in, sign-out and account switch.
final consumerIdProvider = Provider<int?>((ref) => ref.watch(currentConsumerProvider.select((c) => c?.id)));
```

`restore()`:
1. `token = await api.currentToken()` (core drops expired and wrong-kind tokens). Null →
   `SessionSignedOut()`.
2. `GET Endpoints.consumerMe` → `ConsumerUser.fromJson` (with `stats`) → `SessionSignedIn(user)`,
   and cache it.
3. 401 → the hook already set signed-out; return.
4. Network or 5xx error → `SessionSignedIn(prefs.cachedProfile ?? ConsumerUser(id: claims.sub, phone: ''), stale: true)`.
   Retry `refreshProfile()` on the next `AppLifecycleState.resumed` (S0 adds an
   `AppLifecycleListener` in `BizcatApp`).

`signIn(s)`: `await api.setToken(s.token)`, cache `s.consumer`, state `SessionSignedIn(s.consumer)`.
If `prefs.city` is null and `s.consumer.city != null`, set the city pref.

`signOut()`: `await api.clearToken()`, clear the cached profile, state `SessionSignedOut(reason)`.
There is no server logout endpoint (BP issues no refresh tokens).

### 6.5 City (`core/city.dart`)

```dart
const List<String> kCities = ['Toshkent', 'Termiz'];   // demo data is in Toshkent; Termiz is the target market
final cityProvider = NotifierProvider<CityController, String?>(CityController.new);
// CityController: build() => prefs.city; Future<void> set(String? city) (null = all, persisted)
String cityLabel(String? city) => city ?? 'Barcha shaharlar';
```

### 6.6 Booking flow helpers (`core/booking_flow.dart`)

```dart
enum BookingFlow { slot, rental, catalog }

/// From the storefront payload (authoritative):
/// rental -> rental; catalog -> catalog; slot -> slot;
/// medical -> slot if s.services.isNotEmpty && s.staff.isNotEmpty, else catalog.
BookingFlow bookingFlowFor(StorefrontData s);

/// When only the engine is known (cards, revisit items): rental->rental, catalog->catalog,
/// medical->catalog, slot->slot. Screens re-check with bookingFlowFor() after loading the storefront.
BookingFlow bookingFlowForEngine(Engine e);

/// AppRoutes.bookSlot / bookRental / menu.
String bookingEntryPath(String slug, BookingFlow f, {int? serviceId, int? staffId});

/// Primary CTA text on the business page:
/// slot -> 'Navbatga yozilish'; rental -> 'Sanani band qilish';
/// catalog with engine catalog -> 'Buyurtma berish'; catalog with engine medical -> 'Xizmatni tanlash'.
String ctaLabelFor(BookingFlow f, Engine e);
```

**Mismatch guard.** Each flow screen (`SlotBookingScreen`, `RentalBookingScreen`, `MenuScreen`)
loads `storefrontProvider(slug)`. If `bookingFlowFor(data)` is not its own flow, it calls
`context.replace(bookingEntryPath(slug, actual))` once (this protects deep links and rebook from
the wrong engine).

### 6.7 Rental pricing (`core/rental_pricing.dart`)

Copied from `apps/booking/src/engines/rental/RentalEngineApp.vue:28-31,89-91` and
`GuestCountStep.vue:15-17`. The server stores no rental price; this is the web's display estimate.

```dart
abstract final class RentalPricing {
  static const int seatsPerTable = 10, minGuests = 30, maxGuests = 1000, guestStep = 10, defaultGuests = 100;
  static const int horizonDays = 120;                       // web CalendarStep HORIZON_DAYS; booked-days default range
  static int perGuestTiyin(RentalSession s);                // morning 1500000 (15 000 so'm), evening 2500000 (25 000 so'm)
  static int tables(int guests) => (guests / seatsPerTable).ceil();
  static int totalTiyin(RentalSession s, int guests) => perGuestTiyin(s) * guests;
  static int clampGuests(int g);                            // to minGuests..maxGuests
  static String title(RentalSession s);                     // 'Ertalab' / 'Kechqurun'
  static String subtitle(RentalSession s);                  // "Kunduzgi bazm · 10:00–16:00" / "Kechki to'y · 18:00–23:00"
  static String hours(RentalSession s);                     // '10:00–16:00' / '18:00–23:00'
  /// From an appointment's business-local start/end: start 10 & end 16 -> morning; start 18 -> evening;
  /// start 10 & end 23 -> null (full day). Other -> null.
  static RentalSession? sessionOf(Appointment a, String timezone);
}
```

### 6.8 Favorites (`core/favorites.dart`)

```dart
@immutable
final class FavoritesState {
  const FavoritesState({this.ids = const {}, this.cards = const [], this.loaded = false, this.error});
  final Set<int> ids;                 // business ids that are favorites (optimistic)
  final List<BusinessCard> cards;     // for the favorites screen, newest first
  final bool loaded;                  // true after the first successful GET
  final Object? error;
  bool contains(int businessId) => ids.contains(businessId);
}

final favoritesProvider = NotifierProvider<FavoritesController, FavoritesState>(FavoritesController.new);

class FavoritesController extends Notifier<FavoritesState> {
  // build(): watches consumerIdProvider. Null -> const FavoritesState(loaded: true).
  //          Otherwise schedules refresh() and returns FavoritesState().
  Future<void> refresh();                                  // GET Endpoints.consumerFavorites -> List<BusinessCard>
  /// Optimistic. Adds (PUT Endpoints.consumerFavorite(id), 204) or removes (DELETE, 204).
  /// On error it reverts and shows errorText(e) in a snackbar. Returns the new value.
  /// Signed out: does nothing and returns false (FavoriteButton handles the login redirect).
  Future<bool> toggle(BusinessCard card);
  Future<bool> toggleById(int businessId);                 // when only the id is known (detail page); refresh() afterwards to fetch the card
}
```

`FavoriteButton` (§7) shows `state.loaded ? state.contains(id) : initial`, where `initial` is the
server's `is_favorite` from the card or detail.

### 6.9 Revisions (`core/revisions.dart`)

```dart
/// Bumped after any create/cancel/review so other features refetch without importing each other.
final bookingsRevisionProvider = NotifierProvider<RevisionController, int>(RevisionController.new);
final reviewsRevisionProvider = NotifierProvider<RevisionController, int>(RevisionController.new);
class RevisionController extends Notifier<int> { @override int build() => 0; void bump() => state++; }
```

| Who bumps | When |
|---|---|
| booking_slot, booking_rental | after a successful POST /v1/consumer/appointments |
| booking_catalog | after a successful POST /v1/consumer/orders |
| bookings | after cancel, and when a deposit turns `paid` |
| reviews | after review create, update or delete (both revisions) |

Watchers: home (next appointment, revisit), bookings (lists), profile (stats), reviews (my
reviews), business (`businessPageProvider` re-reads after a review via `reviewsRevisionProvider`).

### 6.10 Deposit (`core/deposit.dart`)

```dart
final depositServiceProvider = Provider<DepositService>((ref) => DepositService(ref));

class DepositService {
  /// POST Endpoints.paymentsDeposit, body {"appointment_id": id, "provider": "payme"},
  /// idempotencyKey: Idempotency.deposit(id) (=> 'dep-<id>-payme', stable per appointment+provider),
  /// auth: RequestAuth.none, decode: DepositCheckout.fromJson.
  /// Then opens checkoutUrl with urlOpenerProvider (external application).
  /// Throws ApiException (409 'Bu bron uchun to'lov allaqachon qilingan.' / "Bu bron uchun to'lov qilib bo'lmaydi.",
  /// 422 "Bu bron uchun oldindan to'lov talab qilinmaydi.") or DepositLaunchException when the URL cannot be opened.
  Future<DepositCheckout> startPayme(int appointmentId);
}
final class DepositLaunchException implements Exception { const DepositLaunchException(this.url); final Uri? url; }
```

Click is never offered (fixed decision; `PaymentProvider` has only `payme`).

### 6.11 Launcher (`core/launcher.dart`)

```dart
abstract interface class UrlOpener { Future<bool> open(Uri uri); }      // external application
final urlOpenerProvider = Provider<UrlOpener>((_) => const UrlLauncherOpener());

/// Precedence: mapUrl -> lat/lng 'https://yandex.uz/maps/?pt=<lng>,<lat>&z=17&l=map'
/// -> 'https://maps.google.com/?q=<name, address>' (as LocationCard.vue) -> false when nothing is known.
Future<bool> openMap(WidgetRef ref, {String? mapUrl, double? lat, double? lng, String? name, String? address});
Future<bool> callPhone(WidgetRef ref, String? phone);                   // Phone.telUri
Future<bool> openTelegram(WidgetRef ref, String username);              // https://t.me/<username without @>
```

Each returns false and shows the snackbar `Ochib bo'lmadi.` on failure. `hasMapTarget(...)`
returns whether `openMap` has anything to open, so screens can hide the button.

### 6.12 Errors, messenger, images

```dart
String errorText(Object error);   // ApiException.message; DepositLaunchException -> "To'lov sahifasini ochib bo'lmadi."; else 'Xatolik yuz berdi.'
bool isOffline(Object error);     // ApiException.isNetwork
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
void showSnack(String text); void showErrorSnack(Object error);        // via the key; no BuildContext needed
final netImagesEnabledProvider = Provider<bool>((_) => true);          // tests override false
```

### 6.13 Shared data providers (`lib/data/`)

```dart
@immutable
final class DirectoryQuery {
  const DirectoryQuery({this.q, this.category, this.engine, this.city, this.sort = 'featured', this.page = 1, this.perPage = 20});
  final String? q, category, engine, city;
  final String sort;                 // featured | rating | new | name (BP 4.4)
  final int page, perPage;
  /// {'q','category','engine','city','sort','page','per_page'}; null/blank values dropped, q trimmed.
  Map<String, Object?> toQuery();
  DirectoryQuery copyWith({...});   // sentinel pattern for nullable fields
  // ==, hashCode over every field
}

/// GET /v1/directory/categories (public). keepAlive. -> List<Category> {key,label,label_ru,engine,icon,count}
final categoriesProvider = FutureProvider<List<Category>>(...);

/// GET /v1/directory/businesses?<query> with RequestAuth.auto (a consumer token fills is_favorite).
/// -> Paged<BusinessCard> (meta page/per_page/total/pages). Watches consumerIdProvider.
final businessListProvider = FutureProvider.autoDispose.family<Paged<BusinessCard>, DirectoryQuery>(...);

/// GET /v1/directory/businesses/{slug} -> BusinessPage {business, rating, reviews_preview, is_favorite}.
/// Watches consumerIdProvider and reviewsRevisionProvider. 404 -> ApiException.isNotFound.
final businessPageProvider = FutureProvider.autoDispose.family<BusinessPage, String>(...);

/// GET /v1/site/{slug}, RequestAuth.none -> StorefrontData (engine, business, services, staff, categories, items).
/// Calls ref.keepAlive() after success so the detail page, flows, cart and checkout share one fetch;
/// pull-to-refresh calls ref.invalidate(storefrontProvider(slug)).
final storefrontProvider = FutureProvider.autoDispose.family<StorefrontData, String>(...);
```

---

## 7. Shared widgets (S0, `lib/shared/widgets/`)

Every widget is implemented, themed and documented with a dartdoc line. File per group.

| File | Widget / helper (constructor) | Behavior |
|---|---|---|
| `buttons.dart` | `CtaButton({required String label, VoidCallback? onPressed, bool loading = false, IconData? icon, bool expanded = true})` | Apricot bg, indigo label and icon, height 52, radius m; pressed apricot600; disabled = border-color bg with muted text; while `loading`, a 20 px indigo spinner and taps ignored. **The only apricot button.** |
| | `PrimaryButton({...same})` | Indigo filled (theme FilledButton). |
| | `SecondaryButton({...same})` | Indigo outlined. |
| | `DangerTextButton({required String label, VoidCallback? onPressed})` | Danger-colored text button. |
| `bottom_bar.dart` | `BottomActionBar({required Widget child, Widget? leading})` | White bar, top border, SafeArea, padding 16; for sticky CTAs. |
| `states.dart` | `LoadingView({int rows = 6, LoadingKind kind = LoadingKind.list})`; `enum LoadingKind { list, cards, detail, grid }` | Skeleton blocks (border-color boxes with a pulsing opacity animation; no package). |
| | `EmptyState({required IconData icon, required String title, String? message, String? actionLabel, VoidCallback? onAction})` | Centered; icon 48 muted in an indigo50 circle; title `titleLarge`; message `bodyMedium` muted; optional indigo `PrimaryButton`. |
| | `ErrorState({required String message, VoidCallback? onRetry})` | Icon `error_outline`; button `Qayta urinish`. |
| | `OfflineState({VoidCallback? onRetry})` | Icon `wifi_off`; title `Internet aloqasi yo'q`; message `Ulanishni tekshirib, qayta urinib ko'ring.`; button `Qayta urinish`. |
| `async_body.dart` | `AsyncBody<T>({required AsyncValue<T> value, required Widget Function(T data) builder, bool Function(T data)? isEmpty, Widget? empty, VoidCallback? onRetry, Widget? loading})` | loading (no previous value) → `loading ?? LoadingView()`; error → `OfflineState` if `isOffline(e)`, else `ErrorState(errorText(e))`; data + isEmpty → `empty`; data → builder. While refreshing with a previous value, keeps showing the data. |
| `images.dart` | `NetImage({String? url, BoxFit fit = BoxFit.cover, double? width, double? height, BorderRadius? radius, Widget? placeholder})` | `CachedNetworkImage` when `url != null && netImagesEnabledProvider`; else / on error → placeholder (indigo50 box). |
| | `BizLogo({String? url, required String name, double size = 48, String? brandColor})` | Rounded square (radius size/4); logo image, or initials (first letters of the first 2 words, uppercase, Sora 700, white) on `brandColor` parsed from '#RRGGBB' (fallback indigo). |
| | `BizCover({String? url, String? brandColor, double aspectRatio = 16 / 9, Widget? child})` | Cover image with a dark gradient overlay (black 18% to 55%, as the web `coverStyle`); without a URL, a gradient from brandColor (or indigo) to indigo700. |
| `business_cards.dart` | `BusinessCardTile({required BusinessCard card, VoidCallback? onTap, bool showFavorite = true})` | Full width: 2:1 cover (`BizCover`), the logo overlapping the bottom-left, name `titleMedium`, `categoryLabel` muted, `RatingBadge`, `district ?? address` with a muted location icon, `price_from_tiyin` as `"<Money.format> dan"`, a `Tavsiya` chip (indigo50/indigo) when `isFeatured`, an `Onlayn yozilish yopiq` muted line when `!onlineBookingEnabled`, and a `FavoriteButton` top-right on the cover. Default `onTap` = `context.push(AppRoutes.business(card.slug))`. |
| | `BusinessCardCompact({required BusinessCard card, VoidCallback? onTap, double width = 240})` | For horizontal carousels: 16:10 cover, name (1 line), rating, district. |
| `rating.dart` | `RatingStars({required double value, double size = 16})` | 5 stars (`star`, `star_half`, `star_border`), indigo / border color. |
| | `RatingBadge({required double avg, required int count, bool compact = false})` | `★ 4,7 (15)`: one decimal with a decimal comma (`avg.toStringAsFixed(1).replaceAll('.', ',')`); `count == 0` → `Yangi`. Indigo star, indigo text. |
| | `RatingSummaryView({required RatingSummary summary})` | Big avg (Sora 40/700), `RatingStars`, `"<count> ta sharh"`, then 5 rows 5..1: `"5"`, a bar (indigo on border color, `summary.share(n)`), count. |
| `review_tile.dart` | `ReviewTile({required Review review, bool showBusiness = false, VoidCallback? onEdit, VoidCallback? onDelete})` | Author (`authorName`), `RatingStars(size 14)`, age `UzDates.ago(createdAt, now: DateTime.now())`, `serviceName · staffName` muted, comment; when `hasReply`, an indigo50 box `Biznes javobi` + reply + `repliedAt` age; `showBusiness` adds the business name as the title (tap → business page); edit and delete as a trailing popup menu (`Tahrirlash`, `O'chirish`) when callbacks are given. |
| `status_chips.dart` | `AppointmentStatusChip(AppointmentStatus s)`, `OrderStatusChip(OrderStatus s)` | Pill, `labelSmall`. Colors and consumer labels below. |
| `favorite_button.dart` | `FavoriteButton({required int businessId, bool initial = false, BusinessCard? card, double size = 24, bool onImage = false})` | Heart; filled indigo when on (white-circle bg when `onImage`). Signed out → `context.push(AppRoutes.loginWith(from: <current location>))`. Signed in → `favoritesProvider.notifier.toggle(card)` or `toggleById`. Tooltip `Sevimlilarga qo'shish` / `Sevimlilardan olib tashlash`. |
| `location_card.dart` | `LocationCard({String? address, String? mapUrl, double? lat, double? lng, String? name, String? phone})` | As `apps/booking/src/components/LocationCard.vue`: **apricot** pin icon in an indigo50 circle, label `Manzil`, address, phone link; button `Xaritada ochish` (indigo outlined) via `openMap`; hidden when nothing is known. |
| `category_icon.dart` | `IconData categoryIconData(String? icon)`; `CategoryTile({required Category category, VoidCallback? onTap})` | Mapping: scissors→`content_cut`, cake→`cake_outlined`, utensils→`restaurant`, stethoscope→`medical_services_outlined`, rings→`celebration_outlined`, other→`storefront_outlined`. Tile: white card, icon in an indigo50 circle, short label (the text before `" / "`), `"<count> ta"` muted. |
| `phone_field.dart` | `PhoneField({required TextEditingController controller, String? errorText, ValueChanged<String>? onSubmitted, bool autofocus = false, bool enabled = true})` | Fixed `+998` prefix; digits only; `Phone.formatPartial` as-you-type; max 9 local digits; keyboard `phone`; label `Telefon raqam`, hint `90 123 45 67`. The controller text is the formatted local part. Callers use `Phone.normalize('998' + digits)`. |
| `section_header.dart` | `SectionHeader({required String title, String? actionLabel, VoidCallback? onAction})` | Title `titleLarge`; action `TextButton` with a chevron. |
| `login_prompt.dart` | `LoginPromptView({required String title, String? message, required String from, IconData icon = Icons.lock_outline})` | `EmptyState` look + `PrimaryButton('Kirish')` → `context.push(AppRoutes.loginWith(from: from))`. |
| `flow_widgets.dart` | `StepHeader({required int step, required int total, required String title})` | Dots (done = indigo, todo = border) + `"<step>-qadam / <total> · <title>"` muted (as the web `.steps` / `.step-count`). |
| | `BusinessMiniHeader({required String name, String? logo, String? brandColor, String? subtitle})` | 40 px `BizLogo` + name + subtitle, for flow and checkout tops. |
| | `SummaryCard({required List<SummaryRow> rows})`, `SummaryRow({required String label, required String value, bool emphasize = false})` | White card; label muted left, value indigo bold right; `emphasize` = `titleMedium` with a top divider. |
| `poller.dart` | `Poller({required Duration interval, required VoidCallback onTick, bool enabled = true, bool refreshOnResume = true, required Widget child})` | `Timer.periodic` while mounted, enabled, `TickerMode.of(context)` true and the app resumed; also calls `onTick` on `AppLifecycleState.resumed` when `refreshOnResume`. |
| `dialogs.dart` | `Future<bool> confirmDialog(BuildContext c, {required String title, String? message, String confirmLabel = 'Ha', String cancelLabel = 'Bekor qilish', bool danger = false})` | Material dialog; a danger confirm uses danger-colored text. |
| `brand.dart` | `BrandLogo`, `BrandMark` (§3.3) | |
| `../screens/placeholder_screen.dart` | `PlaceholderScreen({required String title, String? routeName, Map<String, String> params = const {}})` | AppBar title + centered `"<title> — tez orada"` + the params list (used by router tests). |
| `../screens/not_found_screen.dart` | `NotFoundScreen()` | `EmptyState(icon: search_off, title: 'Sahifa topilmadi', actionLabel: 'Bosh sahifaga', onAction: go home)`. |

Status chip colors and **consumer** labels (`status_chips.dart`):

| Appointment | Label | Colors (fg/bg) |
|---|---|---|
| pending | Kutilmoqda | warning / warningBg |
| confirmed | Tasdiqlangan | indigo / indigo50 |
| arrived | Jarayonda | indigo / indigo50 |
| completed | Yakunlandi | success / successBg |
| noShow | Kelmadi | danger / dangerBg |
| canceled | Bekor qilingan | neutral / neutralBg |
| unknown | Noma'lum | neutral / neutralBg |

| Order | Label | Colors |
|---|---|---|
| newOrder | Yangi | warning / warningBg |
| confirmed | Tasdiqlangan | indigo / indigo50 |
| preparing | Tayyorlanmoqda | indigo / indigo50 |
| ready | Tayyor | success / successBg |
| delivered | Topshirildi (no delivery exists; never "Yetkazildi" in Bizcat) | success / successBg |
| cancelled | Bekor qilingan | neutral / neutralBg |
| unknown | Noma'lum | neutral / neutralBg |

---

## 8. Placeholder screens (S0)

For each row of §5.1, S0 writes the file at the fixed path with the exact class and constructor:

```dart
// lib/features/home/home_screen.dart  (PLACEHOLDER — replaced by feature agent A2)
import 'package:material_ui/material_ui.dart';
import 'package:bizcat/shared/screens/placeholder_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderScreen(title: 'Asosiy', routeName: 'home');
}
```

A feature agent may turn the class into a `ConsumerWidget`/`ConsumerStatefulWidget`, but keeps
the name, the file path and the constructor parameters (names, types, defaults). It may add
optional parameters with defaults.

---

## 9. Feature specs

Shared conventions for every screen:
- Lists: `RefreshIndicator` (pull-to-refresh) that invalidates the screen's providers.
- States: loading = `LoadingView`; network error = `OfflineState`; other error = `ErrorState`;
  empty = `EmptyState` with the copy given below. Use `AsyncBody` where it fits.
- Mutations: the button shows `loading`; on error `showErrorSnack(e)` (or an inline field error
  for 422 with a pointer, read through `e.fieldError('<pointer>')`); on success a short snackbar.
- Page padding: horizontal `BzSpace.gutter`; cards stacked with a 12 px gap.
- Times are formatted with `UzDates` in the business timezone; `today = Dates.todayLocal(timezone: tz)`.

### 9.1 onboarding (A1)

**SplashScreen**: indigo full-screen background, centered `BrandLogo(variant: onDark, width: 168)`,
and a 2 px white `LinearProgressIndicator` (width 96) below it. No logic: the router leaves the
splash when the session is known (§5.3). If the splash is still showing after 8 s, show
`Ulanish sekin...` muted white (the restore keeps running).

**OnboardingScreen({from})**: a `PageView` with 3 pages, dots indicator, and top-right
`O'tkazib yuborish` on pages 1-2, which jumps to page 3.

| Page | Visual | Title (Sora 24/700) | Text |
|---|---|---|---|
| 1 | `BrandMark(size: 96)` | Shahringizdagi eng yaxshi joylar | Sartaroshxona, klinika, kafe va to'yxonalar bir ilovada. |
| 2 | icon `event_available` 72 in an indigo50 circle | Navbat bir necha bosishda | Qo'ng'iroqsiz yoziling, bronlaringiz doim qo'lingizda. |
| 3 | city list | Shahringizni tanlang | Keyin profilda o'zgartirishingiz mumkin. |

Page 3: radio list `kCities` + `Barcha shaharlar` (null), default = current `cityProvider` or null.
`CtaButton('Boshlash')` → `cityProvider.notifier.set(choice)`, `appPrefs.setOnboarded(true)`,
`context.go(from ?? AppRoutes.home)`. "Skip" never skips page 3's button; page 3 also has
`Keyinroq` (TextButton), which sets onboarded and keeps the city null.

**CityPickerScreen**: AppBar `Shahar`; radio list (`Barcha shaharlar` first, then `kCities`);
tapping saves at once (`cityProvider.notifier.set`) and pops (`context.pop()`, or
`context.go(AppRoutes.home)` when nothing can pop). The selected row has an indigo check.

Tests (`test/features/onboarding/`): splash renders the logo; onboarding: tap
`O'tkazib yuborish` → page 3; pick `Toshkent` → `Boshlash` → prefs `onboarded == true`,
`city == 'Toshkent'`, location `/home`. City picker: tap `Termiz` → prefs city `Termiz` and the
screen popped.

### 9.2 auth (A1)

Providers (`lib/features/auth/providers.dart`):

```dart
final loginControllerProvider = NotifierProvider.autoDispose<LoginController, LoginState>(LoginController.new);

@immutable final class LoginState {
  final bool sending; final bool verifying;
  final String? phoneError; final String? codeError; final String? error;
  final DateTime? resendAvailableAt;   // now + retry_after_sec
  final DateTime? codeExpiresAt;       // now + ttl_sec
}
class LoginController extends Notifier<LoginState> {
  /// POST Endpoints.consumerOtp, RequestAuth.none, body {"phone": "+998XXXXXXXXX"} -> OtpSent {sent, ttl_sec, retry_after_sec}.
  /// Errors: 422 pointer 'phone' -> phoneError; 429 -> error = e.message, resendAvailableAt = now + e.retryAfter;
  /// 503 "SMS yuborib bo'lmadi. Keyinroq urinib ko'ring." -> error.
  Future<bool> requestCode(String normalizedPhone);
  /// POST Endpoints.consumerVerify, RequestAuth.none, body {"phone","code"} -> ConsumerSession {token, expires_at, is_new, consumer{...}}.
  /// Success -> sessionProvider.notifier.signIn(session); returns the session.
  /// Errors: 422 pointer 'code' "Kod noto'g'ri yoki muddati o'tgan." -> codeError; 403 'Hisob bloklangan.' -> error.
  Future<ConsumerSession?> verify(String normalizedPhone, String code);
  /// PATCH Endpoints.consumerMe body {"name"} -> ConsumerUser -> session.updateConsumer.
  Future<bool> saveName(String name);
}
```

**LoginPhoneScreen({from, expired})**: AppBar back (pop, or home when nothing can pop);
`BrandMark(48)`; title `Telefon raqamingizni kiriting` (headlineSmall); text
`Tasdiqlash kodini SMS orqali yuboramiz.` muted. When `expired`: an info banner (indigo50)
`Sessiya tugadi. Qaytadan kiring.`. Then `PhoneField(autofocus: true)`.
`CtaButton('Kod olish')` is enabled when 9 digits are typed. Validation:
`Phone.isValid('998'+digits)`; otherwise `Telefon raqam noto'g'ri.`. On success →
`context.push(AppRoutes.loginCodeWith(phone: normalized, from: from))`. Footer muted text
`Davom etish orqali foydalanish shartlariga rozilik bildirasiz.`. In debug builds only
(`kDebugMode`), a muted line `Demo: 90 000 00 01 · kod 1111`.

**OtpCodeScreen({phone, from})**: title `Kodni kiriting`; text
`<Phone.format(phone)> raqamiga SMS yuborildi.` with a `O'zgartirish` TextButton (pop). One
`TextField`: digits only, maxLength 6, `autofillHints: [AutofillHints.oneTimeCode]`, letter
spacing 8, centered, Sora 28. Auto-submits at 6 digits; `CtaButton('Tasdiqlash')` is enabled at
4 or more digits (demo codes have 4). It shows `codeError` under the field and clears the field
on a wrong code. Resend: a countdown `Qayta yuborish: 0:59`, then the TextButton `Kodni qayta yuborish`
(calls `requestCode`). A muted line `Kod 2 daqiqa amal qiladi.` (from `ttl_sec`). After verify:
if `session.isNew || (session.consumer.name ?? '').isEmpty` → `context.go(AppRoutes.loginNameWith(from: from))`,
else `context.go(from ?? AppRoutes.home)`.

**LoginNameScreen({from})**: title `Ismingiz nima?`; text
`Biznes sizni shu ism bilan ko'radi.`; a TextField `Ism` (trimmed 2..64 chars, error
`Ism kamida 2 ta harf bo'lsin.`), `textCapitalization.words`; `CtaButton('Saqlash')` →
`saveName` → `context.go(from ?? AppRoutes.home)`; TextButton `O'tkazib yuborish` → same
navigation without saving.

Tests (`test/features/auth/`): the phone `12345` keeps the button disabled; `90 000 00 01` → POST
`/v1/consumer/auth/otp` recorded with body `{"phone":"+998900000001"}` and no Authorization header
→ code screen shown; enter `1111` → POST verify `{"phone":"+998900000001","code":"1111"}` →
session signed in → location = `from`. 422 code → error text visible. 429 with `Retry-After: 42`
→ the countdown starts at `0:42`. `is_new: true` → `/login/name`.

### 9.3 home (A2)

Providers (`lib/features/home/providers.dart`):

```dart
/// businessListProvider(DirectoryQuery(sort: 'featured', perPage: 10, city: ref.watch(cityProvider)))
final homeFeaturedProvider = Provider.autoDispose<AsyncValue<Paged<BusinessCard>>>(...);
/// sort 'rating', perPage 5, same city
final homeTopRatedProvider = Provider.autoDispose<AsyncValue<Paged<BusinessCard>>>(...);

/// Signed in only (null otherwise). GET Endpoints.consumerAppointments
/// query {scope: 'upcoming', page: 1, per_page: 1} -> Paged<Appointment> -> first or null.
/// Watches consumerIdProvider + bookingsRevisionProvider.
final nextAppointmentProvider = FutureProvider.autoDispose<Appointment?>(...);

@immutable final class RevisitItem {
  final BusinessRef business; final DateTime lastAt;           // appointment startsAt / order createdAt (UTC)
  final Engine engine;                                          // business.engine
  final int? serviceId; final String? serviceName; final int? staffId; final String? staffName;
  final int? orderId; final String? orderSummary;               // "Napoleon torti ×2" (first item + " va yana N")
  String rebookPath();   // via bookingFlowForEngine(engine): slot -> AppRoutes.bookSlot(slug, serviceId, staffId);
                         // rental -> bookRental(slug); catalog -> menu(slug, reorder: orderId)
}
/// Signed in only ([] otherwise). Two GETs in parallel:
///   GET consumerAppointments {scope:'past', page:1, per_page:50} -> keep status completed
///   GET consumerOrders {scope:'past', page:1, per_page:50}       -> keep status delivered
/// Group by business.id, keep the most recent, sort lastAt DESC, max 10.
/// Watches consumerIdProvider + bookingsRevisionProvider.
final revisitProvider = FutureProvider.autoDispose<List<RevisitItem>>(...);
```

**HomeScreen** (`CustomScrollView`, pull-to-refresh invalidates every provider above plus
`categoriesProvider`):
1. Top bar (not an AppBar): `BrandLogo(width: 120)` left; right: a city chip
   `<cityLabel> ▾` (icon `place_outlined`, indigo) → `context.push(AppRoutes.city)`.
2. Greeting: `Salom, <firstName>!` when signed in with a name, else `Xush kelibsiz!`
   (headlineSmall); subtitle `Bugun qayerga boramiz?` muted.
3. Search bar: a read-only rounded field, icon `search`, hint
   `Xizmat yoki biznes nomini qidiring` → `context.go(AppRoutes.exploreWith(focus: true))`.
4. Next booking card (signed in, when `nextAppointmentProvider` has a value): indigo bg, white
   text: `Yaqin bron` label, business name, `serviceName`, `UzDates.dateTime(startLocal, today)`,
   `AppointmentStatusChip`; tap → `context.push(AppRoutes.appointment(id))`. Hidden while loading
   or on error.
5. `SectionHeader('Kategoriyalar')` + a 3-column grid of `CategoryTile` from `categoriesProvider`
   (skip `count == 0` only when at least 3 remain); tap →
   `context.go(AppRoutes.exploreWith(category: c.key))`. Loading = `LoadingView(kind: grid)`;
   error = a compact inline `Qayta urinish`.
6. `SectionHeader('Siz borgan joylar')` (signed in, non-empty): a horizontal list of 260 px cards:
   `BizLogo`, business name, `serviceName` or `orderSummary`, `staffName`, `Oxirgi tashrif: <dayLabel>`;
   button (indigo outlined, small) `Qayta yozilish` (slot), `Yana bron qilish` (rental) or
   `Qayta buyurtma` (catalog) → `context.push(item.rebookPath())` (one tap; the slot flow opens
   on the date step). Tapping the card → business page.
7. `SectionHeader('Tavsiya etilgan', actionLabel: 'Hammasi' → exploreWith(sort: 'featured'))` +
   a horizontal list of `BusinessCardCompact`.
8. `SectionHeader('Eng yuqori baholangan', actionLabel: 'Hammasi' → exploreWith(sort: 'rating'))` +
   a vertical list of up to 5 `BusinessCardTile`.
9. Signed out: a card at the end: `Bronlaringizni kuzatish uchun kiring` + `PrimaryButton('Kirish')`
   → `loginWith(from: '/home')`.

Empty: when both business lists are empty → `EmptyState(icon: storefront_outlined, title: 'Bu shaharda hali bizneslar yo'q', actionLabel: 'Barcha shaharlarda ko'rish')`,
whose action sets the city to null. Offline (every request failed with a network error):
full-page `OfflineState`.

Tests (`test/features/home/`): signed out: categories and featured names render, there is no
"Siz borgan joylar"; tap a category → location `/explore?category=barber`. Signed in with
fixtures: the next-booking card shows `Shox Barber`; the revisit card button navigates to
`/b/shox-barber/book?service=11&staff=2`.

### 9.4 directory (A3)

Providers (`lib/features/directory/providers.dart`):

```dart
/// Initialised from the route params (q, category, sort) + cityProvider. autoDispose.
final directoryFilterProvider = NotifierProvider.autoDispose<DirectoryFilterController, DirectoryQuery>(DirectoryFilterController.new);
// methods: init({q, category, sort}) (called once from the screen's initState), setQuery(String q), setCategory(String? key),
//          setSort(String sort), reset()  // reset keeps city

/// Paged list over the filter. build(): page 1. loadMore(): next page appended (Paged.append); a loadMore
/// error sets moreError (the list stays). GET Endpoints.directoryBusinesses query = filter.toQuery(), per_page 20,
/// RequestAuth.auto. Watches directoryFilterProvider + consumerIdProvider.
final directoryResultsProvider = AsyncNotifierProvider.autoDispose<DirectoryResultsController, DirectoryPage>(DirectoryResultsController.new);
@immutable final class DirectoryPage { final Paged<BusinessCard> page; final bool loadingMore; final Object? moreError; }
```

**DirectoryScreen({q, category, sort, focus})**:
- AppBar with a search `TextField` (autofocus when `focus`), hint `Qidirish...`, clear button;
  input debounced 350 ms → `setQuery` (0 or 2+ chars; a single char does not search); submit adds
  it to `appPrefs.recentSearches`.
- While the field is focused and empty and recent searches exist: a chip list `So'nggi qidiruvlar`
  + `Tozalash`.
- Filter row (horizontal scroll): a city chip (`cityLabel`, icon `place_outlined`) →
  `context.push(AppRoutes.city)`; a sort chip (`sort_rounded`, label of the current sort) → a
  bottom sheet with radio items `Tavsiya etilgan` (featured), `Reyting bo'yicha` (rating),
  `Yangi qo'shilganlar` (new), `Nomi bo'yicha` (name); then category `ChoiceChip`s: `Barchasi` +
  each category (short label) from `categoriesProvider`.
- Result count line `<total> ta biznes` muted.
- List of `BusinessCardTile`; infinite scroll: `loadMore()` when within 400 px of the end and
  `page.hasMore`; footer = spinner, or a `Qayta urinish` row on `moreError`, or nothing.
- States: first load `LoadingView(kind: cards)`; empty → `EmptyState(icon: search_off, title: 'Hech narsa topilmadi', message: "Boshqa so'z yoki filtr bilan urinib ko'ring.", actionLabel: 'Filtrlarni tozalash', onAction: reset)`
  (when a city is set, a second button `Barcha shaharlarda` that sets the city to null);
  offline/error states as usual.
- The route params are read once. Later filter changes do not rewrite the URL.

Tests (`test/features/directory/`): renders 2 fixture cards; tap the `Klinika` chip → a request
with `category=clinic` recorded; sort sheet → `rating` → a request with `sort=rating`; an empty
response → `Hech narsa topilmadi`; scrolling to the end with `pages: 2` → a request with `page=2`.

### 9.5 business (A4)

Providers (`lib/features/business/providers.dart`):

```dart
// uses shared businessPageProvider(slug) and storefrontProvider(slug)

/// GET Endpoints.directoryReviews(slug) query {rating?, page, per_page: 20} (public) -> Paged<Review>,
/// summary = RatingSummary.fromMeta(meta). loadMore() appends.
final businessReviewsProvider = AsyncNotifierProvider.autoDispose.family<BusinessReviewsController, ReviewsPage, ReviewsKey>(BusinessReviewsController.new);
typedef ReviewsKey = ({String slug, int? rating});
@immutable final class ReviewsPage { final Paged<Review> page; final RatingSummary summary; final bool loadingMore; final Object? moreError; }
```

**BusinessScreen({slug, tab})**: it watches `businessPageProvider(slug)` (header and info) and
`storefrontProvider(slug)` (offerings and flow). A 404 on the page → `EmptyState(icon: storefront_outlined, title: 'Biznes topilmadi', actionLabel: 'Katalogga qaytish')`.
Layout = `NestedScrollView`:
1. `SliverAppBar` (expanded 220): `BizCover(cover, brandColor)`; actions: share is omitted;
   `FavoriteButton(onImage: true, initial: page.isFavorite, card: page.business.card)`.
2. Header block: `BizLogo(64)` overlapping the cover; name (headlineSmall); `categoryLabel` muted;
   `tagline`; a row with `RatingBadge` (tap → reviews tab) + a `Tavsiya` chip when featured.
3. Action row (4 equal indigo outlined icon+label buttons, hidden when the target is missing):
   `Qo'ng'iroq` (`call`, `callPhone(phone)`), `Xarita` (`map_outlined`, `openMap(mapUrl, lat, lng, name, address)`),
   `Telegram` (`send`, `openTelegram(telegramBotUsername)`), `Sevimli` (heart; the same toggle
   as the app-bar button).
4. Address row: **apricot** pin icon + `address` (+ `district, city` muted) + a trailing
   `Xaritada ochish` TextButton.
5. Hours row: `Bugun: 09:00–21:00` (today's weekday from `hours`; missing → `Bugun: dam olish kuni`;
   empty `hours` → row hidden); tap expands all 7 weekdays (`UzDates.weekdayLong`).
6. `TabBar` (indigo indicator) with 3 tabs in this order: `<engine.servicesTerm>` (key `offer`),
   `Sharhlar` (`reviews`), `Ma'lumot` (`info`). The initial tab comes from the `tab` param.

Offerings tab (from `storefrontProvider`, by `bookingFlowFor(data)`):
- **slot**: services `isActive && onlineBookable` as ListTiles: name, `UzDates.duration(durationMin)`,
  price `Money.format(priceTiyin)`, and when `requiresDeposit` a chip
  `Oldindan to'lov: <Money.format(depositTiyin)>`. Tap → `context.push(AppRoutes.bookSlot(slug, serviceId: s.id))`.
  Below: `SectionHeader(engine.staffTerm)` + horizontal staff avatars (`BizLogo(name)`, name,
  `specialization`) → `bookSlot(slug, staffId: m.id)`. No services →
  `Hozircha onlayn yozilish uchun xizmatlar yo'q.`.
- **rental**: two session cards (icon `wb_sunny_outlined` / `nights_stay_outlined`, `RentalPricing.title`,
  `subtitle`, `"<Money.format(perGuestTiyin)> / kishi"`), then a muted note
  `Narx taxminiy: yakuniy narx menyu va xizmatlarga qarab belgilanadi.`. Tap a card →
  `context.push(AppRoutes.bookRental(slug))`.
- **catalog**: for each category, a header + its first 3 items (56 px `NetImage`, name, price),
  then `Hammasini ko'rish (<n>)` → `context.push(AppRoutes.menu(slug))`. No items → `Menyu hali bo'sh.`.

Reviews tab: `RatingSummaryView(page.rating)`; the first 3 `ReviewTile`s from `reviewsPreview`;
`PrimaryButton('Barcha sharhlar (<count>)')` → `context.push(AppRoutes.businessReviews(slug))`;
then a muted hint `Sharhni tashrifdan keyin "Bronlarim" bo'limidan qoldirishingiz mumkin.`.
No reviews: `EmptyState(icon: rate_review_outlined, title: "Hali sharhlar yo'q")` + the hint.

Info tab: `description` (or `Ma'lumot qo'shilmagan.`); `LocationCard(...)`; phone row
(`Phone.format`); a full weekly hours table.

Bottom: `BottomActionBar` with `CtaButton(ctaLabelFor(flow, engine))` →
`context.push(bookingEntryPath(slug, flow))`. When `!storefront.business.onlineBookingEnabled`
(or the slot/rental flow has no bookable service, or the catalog has no items): instead show the
muted text `Onlayn yozilish vaqtincha yopiq` + `PrimaryButton('Qo'ng'iroq qilish')`.
While the storefront loads, the CTA is disabled with `loading`.

**BusinessReviewsScreen({slug})**: AppBar `Sharhlar`; a `RatingSummaryView(summary)` header;
filter chips `Barchasi`, `5★`, `4★`, `3★`, `2★`, `1★` (key `rating`); a paged list of
`ReviewTile`; empty for a filter → `Bu baho bilan sharhlar yo'q.`.

Tests (`test/features/business/`): renders `Shox Barber`, `★ 4,7 (15)`, the `Xizmatlar` tab
with `Soch olish + soqol` and the CTA `Navbatga yozilish`; tap `Xarita` → the fake opener
received `https://yandex.uz/maps/-/CDabc`; a catalog storefront → CTA `Buyurtma berish`;
`online_booking_enabled: false` → `Onlayn yozilish vaqtincha yopiq`; the reviews screen with
rating 5 → a request with `rating=5`.

### 9.6 booking_slot (A5)

Port of `apps/booking/src/engines/slot/SlotEngineApp.vue`, `ServiceStep.vue`, `StaffStep.vue`,
`DateTimeStep.vue`, `ConfirmStep.vue`. The web's InfoStep (name + phone) is replaced by the
account: the phone is the consumer's, and the name is editable on confirm.

Providers (`lib/features/booking_slot/providers.dart`):

```dart
enum SlotStep { service, staff, datetime, confirm }

@immutable final class SlotFlowState {
  final SlotStep step; final Service? service; final Staff? staff;
  final LocalDate date;                 // default Dates.todayLocal(timezone: tz)
  final AvailabilitySlot? slot;
  final String name; final String notes;
  final String? idempotencyKey;         // created when entering confirm; cleared when service/staff/slot change
  final bool submitting; final Object? submitError;
}

/// Family key = slug. init(storefront, {serviceId, staffId}) is called once after the storefront loads.
final slotFlowProvider = NotifierProvider.autoDispose.family<SlotFlowController, SlotFlowState, String>(SlotFlowController.new);
// pickService(s) -> staff step (auto-picks and skips to datetime when exactly 1 active staff);
// pickStaff(m) -> datetime; pickDate(d); pickSlot(slot) -> confirm (new Idempotency.newKey());
// back() -> previous step; setName/setNotes; Future<Appointment?> submit();

/// GET Endpoints.availability(staffId) query ApiQuery.availability(date: d, serviceId: id), RequestAuth.none
/// -> Availability {date, timezone, slots:[{start_utc, end_utc, start_local}]}.
final slotAvailabilityProvider = FutureProvider.autoDispose.family<Availability, ({int staffId, int serviceId, LocalDate date})>(...);
```

`init` with rebook params: a valid `serviceId` (in the bookable list) sets the service; a valid
`staffId` sets the staff; both valid → start at `datetime`; only the service → `staff`; only the
staff → `service` (the staff stays preselected and is used after the service is picked).
Invalid ids are ignored silently.

`submit()`: `api.request<Appointment>('POST', Endpoints.consumerAppointments, body: ConsumerBookingRequest.slot(staffId, serviceId, startsAt: slot.startUtc, notes: notes.trim().isEmpty ? null : notes.trim(), name: name.trim().isEmpty ? null : name.trim()).toJson(), idempotencyKey: key, decode: (d) => Appointment.fromJson(JsonRead.object(d)))`.
The wire body is `{"staff_id","service_id","starts_at":"Y-m-d H:i:s" UTC,"notes"?,"name"?}`.
201 or 200 (replay) = success → `bookingsRevisionProvider.bump()` →
`context.go(AppRoutes.appointment(appt.id, created: true))`.

Errors:
- 409 (`Tanlangan vaqt band.` / `Bu vaqt allaqachon band qilingan.`): snackbar
  `Kechirasiz, bu vaqt band bo'ldi. Iltimos, boshqa vaqtni tanlang.`; clear the slot and the key;
  go to `datetime`; `ref.invalidate(slotAvailabilityProvider(...))`.
- 403 `Bu biznesda onlayn yozilish yopiq.` and 404: show the message in the confirm alert with
  `PrimaryButton('Biznes sahifasiga')` → pop.
- 400 (past time, not bookable): alert with `e.message`; go back to `datetime` and refresh.
- Network/timeout: alert `errorText(e)` + `Qayta urinish`, which **reuses the same key**.

**SlotBookingScreen({slug, serviceId, staffId})**: AppBar `Navbatga yozilish` (back = `back()`,
or pop on the first step; `PopScope` handles system back the same way). Under it:
`BusinessMiniHeader(business)` and `StepHeader(step, 4, title)` with titles `Xizmat`,
`Mutaxassis`, `Vaqt`, `Tasdiqlash`. The storefront loads → `LoadingView(detail)`; errors as usual;
mismatch guard (§6.6).
- **Service step**: label `Xizmatni tanlang`; cards (name, duration, price, deposit chip); tap →
  pick. Empty → `EmptyState(event_busy, "Hozircha onlayn yozilish uchun xizmatlar yo'q", actionLabel: "Qo'ng'iroq qilish")`.
- **Staff step**: label `Mutaxassisni tanlang`;
  cards with `BizLogo(name)`, name, specialization; tap → pick. Empty → `Mutaxassislar topilmadi.`.
- **Datetime step**: label `Sanani tanlang`; a horizontal day strip of **14 days** from
  `today(local)`: each chip shows the top label (`Bugun`, `Ertaga`, else `UzDates.weekdayShort`),
  the day number (Sora 20) and `UzDates.monthShort`; the selected chip is indigo. Then
  `Bo'sh vaqtlar`, slots grouped by `slot.bucket` under `Ertalab` / `Kunduzi` / `Kechqurun`, as
  `Wrap` chips with `startLocal.format()`; the selected chip is indigo. Loading = 8 skeleton chips;
  empty → `Bu kunga bo'sh vaqt yo'q. Boshqa kunni tanlang.` + an outlined button `Keyingi kun`
  (date + 1, if inside the strip); error → inline `ErrorState` with retry.
- **Confirm step**: `SummaryCard` rows: `Xizmat`, `Mutaxassis`, `Sana` (`UzDates.weekdayDayMonth(date)`),
  `Vaqt` (`UzDates.timeRange(start, end)` in the business tz), `Davomiyligi`, `Narxi` (emphasize),
  plus `Oldindan to'lov` when the service requires a deposit (muted line under it:
  `Bron qilingandan so'ng Payme orqali to'lashingiz mumkin.`). Then `LocationCard(...)` from
  `storefront.business`; a TextField `Ismingiz` prefilled with `consumer.name` (validation: when
  not empty, 2..64 chars); a TextField `Izoh (ixtiyoriy)` (max 500, counter); a muted line
  `Telefon: <Phone.format(consumer.phone)>`; a submit alert area; and in the bottom bar
  `CtaButton('Band qilish', loading: submitting)`.

Tests (`test/features/booking_slot/`): with fixtures (site slot payload, availability with 3
slots), tap the service → staff → the first slot `09:00` → `Band qilish` → the recorded POST body
equals `{"staff_id":2,"service_id":11,"starts_at":"2026-10-19 04:00:00","name":"Aziza Karimova"}`
and the `Idempotency-Key` header matches the UUID v4 regex; the location becomes
`/bookings/a/5012?new=1`. A 409 response → back on the datetime step with the snackbar. Rebook
params `service=11&staff=2` → the datetime step is shown first. A catalog storefront → replaced
with `/b/<slug>/menu`.

### 9.7 booking_rental (A6)

Port of `apps/booking/src/engines/rental/RentalEngineApp.vue`, `GuestCountStep.vue`,
`CalendarStep.vue`.

Providers (`lib/features/booking_rental/providers.dart`):

```dart
enum RentalStep { session, guests, date, confirm }
@immutable final class RentalFlowState {
  final RentalStep step; final RentalSession? session; final int guests;   // default RentalPricing.defaultGuests
  final LocalDate? date; final LocalDate visibleMonth;                      // first of month; starts on today's month
  final String notes; final String? idempotencyKey; final bool submitting; final Object? submitError;
}
final rentalFlowProvider = NotifierProvider.autoDispose.family<RentalFlowController, RentalFlowState, String>(RentalFlowController.new);
// pickSession(s) -> guests; setGuests(n) (clamped on submit), submitGuests() -> date;
// pickDate(d) -> confirm (new key); prevMonth()/nextMonth(); back(); Future<Appointment?> submit(StorefrontData s)

/// GET Endpoints.siteBookedDays(slug) query ApiQuery.localDays(from: today, to: today + RentalPricing.horizonDays),
/// RequestAuth.none -> BookedDays {"booked": {"YYYY-MM-DD": ["morning","evening"]}} ({} or [] when empty).
final bookedDaysProvider = FutureProvider.autoDispose.family<BookedDays, String>(...);
```

Hall and package (web `RentalEngineApp.vue:22-25`): `hall` = the first `staff` with `isActive`
(else the first staff); `hallService` = the first service with `isActive && onlineBookable`, else
the first `isActive`, else the first. If either is missing → `EmptyState(icon: event_busy, title: "Zal resursi topilmadi. Iltimos, biznesga qo'ng'iroq qiling.", actionLabel: "Qo'ng'iroq qilish")`.

`submit()`: body `ConsumerBookingRequest.rental(staffId: hall.id, serviceId: hallService.id, date: date, session: session, guests: guests, notes: ...)`
→ wire `{"staff_id","service_id","date":"YYYY-MM-DD","session":"morning"|"evening","guests":n,"notes"?}`,
with the Idempotency-Key. 201/200 → bump bookings → `context.go(AppRoutes.appointment(id, created: true))`.

Errors:
- 409 `Bu sana allaqachon band.`: snackbar `Kechirasiz, bu sana band bo'ldi. Iltimos, boshqa sanani tanlang.`;
  clear the date and key; go to the `date` step; invalidate `bookedDaysProvider`.
- 400 `Sana bron qilish oralig'idan tashqarida.`: the same handling with that message.
- 403 / 404 / network: as in the slot flow.

**RentalBookingScreen({slug})**: AppBar `Sanani band qilish`; `BusinessMiniHeader`;
`StepHeader(n, 4)` with titles `Vaqt`, `Mehmonlar`, `Sana`, `Tasdiqlash`. Mismatch guard.
- **Session step**: label `To'y vaqtini tanlang`; 2 cards: icon (`wb_sunny_outlined` /
  `nights_stay_outlined`), `RentalPricing.title`, `subtitle`, and right-aligned
  `Money.format(perGuestTiyin)` + `/ kishi` muted; the selected card has an indigo border.
- **Guests step**: label `Nechta mehmon kutilyapti?`; a stepper `−` / numeric TextField / `+`
  (±10, `RentalPricing.minGuests..maxGuests`, clamped on blur and on continue); hint
  `30–1000 kishi · har stolga ~10 kishi`; a summary card `Stollar soni: <tables> ta stol`,
  `Bir kishiga`, `Jami taxminan` (emphasize); `PrimaryButton('Davom etish')`.
- **Date step**: a month header `‹ Oktabr 2026 ›` (capitalized `UzDates.monthFull` + year;
  prev is disabled at today's month, next at the month of `today + 120`); weekday headers
  `UzDates.weekdaysMin` (Monday first); a 7-column grid. A cell is disabled when the date is
  before today, after `today + 120`, or `bookedDays.isTaken(date, session)`. Booked cells use a
  neutral bg with strike-through number; today has an indigo outline; the selected cell is indigo
  with white text. Legend: `Bo'sh`, `Band`, `Tanlangan`. Loading = the grid at 40% opacity with a
  spinner; error → inline message + `Qayta urinish`; tap a free date → `pickDate`.
- **Confirm step**: `SummaryCard`: `Vaqt` (`<title> · <hours>`), `Sana` (`UzDates.dayMonthYear`),
  `Mehmonlar` (`<g> kishi · <tables> stol`), `Bir kishiga`, `Jami taxminan` (emphasize), plus
  `Oldindan to'lov` when `hallService.requiresDeposit`. Fineprint (web
  `RentalEngineApp.vue:257-260`): `Bron so'rovi yuboriladi, to'yxona mudiri siz bilan bog'lanadi. Yakuniy narx menyu va qo'shimcha xizmatlarga qarab o'zgarishi mumkin.`.
  `Izoh (ixtiyoriy)`; `CtaButton('Bron qilish')`.

Tests (`test/features/booking_rental/`): `Kechqurun` → guests `+` twice → `120`, `12 ta stol`,
`Jami taxminan 3 000 000 so'm`; in the calendar, a date booked for `evening` is disabled while
one booked only for `morning` is enabled; confirm → the POST body is
`{"staff_id":5,"service_id":40,"date":"<picked>","session":"evening","guests":120}` with an
Idempotency-Key; a 409 → back on the date step.

### 9.8 booking_catalog (A7)

Port of `apps/booking/src/engines/catalog/CatalogEngineApp.vue` (cart, checkout, item sheet).
There is no delivery anywhere (phase-2 rule).

Copy by engine (`lib/features/booking_catalog/copy.dart`):

| Key | catalog | medical (catalog flow) |
|---|---|---|
| menuTitle | Menyu | Xizmatlar |
| cartTitle | Savat | Tanlangan xizmatlar |
| submit | Buyurtma berish | So'rov yuborish |
| emptyCart | Savat bo'sh | Hech narsa tanlanmagan |
| pickupNote | Yetkazib berish yo'q: buyurtmani joyida olasiz. | Klinika siz bilan bog'lanib, vaqtni kelishadi. |

Providers (`lib/features/booking_catalog/providers.dart`):

```dart
@immutable final class CartLine { final Service item; final int qty; int get totalTiyin => item.priceTiyin * qty; }
@immutable final class CartState {
  final Map<int, CartLine> lines;            // insertion order kept
  int get count; int get totalTiyin; bool get isEmpty;
  List<OrderLine> toOrderLines();            // OrderLine(serviceId, qty)
}
/// keepAlive family per slug: the cart survives menu -> cart -> checkout -> login and back.
final cartProvider = NotifierProvider.family<CartController, CartState, String>(CartController.new);
// add(Service), dec(int serviceId), setQty(int serviceId, int qty) (0 removes; max 99), remove(id), clear(),
// Future<int> applyReorder(Order order, StorefrontData s)  // returns the number of skipped items

/// GET Endpoints.consumerOrder(id) -> Order (used for ?reorder=). Signed-out -> null (the reorder is skipped).
final reorderSourceProvider = FutureProvider.autoDispose.family<Order?, int>(...);

final checkoutControllerProvider = NotifierProvider.autoDispose.family<CheckoutController, CheckoutState, String>(CheckoutController.new);
@immutable final class CheckoutState { final String name; final String note; final String? idempotencyKey; final bool submitting; final Object? error; }
/// POST Endpoints.consumerOrders, Idempotency-Key (created on first open; reused on retry; replaced when the cart changes),
/// body ConsumerOrderRequest(slug, items: cart.toOrderLines(), note?, name?) -> wire {"slug","items":[{"service_id","qty"}],"note"?,"name"?}
/// -> Order. 201/200 -> cart.clear(), bookingsRevisionProvider.bump(), context.go(AppRoutes.order(id, created: true)).
// Future<Order?> submit()
```

**MenuScreen({slug, reorderOrderId})**: an AppBar with the business name; a sticky horizontal
category chip bar (one chip per `CatalogCategory`, `id 0` = `Boshqa`); the selected chip is
indigo and is synced to the scroll position (the visible section header), tap scrolls with
`Scrollable.ensureVisible`. Sections: a category header (titleLarge) + item rows: 72 px `NetImage`
(radius m), name (`titleMedium`), description (2 lines, muted), price; at the right either
`SecondaryButton('Qo'shish')` (small) or a qty stepper `− n +` when in the cart. Tap a row → item
bottom sheet: an image `PageView` (`image` first, then `gallery`, deduplicated; dots), name,
price, description, a qty stepper and `PrimaryButton("Savatga qo'shish · <Money.format(total)>")`.
Bottom (when the cart is not empty): an indigo bar `Savat · <count> ta` + total in white + a
trailing `CtaButton('Savatni ko'rish', expanded: false)` → `context.push(AppRoutes.cart(slug))`.
`reorderOrderId` → after both loads, `applyReorder` once; skipped > 0 → snackbar
`Ba'zi mahsulotlar endi mavjud emas.`. Empty menu → `EmptyState(restaurant_menu, "Menyu hali bo'sh")`.
Mismatch guard.

**CartScreen({slug})**: AppBar `copy.cartTitle`; lines (image, name, unit price, stepper,
swipe/`close` to remove); a `SummaryCard` with `Jami` (emphasize); a muted `copy.pickupNote`;
bottom `PrimaryButton('Rasmiylashtirish')` →
`context.push(AppRoutes.checkout(slug))` (the router sends signed-out users to login and back).
Empty → `EmptyState(shopping_bag_outlined, copy.emptyCart, actionLabel: 'Menyuga qaytish')`.

**CheckoutScreen({slug})**: AppBar `Rasmiylashtirish`; `BusinessMiniHeader`; a compact lines
summary (`name ×qty` and the line total) and `Jami`; a TextField `Ismingiz` (prefill, 2..64 when
not empty); a read-only row `Telefon: <Phone.format(consumer.phone)>` + the muted
`Biznes siz bilan shu raqam orqali bog'lanadi.`; a TextField `Izoh (ixtiyoriy)` (max 500) with
hint `Masalan: soat 17:00 da olib ketaman`; `copy.pickupNote`; `CtaButton(copy.submit)`. An empty
cart → `context.go(AppRoutes.menu(slug))`.

Errors: 403 `Bu biznes hozir onlayn buyurtma qabul qilmaydi.` → alert + `Qo'ng'iroq qilish`;
400 `Savat bo'sh.` / `Mahsulotlar topilmadi.` → alert, `ref.invalidate(storefrontProvider(slug))`
and drop the lines whose item is no longer in the storefront; 404 → `Biznes topilmadi.`;
network → retry with the same key.

Tests (`test/features/booking_catalog/`): add `Napoleon torti (1 kg)` twice → the bar shows
`Savat · 2 ta` and `450 000 so'm`; cart → checkout (signed in) → the POST body
`{"slug":"aziza-tortlari","items":[{"service_id":61,"qty":2}],"name":"Aziza Karimova"}` with an
Idempotency-Key → the location is `/bookings/o/702?new=1` and the cart is empty; signed out,
tapping `Rasmiylashtirish` → `/login?from=%2Fb%2Faziza-tortlari%2Fcheckout`; reorder fixture →
the cart is prefilled.

### 9.9 bookings (A8)

Providers (`lib/features/bookings/providers.dart`):

```dart
enum ApptScope { upcoming, past }      // wire 'upcoming' | 'past'
enum OrderScope { active, past }       // wire 'active' | 'past'

/// GET Endpoints.consumerAppointments query {scope, page, per_page: 20} -> Paged<Appointment> (consumer shape:
/// business{...}, staff{id,name}, service{id,name,duration_min,price_tiyin}, can_cancel, can_review, review_id).
/// loadMore(). Watches consumerIdProvider + bookingsRevisionProvider + reviewsRevisionProvider. Signed out -> empty page.
final myAppointmentsProvider = AsyncNotifierProvider.autoDispose.family<MyAppointmentsController, PagedState<Appointment>, ApptScope>(MyAppointmentsController.new);
/// GET Endpoints.consumerOrders query {scope, page, per_page: 20} -> Paged<Order> (+ business, can_cancel, can_review, review_id).
final myOrdersProvider = AsyncNotifierProvider.autoDispose.family<MyOrdersController, PagedState<Order>, OrderScope>(MyOrdersController.new);
@immutable final class PagedState<T> { final Paged<T> page; final bool loadingMore; final Object? moreError; }

/// GET Endpoints.consumerAppointment(id) -> Appointment. 404 'Bron topilmadi.'.
final appointmentDetailProvider = AsyncNotifierProvider.autoDispose.family<AppointmentDetailController, Appointment, int>(AppointmentDetailController.new);
// Future<bool> cancel({String? reason})   // POST consumerAppointmentCancel(id) body {"reason"?} -> Appointment; bump bookings
// Future<void> payDeposit()               // depositServiceProvider.startPayme(id); then awaitingPayment = true (polling)
// Future<void> refresh()                  // silent GET; when paid flips to true -> bump bookings, snackbar "To'lov qabul qilindi."
// bool awaitingPayment; DateTime? pollUntil   (kept in a small companion Notifier or in the state via a wrapper record)

/// GET Endpoints.consumerOrder(id) -> Order. cancel(): POST consumerOrderCancel(id) (no body) -> Order; bump bookings.
final orderDetailProvider = AsyncNotifierProvider.autoDispose.family<OrderDetailController, Order, int>(OrderDetailController.new);
```

**MyBookingsScreen({tab})**: signed out → `LoginPromptView(title: 'Bronlaringiz shu yerda', message: "Navbat va buyurtmalaringizni ko'rish uchun kiring.", from: '/bookings')`.
Signed in: AppBar `Bronlarim`; a top `SegmentedButton` `Bronlar` / `Buyurtmalar` (from `tab`);
inside each, a `TabBar` `Kelgusi` / `O'tgan` (appointments) or `Faol` / `Tarix` (orders). Lists
are paged with pull-to-refresh. They refresh on resume (`Poller(interval: 5 min, refreshOnResume: true)`).
- Appointment card: `BizLogo(32)` + business name; `serviceName` (`titleMedium`) +
  `staffName` muted; `UzDates.dateTime(startLocal, today)` with `event` icon; rental: the session
  title + `<guests> mehmon`; `AppointmentStatusChip`; a deposit line when `requiresDeposit` and
  the status is live: `Oldindan to'lov: <Money.format> · to'lanmagan` (warning) and when `paid`:
  `Oldindan to'lov qilingan` (success). Actions row: past + `canReview` →
  `SecondaryButton('Sharh qoldirish')` → `context.push(AppRoutes.reviewNew(appointmentId: id, businessName: name))`;
  past + `reviewId != null` → muted `Sharh qoldirilgan`; past completed →
  `SecondaryButton('Qayta yozilish')` → `bookingEntryPath(slug, bookingFlowForEngine(engine), serviceId, staffId)`.
  Tap the card → `context.push(AppRoutes.appointment(id))`.
- Order card: business; `"<first item> ×<qty>"` + ` va yana <n>`; `Money.format(totalTiyin)`;
  `UzDates.dayLabel(createdAt local)`; `OrderStatusChip`; past delivered + `canReview` →
  `Sharh qoldirish` (orderId); tap → order detail.
- Empty: upcoming `EmptyState(event_available, "Kelgusi bronlar yo'q", message: 'Katalogdan biznes tanlab, navbatga yoziling.', actionLabel: 'Katalogni ochish' → go explore)`;
  past `O'tgan bronlar yo'q`; active orders `Faol buyurtmalar yo'q`; order history `Buyurtmalar tarixi bo'sh`.

**AppointmentDetailScreen({id, justCreated})**: AppBar `Bron #<id>`.
- `justCreated`: a success hero (a check icon in a successBg circle) `Navbat band qilindi!`
  (rental: `Bron qabul qilindi!`), subtitle `UzDates.dateTime(...)`, and a muted
  `Biznes tasdiqlashi bilan holat o'zgaradi.` when pending.
- Business block (`BusinessMiniHeader`, tap → business page) + `AppointmentStatusChip`.
- `SummaryCard`: `Xizmat`, `Mutaxassis`, `Sana`, `Vaqt` (`timeRange`), rental: `Vaqt`
  (session) / `Mehmonlar` (`<g> kishi · <tables> stol`) / `Jami taxminan`
  (`RentalPricing.totalTiyin`, when a session is known); `Narxi` (`servicePriceTiyin`), `Izoh` (notes).
- Deposit callout (when `requiresDeposit` and the status is pending/confirmed): a warningBg card
  `Oldindan to'lov: <Money.format(depositTiyin)>`, text
  `Joyingizni kafolatlash uchun oldindan to'lov qiling. To'lov ixtiyoriy.`, and
  `CtaButton("Payme orqali to'lash")` → `payDeposit()`. While `awaitingPayment`: a `Poller(5 s)`
  calls `refresh()` until `paid == true` or 2 minutes pass (the text `To'lov tasdiqlanishi kutilmoqda...`
  + a spinner; after the timeout `To'lov hali tasdiqlanmadi. Keyinroq yangilang.` + `Yangilash`).
  Paid → a successBg line `Oldindan to'lov qilingan`. Never block the user on payment.
- `LocationCard(business.address, mapUrl, name, phone)` and a `PrimaryButton("Qo'ng'iroq qilish")`.
- Actions: `canCancel` → `DangerTextButton('Bronni bekor qilish')` → a bottom sheet titled
  `Bronni bekor qilish` with reason chips `Rejam o'zgardi`, `Boshqa vaqtga yozilaman`,
  `Boshqa sabab` + an optional text (max 200) + a danger button `Bekor qilish`. 409 → show
  `e.message` (`Bu bronni bekor qilib bo'lmaydi.` / the paid message). Paid and live → the info line
  `Oldindan to'lov qilingan bronni bekor qilish uchun biznes bilan bog'laning.` + call.
  `canReview` → `PrimaryButton('Sharh qoldirish')`; `reviewId` → `Sharhim` → `context.push(AppRoutes.myReviews)`.
- 404 → `EmptyState(event_busy, 'Bron topilmadi')`.
- The bottom CTA when `justCreated`: `PrimaryButton('Bronlarimga o'tish')` → `context.go(AppRoutes.bookings)`.

**OrderDetailScreen({id, justCreated})**: AppBar `Buyurtma #<id>`; `justCreated` → hero
`Buyurtmangiz qabul qilindi!` (medical: `So'rovingiz qabul qilindi!`) + `Biznes tez orada tasdiqlaydi.`.
A status progress (horizontal stepper `Yangi → Tasdiqlangan → Tayyorlanmoqda → Tayyor → Topshirildi`;
for `cancelled` a neutral `Bekor qilingan` banner instead). Lines (`name ×qty`, line total),
`Jami` emphasize, `Izoh`, the business block, `LocationCard`. An active order is polled
(`Poller(30 s)` → `refresh`). `canCancel` → `DangerTextButton('Buyurtmani bekor qilish')` →
`confirmDialog(danger)` → cancel; 409 `Buyurtmani faqat yangi holatda bekor qilish mumkin.`.
`canReview` → `Sharh qoldirish`; delivered → `SecondaryButton('Qayta buyurtma')` →
`context.push(AppRoutes.menu(slug, reorder: id))`.

Tests (`test/features/bookings/`): signed out → `Kirish` prompt; the upcoming fixture → the
`Shox Barber` card with `Tasdiqlangan`; tab `O'tgan` → a request `scope=past`, and the
`Sharh qoldirish` button navigates to `/review/new?appointment=4990&bname=Shox+Barber`. Detail
with `paid: false, deposit_tiyin: 2000000` → tap `Payme orqali to'lash` → a recorded POST
`/v1/payments/deposit` with body `{"appointment_id":5012,"provider":"payme"}`, header
`Idempotency-Key: dep-5012-payme` and no Authorization; the fake opener got
`https://checkout.paycom.uz/...`. Cancel → POST `/v1/consumer/appointments/5012/cancel` with
`{"reason":"Rejam o'zgardi"}` and the chip becomes `Bekor qilingan`. Order cancel → POST
`/v1/consumer/orders/702/cancel`.

### 9.10 favorites (A9)

Uses `favoritesProvider` (§6.8) only. No own API provider.

**FavoritesScreen**: signed out → `LoginPromptView(title: 'Sevimli joylaringiz', message: "Yoqqan bizneslarni yurakcha bilan saqlang.", from: '/favorites')`.
Signed in: AppBar `Sevimlilar`; `!loaded` → `LoadingView(cards)`; `error` and no cards →
`OfflineState` / `ErrorState` (retry = `refresh()`); the cards list (`state.cards` filtered by
`state.ids`) as `BusinessCardTile` (its heart toggles and the card disappears at once;
`showSnack("Sevimlilardan olib tashlandi")`); pull-to-refresh → `refresh()`. Empty →
`EmptyState(favorite_border, "Sevimlilar ro'yxati bo'sh", message: 'Biznes sahifasidagi yurakchani bosing.', actionLabel: 'Katalogni ochish')`.

Tests: the fixture with 2 cards renders both; tap the heart on the first → a DELETE
`/v1/consumer/favorites/2` recorded and the card removed; signed out → the prompt.

### 9.11 loyalty (A9)

```dart
/// GET Endpoints.consumerLoyalty -> List<LoyaltyWalletEntry>
/// {business{id,slug,name,logo,brand_color}, client_id, points, cashback_tiyin, deposit_balance_tiyin, visits}.
/// Watches consumerIdProvider + bookingsRevisionProvider.
final loyaltyWalletProvider = FutureProvider.autoDispose<List<LoyaltyWalletEntry>>(...);
```

**LoyaltyWalletScreen**: AppBar `Hamyon`. Header card (indigo bg, white text): `Jami keshbek`
= `Money.format(sum of cashbackTiyin)`, `Jami ballar: <sum points>`. A muted note
`Bonuslardan foydalanish uchun biznesda telefon raqamingizni ayting.`. Entry cards: a 4 px left
stripe in `brandColor` (or indigo), `BizLogo(40)`, business name, a 3-column metric row
`Ballar` (points), `Keshbek` (`Money.format`), `Tashriflar` (visits); a muted
`Depozit balansi: <Money.format>` line when `depositBalanceTiyin > 0`; tap →
`context.push(AppRoutes.business(slug))`. Empty → `EmptyState(account_balance_wallet_outlined, "Hali bonuslar yo'q", message: "Bizcat orqali yoziling va keshbek to'plang.")`.

Tests: the fixture shows `Shox Barber`, `120`, `15 000 so'm`; an empty list → the empty state.

### 9.12 profile (A9)

```dart
/// GET Endpoints.consumerMe -> ConsumerUser (with stats). On success also session.updateConsumer(user).
/// Watches consumerIdProvider + bookingsRevisionProvider + reviewsRevisionProvider.
final profileProvider = FutureProvider.autoDispose<ConsumerUser>(...);

final profileEditControllerProvider = NotifierProvider.autoDispose<ProfileEditController, ProfileEditState>(ProfileEditController.new);
/// PATCH Endpoints.consumerMe with ConsumerProfilePatch containing ONLY changed fields
/// ({"name","birthday":"Y-m-d","gender":"male|female","city","locale"}) -> ConsumerUser -> session.updateConsumer.
/// 422 pointers name/birthday/gender/locale -> fieldErrors.
// Future<bool> save()

/// DELETE Endpoints.consumerMe -> 204 -> session.signOut(reason: deleted).
Future<void> deleteAccount(WidgetRef ref);
```

**ProfileScreen**: signed out → `LoginPromptView(title: 'Profil', message: 'Bronlar, sevimlilar va bonuslar uchun kiring.', from: '/profile')`
+ below it the app section (city, version). Signed in:
1. Header: an avatar circle (indigo bg, white initials of `displayName`), `displayName`
   (headlineSmall), `Phone.format(phone)` muted; `IconButton(edit)` → `context.push(AppRoutes.profileEdit)`.
2. Stats row (3 tiles from `stats`): `Bronlar` (`appointmentsTotal`), `Sharhlar` (`reviewsTotal`),
   `Sevimlilar` (`favoritesTotal`); taps → the bookings tab / my reviews / the favorites tab.
3. List: `Hamyon` (`account_balance_wallet_outlined`) → wallet; `Sharhlarim` (`rate_review_outlined`)
   → my reviews; `Shahar` with the trailing `cityLabel` → `/city`; `Til` with the trailing
   `O'zbekcha` (disabled; subtitle `Ruscha tez orada`); `Biznesingizni ulang` (`storefront_outlined`)
   → open `https://tizbiz.uz/register`; `Ilova haqida` → `showAboutDialog` (Bizcat, version from
   pubspec `0.1.0`, `TizBiz ekotizimi`).
4. `SecondaryButton('Chiqish')` → `confirmDialog(title: 'Hisobdan chiqasizmi?')` → `signOut()`
   → `context.go(AppRoutes.home)`.
5. `DangerTextButton("Hisobni o'chirish")` → a dialog `Hisobni o'chirish` with the text
   `Profilingiz o'chiriladi, sharhlaringiz anonim bo'lib qoladi. Bizneslardagi bron tarixi o'chmaydi. Bu amalni ortga qaytarib bo'lmaydi.`,
   a checkbox `Tushundim`, and a danger button `O'chirish` (enabled only when checked) →
   `deleteAccount` → snackbar `Hisobingiz o'chirildi.` → `context.go(AppRoutes.home)`.

**ProfileEditScreen**: AppBar `Ma'lumotlarim`; fields: `Ism` (required, 2..64), `Tug'ilgan kun`
(a read-only field that opens `showDatePicker` with locale uz, range 1930..today-10y; a clear icon),
`Jins` (`SegmentedButton` `Erkak` / `Ayol`, can be unset), `Shahar` (dropdown `kCities` + empty),
and `Telefon` read-only with the hint `Telefon raqamni o'zgartirib bo'lmaydi.`. The bottom
`PrimaryButton('Saqlash')` is enabled when something changed → `save()` → snackbar `Saqlandi.`
→ pop.

Tests: shows `Aziza Karimova` and `+998 90 000 00 01`; edit the name to `Aziza K.` → PATCH
body `{"name":"Aziza K."}` only; `Chiqish` → confirm → session signed out and the location
`/home`; delete → checkbox → `O'chirish` → DELETE `/v1/consumer/me` recorded.

### 9.13 reviews (A10)

```dart
/// GET Endpoints.consumerReviews -> List<Review> (mine: + business{id,slug,name,logo}, appointment_id, order_id, status).
/// Watches consumerIdProvider + reviewsRevisionProvider.
final myReviewsProvider = FutureProvider.autoDispose<List<Review>>(...);

final reviewComposeProvider = NotifierProvider.autoDispose.family<ReviewComposeController, ReviewComposeState, ReviewTarget>(ReviewComposeController.new);
typedef ReviewTarget = ({int? appointmentId, int? orderId, int? reviewId});
@immutable final class ReviewComposeState { final int rating /*0 = none*/; final String comment; final bool submitting; final String? ratingError; final String? commentError; final Object? error; final Review? existing; }
// build(): in edit mode it reads myReviewsProvider and seeds rating/comment from the review with reviewId (missing -> error 404).
/// create: POST Endpoints.consumerReviews body ReviewInput(appointmentId|orderId, rating, comment?) -> wire {"appointment_id"|"order_id","rating","comment"?} -> Review (201).
/// edit:   PATCH Endpoints.consumerReview(id) body ReviewInput.toPatchJson() -> {"rating","comment"} -> Review.
/// delete: DELETE Endpoints.consumerReview(id) -> 204.
/// After each: bookingsRevisionProvider.bump() + reviewsRevisionProvider.bump().
/// Errors: 409 "Bu tashrif uchun sharh allaqachon qoldirilgan." / "Faqat yakunlangan tashrif uchun sharh qoldirish mumkin."
///         -> error text + pop button; 422 pointers rating/comment -> field errors; 404 -> not found.
// Future<bool> submit(); Future<bool> delete();
```

**ReviewComposeScreen({appointmentId, orderId, reviewId, businessName})**: AppBar
`Sharh qoldirish` (edit: `Sharhni tahrirlash`); a title `<businessName> qanday bo'ldi?`
(fallback `Tashrifingiz qanday bo'ldi?`); 5 large indigo star buttons (44 px, `Semantics` label
`<n> yulduz`) with the caption under them: 1 `Yomon`, 2 `Qoniqarsiz`, 3 `O'rtacha`, 4 `Yaxshi`,
5 `A'lo`; a TextField `Fikringiz (ixtiyoriy)` (multi-line 5, max 1000, counter) with the hint
`Xizmat, usta, muhit haqida yozing`. Validation: rating 1..5 required, otherwise
`Baho tanlang.`; comment max 1000. `CtaButton('Yuborish')` (edit: `Saqlash`) → snackbar
`Rahmat! Sharhingiz qabul qilindi.` → `context.pop()` (or `go(AppRoutes.bookings)` when nothing
can pop). Edit mode also shows `DangerTextButton("Sharhni o'chirish")` → `confirmDialog(danger)` →
delete → `O'chirildi.` → pop.

**MyReviewsScreen**: AppBar `Sharhlarim`; `ReviewTile(showBusiness: true, onEdit: → context.push(AppRoutes.reviewEdit(id)), onDelete: → confirm → delete)`
(`hidden` reviews get a muted badge `Yashirilgan`); empty → `EmptyState(rate_review_outlined, "Hali sharh qoldirmagansiz", message: "Yakunlangan tashriflaringizni \"Bronlarim\" bo'limida baholang.")`.

Tests: submit without a rating → `Baho tanlang.` and no request; 5 stars + text → POST body
`{"appointment_id":4990,"rating":5,"comment":"Juda yoqdi!"}`; edit mode prefills from the mine
fixture and PATCHes `{"rating":4,"comment":"..."}`; my reviews renders the business name and the
reply box `Biznes javobi`.

---

## 10. Copy rules and shared phrases

- Sentence case, polite `siz` forms; short buttons (1-3 words).
- Common phrases (use exactly): `Qayta urinish`, `Bekor qilish`, `Saqlash`, `Davom etish`,
  `Orqaga`, `Kirish`, `Chiqish`, `Hammasi`, `Yuklanmoqda...`, `Saqlandi.`,
  `Internet aloqasi yo'q`, `Xatolik yuz berdi.`.
- Server error texts (`ApiException.message`) are already Uzbek. Show them as they are; do not
  re-translate them.
- Numbers: `Money.format` for money; counts as `<n> ta`; ratings with a decimal comma.
- Dates: `UzDates.dayLabel` / `dateTime` (`Bugun, 10:00`, `Ertaga, 09:30`, `20 oktabr, 18:00`).

---

## 11. Navigation and state rules (summary)

| Situation | Behavior |
|---|---|
| Cold start | `/splash` until `restore()` finishes → onboarding (first run) → `from ?? /home` |
| A signed-out user opens a required route | `/login?from=<route>`; after verify (and the optional name step) → `context.go(from)` |
| A signed-out user taps a heart / "Sharh qoldirish" / checkout | `context.push(loginWith(from: current))` |
| 401 on any consumer call | token cleared → signed out (expired) → the snackbar → on a required route redirect to login with `expired=1` (§6.2) |
| Flow finished (booking/order) | `context.go(appointment/order(id, created: true))` (the stack is replaced) |
| A flow gets the wrong engine | `context.replace(bookingEntryPath(actual))` |
| System back inside a multi-step flow | the previous step (`PopScope`), then pop |
| Tapping the active tab again | pops to the tab root |
| App resumed | Session `refreshProfile()` when stale; `Poller`s with `refreshOnResume` refetch |

Polling summary: bookings lists on resume; appointment detail every 5 s for up to 2 min only
after "Payme orqali to'lash"; an active order's detail every 30 s while visible. No other
background polling.

---

## 12. Assets

| Asset | Used in |
|---|---|
| `assets/brand/bizcat-logo-on-dark.svg` | Splash (indigo bg) |
| `assets/brand/bizcat-logo-on-light.svg` | Home top bar, About dialog |
| `assets/brand/bizcat-mark.svg` | Onboarding page 1, login header, loading accents |
| `assets/brand/bizcat-favicon.svg` | Any mark below 32 px |
| `assets/brand/png/bizcat-app-icon-1024.png` | Launcher icons (flutter_launcher_icons) |
| `assets/brand/png/bizcat-app-icon-192.png`, `-512.png`, `bizcat-favicon-48.png` | Web manifest icons and favicon |

Network images (logos, covers, item photos) come from API URLs and go through
`NetImage`/`BizLogo`/`BizCover`. No other bundled images; empty states use Material icons.

---

## 13. Tests

### 13.1 Test support (S0, `test/support/`)

- `fake_api.dart`:
  ```dart
  final class FakeApi {
    /// Registers a response. `path` is matched exactly (no query); `when` filters on the query map.
    void on(String method, String path, {int status = 200, Object? body, Map<String, String> headers = const {}, bool Function(Map<String, String> query)? when});
    List<RecordedRequest> get requests;   // method, path, query, headers (lower-case), json body
    RecordedRequest last(String method, String path);
    ApiClient client({String? token});    // ApiClient(config: ApiConfig(baseUrl: 'https://api.test'), tokenKind: TokenKind.consumer,
                                          //   tokenStore: InMemoryTokenStore(token), dio: Dio()..httpClientAdapter = _adapter)
  }
  String fakeConsumerToken({int sub = 17, Duration ttl = const Duration(days: 30)});   // unsigned JWT with typ 'consumer'
  ```
  An unmatched request answers 404 `{"errors":[{"status":"404","title":"Not Found","detail":"Topilmadi."}]}`
  and is recorded, so tests can assert on it.
- `fake_opener.dart`: `FakeUrlOpener implements UrlOpener` records the opened `Uri`s and returns true.
- `fixtures.dart`: `abstract final class Fx` with `const Map<String, dynamic>` JSON copied
  **verbatim** from BP §4 (consumer `me`, `verify`, `otp`, directory `categories` with all 5 keys,
  a list of 2 cards (shox-barber, aziza-tortlari), a `detail` for shox-barber, a `reviews` page with
  meta, consumer appointments upcoming (id 5012) + past completed reviewable (id 4990, `can_review: true`),
  an unpaid appointment (`paid: false`, `deposit_tiyin: 2000000`), orders (702 `new`, a delivered
  one with `can_review: true`), `loyalty`, mine reviews, `deposit`), plus storefront payloads:
  `siteSlot` (shox-barber: service 11 `Soch olish + soqol` 40 min 8 000 000 tiyin with a deposit of
  2 000 000; staff 2 `Usta Jahongir`), `siteCatalog` (aziza-tortlari: category `Tortlar` with
  item 61 `Napoleon torti (1 kg)` 22 500 000 tiyin), `siteRental` (serenada: staff 5, service 40),
  `siteMedical` (catalog shape, engine medical), `availability` (2026-10-19, slots 04:00Z/09:00,
  05:00Z/10:00, 13:00Z/18:00), `bookedDays` (one day both sessions, one evening only, one morning only).
- `pump.dart`:
  ```dart
  /// Pumps the full app (router included) at [location].
  /// - SharedPreferences.setMockInitialValues({'bizcat.onboarded': true, ...prefs})
  /// - apiProvider -> fake.client(token: signedIn ? fakeConsumerToken() : null)
  /// - default fakes: GET /v1/consumer/me -> Fx.me (when signed in), /v1/directory/categories, /v1/consumer/favorites -> [] ...
  /// - urlOpenerProvider -> FakeUrlOpener, netImagesEnabledProvider -> false
  /// - ProviderScope(retry: (_, __) => null), BizcatApp(googleFonts: false)
  /// Then pumpAndSettle until the session is known (the splash is gone).
  Future<TestHarness> pumpBizcat(WidgetTester t, {String location = '/home', bool signedIn = false,
      Map<String, Object> prefs = const {}, void Function(FakeApi api)? setup, List<Override> overrides = const []});
  final class TestHarness { final FakeApi api; final FakeUrlOpener opener; final ProviderContainer container; GoRouter get router; String get location; }
  ```
  The `Override` type comes from `flutter_riverpod` (Riverpod 3 exports it; if it is not exported
  under that name, use the type `ProviderScope.overrides` accepts).

### 13.2 S0 tests (`test/app/`)

- `router_test.dart`: `routeRequiresAuth` table (every row of §5.1); every route path in §5.1
  pumps its placeholder (title visible); signed out `/profile/wallet` → `/login?from=%2Fprofile%2Fwallet`;
  signed in `/login` → `/home`; first run (`onboarded` false) cold start → `/onboarding`; `/b/x/book`
  deep link with a valid session → stays on it after the splash; a bad id `/bookings/a/abc` →
  `Sahifa topilmadi`.
- `session_test.dart`: restore with no token → signed out; with a token + `me` 200 → signed in;
  `me` 401 → signed out with reason expired and the token store cleared; a network error with a
  cached profile → signed in `stale: true`; on `/profile/wallet`, a 401 from any request →
  redirect to `/login?...&expired=1`.
- `favorites_test.dart`: toggle on → PUT recorded and ids contains it; a PUT that returns 500 →
  reverted plus a snackbar.
- `theme_test.dart`: `AppTheme.light().colorScheme.primary == BzColors.indigo`; the default
  `FilledButton` background is indigo (not apricot); a `CtaButton` renders with an apricot
  background and an indigo label.
- `shared_widgets_test.dart`: `RatingBadge(avg: 4.73, count: 15)` → `4,7 (15)`; count 0 → `Yangi`;
  `OrderStatusChip(delivered)` → `Topshirildi`; `LocationCard` → `Xaritada ochish` opens `mapUrl`.

### 13.3 Feature tests

Money in test expectations: build the expected string with `Money.format(...)` (or write the
U+00A0 no-break spaces explicitly). `Money.format` groups with NBSP, so a literal typed with plain
spaces, such as the readable `450 000 so'm` used in this spec, never matches `find.text`.

Each feature agent writes `test/features/<feature>/*_test.dart`, with **at least one smoke test
per screen** it owns (render with fixtures, no exceptions, key texts visible) plus the behavior
tests listed in its §9 section. Tests use `pumpBizcat` and `FakeApi`. They never hit the network
and never sleep in real time (use `tester.pump(Duration)` for debounces and pollers).

### 13.4 Commands and done criteria

Each feature agent, from `bizcat/`:
```bash
~/development/flutter/bin/flutter analyze lib/features/<feature> test/features/<feature>
~/development/flutter/bin/flutter test test/features/<feature>
grep -rn "features/" lib/features/<feature> | grep import | grep -v "features/<feature>/"   # must be empty
grep -rn "apricot" lib/features/<feature>   # must be empty: use CtaButton / the LocationCard pin only
grep -rn "package:flutter/material.dart" lib/features/<feature> test/features/<feature>   # must be empty (hard rule 9)
```
Agents work in parallel in one project: **do not run** `flutter pub get`, `flutter clean` or
`flutter build` (S0 and the orchestrator do). If `flutter test` reports a lock on `.dart_tool`,
retry after a few seconds.

S0 done: `flutter pub get`, `flutter analyze` (0 issues), `flutter test` (green, including
§13.2), and `flutter build web --release --dart-define=API_BASE=http://127.0.0.1:8899` all
succeed; every route opens its placeholder; `grep -rn "package:flutter/material.dart" lib test`
is empty.

Orchestrator done (after all agents): `flutter analyze` 0 issues, all tests green,
`flutter build web` succeeds, and a manual run against the local API with
`+998900000001`/`1111` covers home → business → slot booking → Payme URL opened → bookings →
review; aziza-tortlari order; serenada rental (`+998900000002`).

---

## 14. Feature ownership

S0 runs first and alone. When S0 is done (§13.4), A1-A10 run **in parallel**. Every agent owns
only the paths listed; the test folder `test/features/<feature>/` belongs to the same agent.

| Agent | Feature id(s) | Folder(s) | Files it must deliver (fixed paths, beyond any helpers inside the folder) | Depends on (read-only) |
|---|---|---|---|---|
| **S0** skeleton | app, core, data, theme, shared, placeholders, test support | `pubspec.yaml`, `analysis_options.yaml`, `README.md`, `android/`, `ios/`, `web/`, `assets/`, `lib/main.dart`, `lib/app/**`, `lib/core/**`, `lib/data/**`, `lib/theme/**`, `lib/shared/**`, the 24 placeholder files of §5.1 (rows 24 and 25 share one file), `test/support/**`, `test/app/**` | everything in §2-§8, §13.1-§13.2 | `mobile/tizbiz_core` (must already pass its own tests) |
| **A1** | onboarding, auth | `lib/features/onboarding/`, `lib/features/auth/` | `splash_screen.dart`, `onboarding_screen.dart`, `city_picker_screen.dart`; `login_phone_screen.dart`, `otp_code_screen.dart`, `login_name_screen.dart`, `providers.dart` | session, prefs, city, PhoneField, CtaButton |
| **A2** | home | `lib/features/home/` | `home_screen.dart`, `providers.dart` | businessListProvider, categoriesProvider, cityProvider, revisions, booking_flow |
| **A3** | directory | `lib/features/directory/` | `directory_screen.dart`, `providers.dart` | DirectoryQuery, categoriesProvider, cityProvider, prefs, BusinessCardTile |
| **A4** | business | `lib/features/business/` | `business_screen.dart`, `business_reviews_screen.dart`, `providers.dart` | businessPageProvider, storefrontProvider, booking_flow, rental_pricing, launcher, favorites, rating widgets |
| **A5** | booking_slot | `lib/features/booking_slot/` | `slot_booking_screen.dart`, `providers.dart` | storefrontProvider, booking_flow, revisions, flow widgets |
| **A6** | booking_rental | `lib/features/booking_rental/` | `rental_booking_screen.dart`, `providers.dart` | storefrontProvider, rental_pricing, booking_flow, revisions, flow widgets |
| **A7** | booking_catalog | `lib/features/booking_catalog/` | `menu_screen.dart`, `cart_screen.dart`, `checkout_screen.dart`, `providers.dart`, `copy.dart` | storefrontProvider, booking_flow, revisions, flow widgets |
| **A8** | bookings | `lib/features/bookings/` | `my_bookings_screen.dart`, `appointment_detail_screen.dart`, `order_detail_screen.dart`, `providers.dart` | deposit, revisions, rental_pricing, booking_flow, status chips, Poller, LocationCard |
| **A9** | favorites, loyalty, profile | `lib/features/favorites/`, `lib/features/loyalty/`, `lib/features/profile/` | `favorites_screen.dart`; `loyalty_wallet_screen.dart`, `providers.dart`; `profile_screen.dart`, `profile_edit_screen.dart`, `providers.dart` | favoritesProvider, session, city, revisions |
| **A10** | reviews | `lib/features/reviews/` | `review_compose_screen.dart`, `my_reviews_screen.dart`, `providers.dart` | revisions, ReviewTile, session |

Sizing: each feature agent owns 1-3 screens and one provider file. The largest are A4 (business
detail) and A7 (three catalog screens).

Escalation: a missing shared widget, provider, model field or endpoint is **not** added inside a
feature (no copies of shared code, no new packages). The agent writes the smallest local
workaround inside its folder, marks it `// TODO(S0): move to shared` and lists it in its final
report.

---

## 15. Known limitations (accepted for this iteration)

1. **Rental price** is the web's client-side estimate (15 000 / 25 000 so'm per guest). The server
   stores no rental total (critic: missing #1). The UI labels it `taxminan`.
2. **Medical** uses the catalog cart flow until its storefront payload exposes staff (§1).
3. **No push**: status changes show up on pull-to-refresh, on resume, and via the short polls of §11.
4. **Payme return**: the checkout URL has no return/deep-link param, so the user switches back
   manually. The 5 s poll plus refresh-on-resume picks up `paid`.
5. **Production API**: the consumer, directory and rental endpoints exist only after the
   orchestrator deploys BP and runs migrations; until then use the local API.
6. **Cities** are a fixed list (`Toshkent`, `Termiz`). The directory has no city-list endpoint.
7. **Russian UI** is not shipped (`locale` is stored, the strings are Uzbek only).
