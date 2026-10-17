# Bizcat

Bizcat is the consumer app of the TizBiz platform: a city business catalog with booking, ordering,
favorites, loyalty and reviews. It is a Flutter app (`uz.tizbiz.bizcat`) for Android, iOS and web.

- Spec: `docs/mobile/BIZCAT-SPEC.md` (source of truth); API: `docs/mobile/BACKEND-PLAN.md`.
- Shared Dart core (models, ApiClient, Money, Phone, Dates): `../mobile/tizbiz_core`.
- Brand originals: `bizcat-brand/` (do not edit). The copies the app uses are in `assets/brand/`.

## Run

Toolchain: Flutter 3.47.7 / Dart 3.13.5 (`~/development/flutter/bin`).

```bash
# local API (from the repo root): php -S 127.0.0.1:8899 -t api/web api/web/router.php
cd bizcat
flutter pub get
flutter run -d chrome --web-port 5180 --dart-define=API_BASE=http://127.0.0.1:8899
```

`API_BASE` defaults to `https://api.tizbiz.uz`. Production gets the consumer, directory and rental
endpoints only after the backend plan is deployed, so develop against the local API.

## Verify

```bash
flutter analyze                 # 0 issues
flutter test                    # all green
flutter build web --release --dart-define=API_BASE=http://127.0.0.1:8899
grep -rn "package:flutter/material.dart" lib test   # must be empty
```

There is no Android SDK or Xcode on the dev machine, so only the web build is verified there.

## Demo logins

OTP code `1111`; no SMS is sent for these phones.

| Phone | Data |
|---|---|
| `+998 90 000 00 01` | rich data (bookings, orders, reviews, loyalty) |
| `+998 90 000 00 02` | rental booking |
| `+998 90 000 00 03` | empty account |

## Layout

| Path | Owner | What |
|---|---|---|
| `lib/main.dart`, `lib/app/` | S0 | `BizcatApp`, `routerProvider` (routes, redirects), `AppRoutes`, `MainShell` |
| `lib/core/` | S0 | api, secure token store, prefs, session (OTP auth), city, favorites, revisions, deposit (Payme), launcher, booking flow, rental pricing, errors, messenger, images |
| `lib/data/` | S0 | `DirectoryQuery`, `categoriesProvider`, `businessListProvider`, `businessPageProvider`, `storefrontProvider` |
| `lib/theme/` | S0 | `BzColors`/`BzSpace`/`BzRadius`, `AppTheme`, `BzText` |
| `lib/shared/` | S0 | shared widgets and the placeholder / not-found screens |
| `lib/features/<f>/` | A1-A10 | one folder per feature; each agent edits only its own folders |
| `test/support/` | S0 | `FakeApi`, `Fx` fixtures, `pumpBizcat`, `pumpInApp`, `settle`, `FakeUrlOpener` |

## Rules (short)

- Import Material only from `package:material_ui/material_ui.dart`, never
  `package:flutter/material.dart` (go_router 18 and cached_network_image 4 use `material_ui`).
- Apricot is only for `CtaButton` (one per screen) and map pins. Never use it for text.
- Money goes through `Money.format` (tiyin, NBSP groups). Times use the business timezone.
- Phones go through `Phone.normalize` before they reach the API.
- Build paths only with the `AppRoutes` helpers.
- UI text is Uzbek Latin with the ASCII apostrophe (`noto'g'ri`).
