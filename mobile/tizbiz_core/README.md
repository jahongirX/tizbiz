# tizbiz_core

Shared **pure-Dart** core for the two TizBiz Flutter apps (`bizcat/` consumer app and
`mobile-app/` business app). Source of truth: `docs/mobile/CORE-SPEC.md` (Dart contract) and
`docs/mobile/BACKEND-PLAN.md` (wire contract).

What is here (`lib/tizbiz_core.dart` exports everything):

| Area | Files |
|---|---|
| API | `ApiConfig`, `ApiClient` (dio, envelope unwrap, token attach, 401 hook, upload), `ApiException`, `ApiResponse`/`Paged`/`PageMeta`, `ApiQuery` (the four date-range encodings), `Endpoints` |
| Auth | `TokenStore`/`InMemoryTokenStore`, `JwtClaims` (decode only), `Permissions` |
| Util | `JsonRead` (tolerant readers: 0/1 bools, decimal strings, PHP `[]`), `Idempotency` |
| Format | `Money` (tiyin, NBSP grouping), `Phone` (`+998XXXXXXXXX`) |
| Time | `LocalDate`, `HmTime`, `BizTime`, `Dates` (UTC parsing, fixed business offsets), `UzDates` (Uzbek formatters) |
| Models | hand-written `fromJson`/`toJson` for every API shape + request bodies |

Rules: no `package:flutter`, no `dart:io`/`dart:html` in `lib/` (compiles for Android, iOS and
web), no code generation. Apps import only `package:tizbiz_core/tizbiz_core.dart`
(`CancelToken` is re-exported, so apps need no direct dio dependency).

Use from an app:

```yaml
dependencies:
  tizbiz_core:
    path: ../mobile/tizbiz_core
```

Run the checks:

```sh
cd mobile/tizbiz_core
~/development/flutter/bin/dart pub get
~/development/flutter/bin/dart analyze --fatal-infos
~/development/flutter/bin/dart test
```

Tests never hit the network: `test/support/fake_adapter.dart` is a dio `HttpClientAdapter`
fake and `test/support/fixtures.dart` holds raw JSON from BACKEND-PLAN §4 and the live API.
