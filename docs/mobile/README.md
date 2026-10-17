# Mobile apps: spec index

Two Flutter apps and one shared Dart package, built on additive Yii2 backend work. Written
2026-10-17 and cross-checked against the working tree of `main`, the local DB and the local pub
cache.

## Specs

| File | What it fixes | Who builds from it |
|---|---|---|
| [BACKEND-PLAN.md](BACKEND-PLAN.md) (**BP**) | Migrations, security hardening (a)-(h), the role matrix (§2.9), every new or changed endpoint with JSON examples, file ownership B1/B2, seed commands, curl verification | B1, B2, orchestrator |
| [CORE-SPEC.md](CORE-SPEC.md) (**CS**) | `mobile/tizbiz_core`: pure-Dart `ApiClient`, `ApiException`, `Endpoints`, `ApiQuery`, models, `Money`, `Phone`, `Dates`/`UzDates`, `Idempotency`, `Permissions`, unit tests | core agent |
| [BIZCAT-SPEC.md](BIZCAT-SPEC.md) | Consumer app `bizcat/` (`uz.tizbiz.bizcat`): brand theme, 25 routes, shared services, 13 features, tests, ownership S0 + A1-A10 | Bizcat agents |
| [BIZNES-SPEC.md](BIZNES-SPEC.md) | Business app `mobile-app/` (`uz.tizbiz.biznes`): admin-mirrored theme, manager and staff shells, 33 routes, 14 features, tests, ownership S + A1-A14 | Biznes agents |

Precedence when two documents disagree: BP (wire contract) > CS (Dart contract) > app specs.

## Rules that every document shares

- **Money** is integer tiyin on the wire and is shown only through `Money.format`
  (`150 000 so'm` with U+00A0 no-break spaces).
- **Time**: `starts_at`/`ends_at` are UTC `Y-m-d H:i:s` strings and `*_at` stamps are unix
  seconds. Display uses the business zone (`Asia/Tashkent`, fixed +05:00). Range queries are
  built only through `ApiQuery`: appointments use UTC datetimes, orders use unix seconds,
  analytics/payroll/finance use UTC days, and `/v1/me/*` and booked-days use business-local days.
- **Phones** are sent as `Phone.normalize(...)`, i.e. `+998XXXXXXXXX`.
- **Tokens**: `typ` `biz` (business app, 7 days) and `consumer` (Bizcat, 30 days). Each app's
  client attaches only its own kind.
- **Staff** may call exactly what the staff shell needs: auth login/me/switch, `/v1/me/*`, and
  `GET`/`PATCH /v1/orders`. Everything else returns 403. `permissions` = `["orders","me"]`.
- **Payments**: Payme only, with key `dep-<appointment_id>-payme`. Click is never sent.
- **No push** in this iteration. The apps use pull-to-refresh and polling (business lists every
  60 s while visible; Bizcat polls payment status every 5 s for up to 2 min).
- **Flutter 3.47**: go_router 18 and cached_network_image 4 import `package:material_ui`. Both apps
  therefore use `material_ui` only and never import `package:flutter/material.dart`. Bizcat uses
  google_fonts only through its `TextStyle` helpers.

## Build order

| Step | Who | Gate to pass before the next step |
|---|---|---|
| 1. Backend B1 ∥ B2 | B1 commits `Jwt.php` first (BP §2a); B2 codes against that signature. File ownership is in BP §5. | `php -l` on every touched file |
| 2. Integrate the backend | Orchestrator: register modules `me`, `consumer`, `directory` in `api/config/main.php`; `php yii migrate` (applies `m260917_*`, then `m261017_100000..100600`); `php yii seed-staff && php yii seed-consumer` | BP §7.1 and all 44 curl checks in BP §7.2; web regression BP §7.3 |
| 3. Core | `mobile/tizbiz_core` per CS | `dart analyze --fatal-infos`, `dart test`, no `package:flutter` / `dart:io` (CS §13) |
| 4. App skeletons ∥ | Bizcat S0, Biznes S | `flutter pub get`, `analyze`, `test`, `build web`; every route opens its placeholder |
| 5. App features ∥ | Bizcat A1-A10, Biznes A1-A14. Each agent edits only its own `lib/features/<f>/` and `test/features/<f>/`. | per-feature analyze/test and the grep checks in each spec |
| 6. Verify | Orchestrator | Whole-app `analyze`/`test`/`build web` for both apps; manual smoke against the local API (`php -S 127.0.0.1:8899 -t api/web api/web/router.php`, run with `--dart-define=API_BASE=http://127.0.0.1:8899`): Bizcat §13.4, Biznes §16 |
| 7. Deploy (later) | Orchestrator | rsync + `yii migrate` + both seeds on prod, then re-check the prod demo phones |

## Demo credentials (after step 2)

Password `secret123` for every business login. Bizcat demo phones log in with OTP `1111`, and no
SMS is sent for them. Slugs: prod first, local in brackets.

| App | Business | Role | Phone |
|---|---|---|---|
| TizBiz Biznes | shox-barber [barber], slot | owner / staff | +998901111111 / +998931110001, +998931110002 |
| TizBiz Biznes | aziza-tortlari [tort], catalog | owner / staff | +998902222222 / +998932220001 |
| TizBiz Biznes | restoran, catalog | owner | +998905555555 |
| TizBiz Biznes | sanatrix [klinika], medical | owner / staff | +998903333333 / +998933330001, +998933330002 |
| TizBiz Biznes | serenada [ijara], rental | owner / staff | +998904444444 / +998934440001 |
| Bizcat | n/a | consumer: rich data / rental booking / empty | +998900000001 / +998900000002 / +998900000003 |

## Open risks

1. **Uncommitted backend.** Rental, booked-days, `guests` and address exist only in the working
   tree. Prod returns 404 or missing fields until they are committed, deployed and migrated. The
   local DB has not applied `m260917_*` yet.
2. **Prod demo data is unverified.** The owner phones above were checked only in the local DB.
   The prod slugs (`shox-barber`, ...) come from the seed defaults. Re-check them after deploy
   (query in BP §6.3).
3. **Real OTP.** When `SmsSender` is not configured, non-demo phones get 503. Only the 3 demo
   phones can log in until SMS is set up. Business login has no rate limit (brute force risk);
   this is not in the plan.
4. **Directory opt-out.** `is_listed` defaults to 1, so every active business appears in Bizcat
   on deploy without the owner opting in, and with no feature flag. CLAUDE.md asks for a flag per
   phase engine; this one is not flagged.
5. **Staff web-admin regression.** It is intended: staff keep only the Orders board in
   `apps/admin`. Front-desk users need the `business_admin` role.
6. **Payments.** Click has a suspected 100x tiyin/so'm bug, so the apps are Payme only. Payme
   checkout has no return deep link, so the apps poll. `POST /v1/payments/deposit` is public, and
   appointment ids are sequential. Refunds are a stub, so the apps offer none.
7. **Money accuracy for rentals.** The rental price is a client-side estimate. Analytics and
   payroll ignore guests, so hall revenue is undercounted.
8. **Medical in Bizcat** uses the catalog/order flow because its storefront has no `staff`.
   Clinic appointments are created only by admins.
9. **Toolchain.** `flutter_secure_storage` and `fl_chart` are not in the local pub cache, so
   `pub get` needs network. google_fonts 6.3.3 still targets SDK material (use only its
   `TextStyle` helpers). With prod `APP_ORIGINS` set, Flutter web from another origin is blocked
   (native builds are unaffected). There is no Android SDK or Xcode, so only `build web` is
   verified.
10. **No realtime.** New bookings and orders reach the business only through polling.
    Device-token tables and FCM come later. Staff cannot change their password and
    appointments cannot be rescheduled, because no endpoints exist for either.
