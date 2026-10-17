# TizBiz Biznes (`mobile-app/`)

Flutter app for business owners, administrators and staff (`uz.tizbiz.biznes`). One app, two
shells: the **manager shell** (`business_owner`, `business_admin`) mirrors the web cabinet
`apps/admin`; the **staff shell** (`staff`) shows the member's own work through `/v1/me/*`.

Source of truth: `docs/mobile/BIZNES-SPEC.md` (this app), `docs/mobile/CORE-SPEC.md` (the shared
`mobile/tizbiz_core` package) and `docs/mobile/BACKEND-PLAN.md` (the API contract).

## Toolchain

Flutter 3.47.7 / Dart 3.13.5 (`~/development/flutter/bin`). The UI uses **only**
`package:material_ui/material_ui.dart` (go_router 18 and cached_network_image 4 are built on it);
never import `package:flutter/material.dart` in `lib/` or `test/`.

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
cd mobile-app
flutter pub get
flutter analyze            # must report: No issues found!
flutter test               # all green, never touches the network
flutter build web --release --dart-define=API_BASE=https://api.tizbiz.uz
```

No Android SDK or Xcode on the dev machine: the platform folders are generated and configured, but
only `flutter build web` is verified locally.

## Run against the local API

```bash
# from the repo root
php -S 127.0.0.1:8899 -t api/web api/web/router.php
# from mobile-app/
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8899 --dart-define=DEMO_LOGINS=true
```

| dart-define | Default | Use |
|---|---|---|
| `API_BASE` | `https://api.tizbiz.uz` | read only through `ApiConfig.fromEnvironment()` |
| `DEMO_LOGINS` | `false` | `true` shows demo login chips (also shown in debug builds) |

With prod `APP_ORIGINS` set, Flutter web served from another origin is blocked by CORS (native
builds are unaffected).

## Demo credentials (BACKEND-PLAN §6.3)

Password `secret123` for every login. Slugs: prod first, local in brackets. Staff rows exist only
after `php yii seed-staff`.

| Business | Engine | Role | Phone |
|---|---|---|---|
| shox-barber [barber] | slot | owner | +998901111111 |
| shox-barber [barber] | slot | staff | +998931110001, +998931110002 |
| aziza-tortlari [tort] | catalog | owner | +998902222222 |
| aziza-tortlari [tort] | catalog | staff | +998932220001 |
| restoran [restoran] | catalog | owner | +998905555555 |
| sanatrix [klinika] | medical | owner | +998903333333 |
| sanatrix [klinika] | medical | staff | +998933330001, +998933330002 |
| serenada [ijara] | rental | owner | +998904444444 |
| serenada [ijara] | rental | staff | +998934440001 |

## Layout and ownership

```
lib/
  main.dart                 S  bootstrap (prefs, ProviderScope, retry off)
  app/                      S  TizbizApp, Routes, routerProvider, computeRedirect, shells, Ko'proq, theme
  core/                     S  Env, clockProvider, prefsProvider, SecureTokenStore, apiClientProvider,
                               SessionNotifier/sessionProvider, ActiveBusiness/activeBusinessProvider, themeModeProvider
  shared/                   S  revisions, shared data providers, format helpers, polling, widgets
  features/<feature>/       F  one folder per feature (auth, dashboard, timetable, appointments, orders,
                               clients, catalog, staff_admin, money, reviews, settings, team, me_day, me)
test/
  support/                  S  test_app.dart (pumpScreen, pumpRouterAt), fake_session.dart, fake_http.dart, fixtures.dart
  app/ core/ shared/        S  skeleton tests
  features/<feature>/       F  feature tests
```

`S` = skeleton (owned centrally), `F` = the feature agent owning that folder.

Rules for feature work (BIZNES-SPEC §14):

1. Edit only `lib/features/<feature>/` and `test/features/<feature>/`. Keep every screen's class
   name, file path and constructor (BIZNES-SPEC §6.2); `StatelessWidget` may become
   `ConsumerWidget` / `ConsumerStatefulWidget`.
2. A feature imports only `package:tizbiz_core/tizbiz_core.dart`, `package:tizbiz_biznes/core/...`,
   `package:tizbiz_biznes/shared/...`, `package:tizbiz_biznes/app/routes.dart` and
   `package:tizbiz_biznes/app/theme/...`. A feature never imports another feature.
3. Paths come from `Endpoints`, ranges from `ApiQuery`, models from the core. No hand-written
   `/v1/` path in `lib/`.
4. Navigate only with `Routes.*`; refresh other features' data only by bumping the revision
   providers (`lib/shared/data/revisions.dart`).
5. Every tenant data provider calls `requireActive(ref)` first.
6. Before finishing: `flutter analyze` (zero issues), `flutter test` (all green),
   `grep -rn "package:flutter/material.dart" lib test` empty, `grep -rn "'/v1/" lib` empty.
