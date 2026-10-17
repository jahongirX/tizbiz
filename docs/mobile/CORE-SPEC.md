# Core spec: `mobile/tizbiz_core` (shared pure-Dart package)

Status: **source of truth** for the implementer of `mobile/tizbiz_core` and for the two Flutter
apps that consume it (`bizcat/` = consumer app "Bizcat", `mobile-app/` = business app "TizBiz Biznes").
Written 2026-10-17 against `docs/mobile/BACKEND-PLAN.md` (the API contract) and the live code of
`main` (models' `fields()`, controllers, the `Envelope`, and real responses from the local API).

Hard rules:

- **Pure Dart.** No `package:flutter/*` import anywhere in `lib/` or `test/`. `dart test` must run
  on the VM. Also no `dart:io` and no `dart:html`/`package:web` in `lib/` (the package is compiled
  for Android, iOS **and web**). `dio` picks its platform adapter itself.
- **No code generation.** No freezed, json_serializable or build_runner. Every `fromJson`/`toJson`
  is hand-written.
- **Wire names are the API's.** Every JSON key below was checked against BACKEND-PLAN.md or the
  current PHP (`fields()`, controller arrays, `information_schema`). Do not rename keys.
- **Tolerant parsing.** The API serialises raw ActiveRecord rows, so booleans arrive as `0/1`
  (verified: `is_active:1`, `online_bookable:1`, `is_superadmin:0`), `decimal` columns can arrive
  as strings (`"41.2756000"`), and PHP's empty associative array arrives as `[]`. Every model reads
  through `JsonRead` (§6) and **never throws** for a missing or odd-typed field. Only a non-map
  top level throws `FormatException`.

---

## 1. `pubspec.yaml`

```yaml
name: tizbiz_core
description: Shared pure-Dart core for the TizBiz mobile apps (API client, models, formatting).
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.9.0          # local toolchain is Dart 3.13.5 (Flutter 3.47.7); no language feature newer than 3.9 is used

dependencies:
  dio: ^5.9.0          # 5.11.1 is in the local pub cache
  intl: '>=0.19.0 <0.21.0'   # Flutter's flutter_localizations pins ^0.20.3; keep the range wide
  meta: ^1.18.0        # Flutter pins ^1.18.3
  collection: ^1.19.0  # Flutter pins ^1.19.1

dev_dependencies:
  test: ^1.29.0
  lints: ^6.0.0
```

`intl` is declared so both apps resolve one version, but the core formatters are hand-rolled
(Uzbek month names and money grouping must match the web exactly and must not depend on ICU locale
data). Do not import `package:intl` in `lib/` unless a later need appears.

`analysis_options.yaml`:

```yaml
include: package:lints/recommended.yaml
analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
linter:
  rules:
    - prefer_final_fields
    - prefer_const_constructors
    - avoid_print
    - always_declare_return_types
    - unawaited_futures
```

Both apps depend on it by path (both live at the repo root):

```yaml
# bizcat/pubspec.yaml and mobile-app/pubspec.yaml
dependencies:
  tizbiz_core:
    path: ../mobile/tizbiz_core
```

---

## 2. Library layout

```
mobile/tizbiz_core/
  pubspec.yaml
  analysis_options.yaml
  README.md                       # 1 page: what is here, how to run tests
  lib/
    tizbiz_core.dart              # barrel: exports every file below (nothing under src/ is private API except where noted)
    src/
      api/
        api_config.dart           # ApiConfig
        api_client.dart           # ApiClient, RequestAuth, UnauthorizedHandler
        api_exception.dart        # ApiException, ApiErrorKind, ApiErrorItem
        api_response.dart         # ApiResponse<T>, Paged<T>, PageMeta
        api_query.dart            # ApiQuery: correct from/to encodings per endpoint
        endpoints.dart            # Endpoints: every path the apps call
      auth/
        token_store.dart          # TokenStore (abstract), InMemoryTokenStore
        jwt_claims.dart           # TokenKind, JwtClaims (decode only, no verification)
        permissions.dart          # Permissions (mirror of common/rbac/Permissions.php)
      util/
        json_read.dart            # JsonRead: tolerant readers
        idempotency.dart          # Idempotency: uuid v4 + deposit key
      format/
        money.dart                # Money
        phone.dart                # Phone
      time/
        local_date.dart           # LocalDate (date-only value type)
        hm_time.dart              # HmTime (wall-clock HH:MM value type)
        biz_time.dart             # BizTime (instant + business offset)
        dates.dart                # Dates (parse/convert/offsets)
        uz_dates.dart             # UzDates (Uzbek formatters)
      models/
        enums.dart                # AppointmentStatus, OrderStatus, Engine, BizRole, RentalSession, Gender, ReviewStatus, PaymentProvider
        business.dart             # BusinessRef, BusinessCard, BusinessDetail, OpeningHours, BusinessPage, Category, SiteBusiness, BusinessMembership
        catalog.dart              # Service, ServiceCategory, Staff
        storefront.dart           # StorefrontData, CatalogCategory, Availability, AvailabilitySlot, BookedDays
        appointment.dart          # Appointment, AppointmentItem
        order.dart                # Order, OrderItem
        client.dart               # Client, ClientCategory, ClientLoyalty, ClientDetail
        review.dart               # Review, RatingSummary
        consumer.dart             # ConsumerUser, ConsumerStats, ConsumerSession, OtpSent, LoyaltyWalletEntry
        auth.dart                 # BizUser, ActiveContext, AuthSession, AuthMe, SwitchResult
        team.dart                 # TeamMember
        schedule.dart             # WorkingHours, TimeOff, MeSchedule
        reports.dart              # AnalyticsOverview (+parts), PayrollReport, PayrollRow, FinanceSummary, FinanceProviderRow, FinanceTransaction, MeStats (+parts)
        settings.dart             # BookingSettings
        payment.dart              # PaymentTransaction, DepositCheckout
        requests.dart             # request bodies: ConsumerBookingRequest, AdminBookingRequest, ConsumerOrderRequest, OrderLine, ReviewInput, ConsumerProfilePatch, TeamMemberInput, TeamMemberPatch, TimeOffInput, WorkingHoursInput
  test/
    support/fake_adapter.dart     # FakeAdapter implements dio HttpClientAdapter
    support/fixtures.dart         # raw JSON strings (copied from BACKEND-PLAN.md + live local responses)
    ... (see §12)
```

`lib/tizbiz_core.dart`:

```dart
library;

export 'src/api/api_config.dart';
export 'src/api/api_client.dart';
export 'src/api/api_exception.dart';
export 'src/api/api_response.dart';
export 'src/api/api_query.dart';
export 'src/api/endpoints.dart';
export 'src/auth/token_store.dart';
export 'src/auth/jwt_claims.dart';
export 'src/auth/permissions.dart';
export 'src/util/json_read.dart';
export 'src/util/idempotency.dart';
export 'src/format/money.dart';
export 'src/format/phone.dart';
export 'src/time/local_date.dart';
export 'src/time/hm_time.dart';
export 'src/time/biz_time.dart';
export 'src/time/dates.dart';
export 'src/time/uz_dates.dart';
export 'src/models/enums.dart';
export 'src/models/business.dart';
export 'src/models/catalog.dart';
export 'src/models/storefront.dart';
export 'src/models/appointment.dart';
export 'src/models/order.dart';
export 'src/models/client.dart';
export 'src/models/review.dart';
export 'src/models/consumer.dart';
export 'src/models/auth.dart';
export 'src/models/team.dart';
export 'src/models/schedule.dart';
export 'src/models/reports.dart';
export 'src/models/settings.dart';
export 'src/models/payment.dart';
export 'src/models/requests.dart';
```

Apps import `package:tizbiz_core/tizbiz_core.dart` only. Dio types (`CancelToken`, `Dio`) are
re-exported by name from `api_client.dart` with `export 'package:dio/dio.dart' show CancelToken;`
so the apps do not need a direct dio dependency.

---

## 3. API layer

### 3.1 `ApiConfig`

```dart
@immutable
final class ApiConfig {
  static const String defaultBaseUrl = 'https://api.tizbiz.uz';

  const ApiConfig({
    this.baseUrl = defaultBaseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 20),
    this.log,
  });

  /// Reads `--dart-define=API_BASE=...` (falls back to [defaultBaseUrl]).
  /// Works because the const is evaluated when the app (which includes this package) is compiled.
  factory ApiConfig.fromEnvironment({void Function(String line)? log}) => ApiConfig(
        baseUrl: const String.fromEnvironment('API_BASE', defaultValue: defaultBaseUrl),
        log: log,
      );

  /// Without a trailing slash; paths in [Endpoints] start with '/v1/'.
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  /// Optional request log sink: one line per request, `"GET /v1/me/stats -> 200 (123 ms)"`.
  /// It never receives headers, query values or bodies (passwords, OTP codes, tokens).
  final void Function(String line)? log;

  /// [baseUrl] with trailing '/' removed.
  String get normalizedBaseUrl;
}
```

Local dev: `--dart-define=API_BASE=http://127.0.0.1:8899` (`php -S 127.0.0.1:8899 -t api/web api/web/router.php`).
The MAMP host `https://api.startup` uses a self-signed cert, which the pure-Dart client cannot
bypass without `dart:io`; use the `php -S` server for device/web testing.

**CORS rule (Flutter web).** The client sends only `Authorization`, `Content-Type`, `Accept` and
`Idempotency-Key`. No custom `X-*` header and no `User-Agent` override, otherwise the browser
preflight fails (`common/rest/Controller.php` CORS list; `Idempotency-Key` is added by BACKEND-PLAN §2.8).

### 3.2 `RequestAuth`, `ApiResponse`, `Paged`, `PageMeta`

```dart
/// Whether a request carries the stored token.
enum RequestAuth {
  /// Attach the token when one is stored and valid for this client's [TokenKind] (default).
  auto,
  /// Never attach (login, OTP, public storefront, availability, deposit). A 401 on such a request
  /// never triggers the unauthorized hook (e.g. the login 401 'Telefon yoki parol noto'g'ri.').
  none,
}

@immutable
final class ApiResponse<T> {
  const ApiResponse({required this.statusCode, required this.data, this.meta, this.headers = const {}});
  final int statusCode;
  final T data;                              // unwrapped `data` (null for 204)
  final PageMeta? meta;                      // present when the envelope has `meta`
  final Map<String, List<String>> headers;   // lower-cased names
  /// true for 200 on a create endpoint that answers 201 for a new row (idempotent replay).
  bool get isReplay => statusCode == 200;
  bool get isCreated => statusCode == 201;
}

@immutable
final class PageMeta {
  const PageMeta({required this.page, required this.perPage, required this.total, required this.pages, this.extra = const {}});
  /// Synthesised for a non-paginated list: page 1 of 1.
  factory PageMeta.single(int count);
  factory PageMeta.fromJson(Map<String, dynamic> json);    // keys: page, per_page, total, pages; every other key -> extra
  final int page;          // json: page
  final int perPage;       // json: per_page
  final int total;         // json: total
  final int pages;         // json: pages (0 when total == 0)
  /// Non-standard meta keys, e.g. reviews: avg, count, distribution.
  final Map<String, dynamic> extra;
  bool get hasMore => page < pages;
  int? get nextPage => hasMore ? page + 1 : null;
  Map<String, dynamic> toJson();
  // == and hashCode over page, perPage, total, pages (extra excluded)
}

@immutable
final class Paged<T> {
  const Paged({required this.items, required this.meta});
  final List<T> items;
  final PageMeta meta;
  bool get hasMore => meta.hasMore;
  bool get isEmpty => items.isEmpty;
  /// Appends the next page (for infinite scroll); keeps [next.meta].
  Paged<T> append(Paged<T> next);
  Paged<R> map<R>(R Function(T) f);
}
```

### 3.3 `ApiClient`

```dart
export 'package:dio/dio.dart' show CancelToken;

typedef UnauthorizedHandler = FutureOr<void> Function(ApiException error);
typedef JsonDecoder<T> = T Function(dynamic data);

final class ApiClient {
  ApiClient({
    required ApiConfig config,
    required TokenKind tokenKind,          // TokenKind.consumer in Bizcat, TokenKind.biz in TizBiz Biznes
    TokenStore? tokenStore,                // defaults to InMemoryTokenStore()
    UnauthorizedHandler? onUnauthorized,
    Dio? dio,                              // tests inject a Dio with FakeAdapter (see rule 4: options are overwritten)
    DateTime Function()? clock,            // defaults to DateTime.now; used for exp checks
  });

  final ApiConfig config;
  final TokenKind tokenKind;

  // ---------- token ----------
  /// Lazily loads the token from the store once, then serves it from memory.
  /// Returns null when absent, malformed, of the wrong [TokenKind] (store is cleared), or expired
  /// (store is cleared and [onUnauthorized] is NOT called; the app decides on next 401 / on boot).
  Future<String?> currentToken();
  /// Claims of the current token (null when none).
  Future<JwtClaims?> currentClaims();
  /// Saves and caches. Throws [ArgumentError] if the token's kind != [tokenKind] (programming error:
  /// e.g. storing a business token in Bizcat). `null` == [clearToken].
  Future<void> setToken(String? token);
  Future<void> clearToken();
  /// Stream of token changes (null on clear), for Riverpod auth providers.
  Stream<String?> get tokenChanges;

  // ---------- requests ----------
  /// Low-level call. Every verb below delegates here.
  Future<ApiResponse<T>> request<T>(
    String method,                         // 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'
    String path, {
    Map<String, Object?>? query,
    Object? body,                          // encoded as JSON; null = no body
    JsonDecoder<T>? decode,                // applied to envelope `data`; null => data cast to T
    String? idempotencyKey,                // sent as header 'Idempotency-Key'
    RequestAuth auth = RequestAuth.auto,
    CancelToken? cancelToken,
  });

  Future<T> get<T>(String path, {Map<String, Object?>? query, JsonDecoder<T>? decode, RequestAuth auth = RequestAuth.auto, CancelToken? cancelToken});
  Future<T> post<T>(String path, {Object? body, Map<String, Object?>? query, JsonDecoder<T>? decode, String? idempotencyKey, RequestAuth auth = RequestAuth.auto, CancelToken? cancelToken});
  Future<T> put<T>(String path, {Object? body, Map<String, Object?>? query, JsonDecoder<T>? decode, String? idempotencyKey, RequestAuth auth = RequestAuth.auto, CancelToken? cancelToken});
  Future<T> patch<T>(String path, {Object? body, Map<String, Object?>? query, JsonDecoder<T>? decode, String? idempotencyKey, RequestAuth auth = RequestAuth.auto, CancelToken? cancelToken});
  Future<T> delete<T>(String path, {Object? body, Map<String, Object?>? query, JsonDecoder<T>? decode, RequestAuth auth = RequestAuth.auto, CancelToken? cancelToken});

  /// `data` must be a List of maps; `meta` is read when present, else PageMeta.single(items.length).
  Future<Paged<T>> getPage<T>(String path, T Function(Map<String, dynamic> json) item, {Map<String, Object?>? query, RequestAuth auth = RequestAuth.auto, CancelToken? cancelToken});

  /// Non-paginated list (`{"data":[...]}`); null/[]/{} data => [].
  Future<List<T>> getList<T>(String path, T Function(Map<String, dynamic> json) item, {Map<String, Object?>? query, RequestAuth auth = RequestAuth.auto, CancelToken? cancelToken});

  /// Multipart upload for POST /v1/uploads. [contentType] is REQUIRED and must be image/*
  /// (the server checks the declared type; octet-stream is rejected). Returns the `url`.
  Future<String> uploadImage(List<int> bytes, {required String filename, required String contentType, String path = Endpoints.uploads, CancelToken? cancelToken});

  void close({bool force = false});
}
```

Behaviour (normative):

1. **URL**: `config.normalizedBaseUrl + path`. `path` must start with `/`.
2. **Query encoding** (`_encodeQuery`): entries with `null` value are dropped; `bool` → `'1'`/`'0'`;
   `LocalDate` → `toIso()`; `DateTime` → `Dates.formatApiUtc(v)`; `Enum`-like values that expose
   `wire` (all enums in §9) → `wire`; `num` → `toString()`; everything else `toString()`.
3. **Headers**: `Accept: application/json` always; `Content-Type: application/json` when `body != null`;
   `Authorization: Bearer <t>` when `auth == RequestAuth.auto` and `currentToken()` is non-null;
   `Idempotency-Key` when given.
4. **Status handling**: the Dio instance is built with `validateStatus: (_) => true` and
   `responseType: ResponseType.plain`; the client decodes JSON itself (empty body → null).
   An **injected** `dio` keeps its `httpClientAdapter` and interceptors, but the constructor
   always overwrites `options.validateStatus`, `options.responseType` and the three timeouts
   from [config], so a test `Dio()..httpClientAdapter = fake` behaves exactly like production.
   - 2xx: body `{"data": X, "meta"?: M}` → `ApiResponse(data: decode?(X) ?? X as T, meta: M == null ? null : PageMeta.fromJson(M))`.
     A 2xx body that is not an envelope (no `data` key) is passed whole as `data` (defensive).
     204 / empty body → `data = null` (callers use `T = void` or nullable).
   - non-2xx: throw `ApiException.fromResponse(statusCode, decodedBody, headers)`.
5. **401 hook**: if a non-2xx is 401 **and the request carried an Authorization header**, the
   client (a) clears the token store and memory cache, (b) calls `onUnauthorized(error)` **once per
   token value** (concurrent 401s for the same token call it once), (c) throws the error.
   Requests with `RequestAuth.none`, or sent without a token, never trigger it.
6. **Token kind**: the client attaches a token only if `JwtClaims.tryParse(token)?.kind == tokenKind`.
   Missing `typ` = `biz` (backward compatible with tokens issued before BACKEND-PLAN §2a).
7. **Transport errors** (`DioException` without response): `connectionTimeout|sendTimeout|receiveTimeout`
   → `ApiException(kind: timeout, status: 0)`; `cancel` → `kind: cancelled`; everything else
   (`connectionError`, `unknown`, `badCertificate`) → `kind: network`. Original error in `cause`.
8. **No automatic retries.** Retrying a POST is the app's decision and must reuse the same
   `idempotencyKey`.
9. **Logging**: if `config.log != null`, one line per completed request: `'$method $path -> $status (${ms} ms)'`
   (path without query string). Never headers, query or body.

### 3.4 `ApiException`

```dart
enum ApiErrorKind { http, network, timeout, cancelled, decode }

@immutable
final class ApiErrorItem {
  const ApiErrorItem({required this.status, required this.title, required this.detail, this.code, this.pointer});
  factory ApiErrorItem.fromJson(Map<String, dynamic> json); // keys: status (string|int), title, detail, code?, source.pointer?
  final int status;
  final String title;
  final String detail;
  final String? code;
  final String? pointer;     // json: source.pointer, e.g. 'phone', 'items[2].end_time'
  Map<String, dynamic> toJson();
}

final class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.status,
    this.title = '',
    this.detail = '',
    this.code,
    this.fieldErrors = const {},
    this.errors = const [],
    this.retryAfter,
    this.cause,
  });

  /// Parses `{"errors":[...]}`. status = int.tryParse(errors[0].status) ?? httpStatus.
  /// fieldErrors = { pointer: detail } for every item that has source.pointer (first wins per pointer).
  /// title/detail/code from errors[0]. retryAfter from header 'retry-after' (seconds).
  /// Non-JSON or envelope-less body -> kind http, title '', detail ''.
  factory ApiException.fromResponse(int httpStatus, Object? body, Map<String, List<String>> headers);
  factory ApiException.network(ApiErrorKind kind, {Object? cause});   // status 0

  final ApiErrorKind kind;
  final int status;                       // HTTP status; 0 for transport errors
  final String title;                     // e.g. 'Conflict', 'Validation error'
  final String detail;                    // server text, usually Uzbek
  final String? code;
  final Map<String, String> fieldErrors;  // 422 with pointer only
  final List<ApiErrorItem> errors;
  final Duration? retryAfter;             // 429 resend
  final Object? cause;

  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
  bool get isNotFound => status == 404;
  bool get isConflict => status == 409;
  bool get isValidation => status == 422;          // both 422 shapes (with and without pointer)
  bool get isRateLimited => status == 429;
  bool get isServer => status >= 500;
  bool get isNetwork => kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;
  bool get isCancelled => kind == ApiErrorKind.cancelled;
  bool get hasFieldErrors => fieldErrors.isNotEmpty;

  String? fieldError(String pointer) => fieldErrors[pointer];

  /// User-facing Uzbek text (see table). Never empty.
  String get message;

  @override
  String toString();   // 'ApiException(409 Conflict: Tanlangan vaqt band.)'
}
```

`message` resolution, in order:
1. `kind == network` → `Internet aloqasi yo'q. Qayta urinib ko'ring.`; `timeout` → `Server javob bermadi. Qayta urinib ko'ring.`; `cancelled` → `So'rov bekor qilindi.`; `decode` → `Serverdan noto'g'ri javob keldi.`
2. Known English server strings are translated:

| Server `detail` | `message` |
|---|---|
| `Your request was made with invalid credentials.` | `Sessiya tugadi. Qaytadan kiring.` |
| `No active business selected.` | `Faol biznes tanlanmagan.` |
| `Insufficient role for this action.` | `Bu amal uchun ruxsatingiz yo'q.` |
| `Login required` | `Tizimga kiring.` |

3. Non-empty `detail` → `detail` as is (server text is already Uzbek).
4. First value of `fieldErrors`.
5. Fallback by status: 400 `So'rov noto'g'ri.`; 401 `Sessiya tugadi. Qaytadan kiring.`; 403 `Bu amal uchun ruxsatingiz yo'q.`;
   404 `Topilmadi.`; 409 `Amalni bajarib bo'lmadi: ma'lumot o'zgargan.`; 422 `Ma'lumotlar noto'g'ri to'ldirilgan.`;
   429 `Juda ko'p urinish. Keyinroq urinib ko'ring.`; >=500 `Serverda xatolik. Keyinroq urinib ko'ring.`; other `Xatolik yuz berdi.`
   (step 5 also covers the `{ok:false,error}` endpoints whose text the Envelope loses).

### 3.5 `ApiQuery`: one place for the four date encodings

The API uses four different encodings for ranges. Getting them wrong silently returns the wrong
window (the web admin already does: Analytics ignores its period). Apps must build these queries
only through `ApiQuery`.

```dart
abstract final class ApiQuery {
  /// GET /v1/appointments. Server: starts_at >= from AND starts_at <= to (UTC 'Y-m-d H:i:s').
  /// from = local 00:00 of [from] in UTC; to = local 00:00 of ([to] + 1 day) in UTC minus 1 second.
  static Map<String, Object?> appointments({required LocalDate from, required LocalDate to, String? timezone, int? staffId, AppointmentStatus? status});
  //   -> {'from': '2026-10-16 19:00:00', 'to': '2026-10-17 18:59:59', 'staff': staffId, 'status': status?.wire}

  /// GET /v1/orders. Server: created_at >= from AND created_at < to (unix seconds).
  static Map<String, Object?> orders({required LocalDate from, required LocalDate to, String? timezone, OrderStatus? status, int? limit});
  //   -> {'from': 1792177200, 'to': 1792263600, 'status': ..., 'limit': ...}

  /// analytics/overview, payroll, finance/summary, finance/transactions: plain 'YYYY-MM-DD'
  /// (server treats them as UTC days; documented limitation).
  static Map<String, Object?> utcDays({required LocalDate from, required LocalDate to});

  /// /v1/me/appointments, /v1/me/stats, /v1/me/schedule, /v1/site/{slug}/booked-days: business-local dates.
  static Map<String, Object?> localDays({LocalDate? from, LocalDate? to});

  /// GET /v1/staff/{id}/availability.
  static Map<String, Object?> availability({required LocalDate date, required int serviceId});

  /// page/per_page helper; per_page is clamped by the server (directory/consumer 1..50, crm 1..100).
  static Map<String, Object?> page(int page, {int perPage = 20});
}
```

### 3.6 `Endpoints`

```dart
abstract final class Endpoints {
  // business auth & team (TizBiz Biznes)
  static const login = '/v1/auth/login';
  static const authMe = '/v1/auth/me';
  static String switchBusiness(int businessId) => '/v1/auth/switch/$businessId';
  static const team = '/v1/team';
  static String teamMember(int userId) => '/v1/team/$userId';

  // staff self-service
  static const meStaff = '/v1/me/staff';
  static const meStats = '/v1/me/stats';
  static const meSchedule = '/v1/me/schedule';
  static const meAppointments = '/v1/me/appointments';
  static String meAppointment(int id) => '/v1/me/appointments/$id';

  // tenant data (business token)
  static const staff = '/v1/staff';
  static String staffById(int id) => '/v1/staff/$id';
  static String workingHours(int staffId) => '/v1/staff/$staffId/working-hours';
  static String timeOff(int staffId) => '/v1/staff/$staffId/time-off';
  static String timeOffItem(int staffId, int id) => '/v1/staff/$staffId/time-off/$id';
  static const services = '/v1/services';
  static String service(int id) => '/v1/services/$id';
  static const serviceCategories = '/v1/service-categories';
  static String serviceCategory(int id) => '/v1/service-categories/$id';
  static const bookingSettings = '/v1/settings/booking';
  static const uploads = '/v1/uploads';                  // owner/admin only (BP §2b)
  static const appointments = '/v1/appointments';
  static String appointment(int id) => '/v1/appointments/$id';
  static const orders = '/v1/orders';
  static String order(int id) => '/v1/orders/$id';
  static const clients = '/v1/clients';
  static String client(int id) => '/v1/clients/$id';
  static String clientCategoriesOf(int clientId) => '/v1/clients/$clientId/categories';
  static const clientCategories = '/v1/client-categories';
  static const analyticsOverview = '/v1/analytics/overview';
  static const financeSummary = '/v1/finance/summary';
  static const financeTransactions = '/v1/finance/transactions';
  static const payroll = '/v1/payroll';
  static const reviews = '/v1/reviews';
  static String reviewReply(int id) => '/v1/reviews/$id/reply';

  // public (no token)
  static String availability(int staffId) => '/v1/staff/$staffId/availability';
  static String site(String slug) => '/v1/site/${Uri.encodeComponent(slug)}';
  static String siteBookedDays(String slug) => '/v1/site/${Uri.encodeComponent(slug)}/booked-days';
  static const paymentsDeposit = '/v1/payments/deposit';

  // directory (optional consumer token)
  static const directoryCategories = '/v1/directory/categories';
  static const directoryBusinesses = '/v1/directory/businesses';
  static String directoryBusiness(String slug) => '/v1/directory/businesses/${Uri.encodeComponent(slug)}';
  static String directoryReviews(String slug) => '/v1/directory/businesses/${Uri.encodeComponent(slug)}/reviews';

  // consumer (Bizcat)
  static const consumerOtp = '/v1/consumer/auth/otp';
  static const consumerVerify = '/v1/consumer/auth/verify';
  static const consumerMe = '/v1/consumer/me';
  static const consumerFavorites = '/v1/consumer/favorites';
  static String consumerFavorite(int businessId) => '/v1/consumer/favorites/$businessId';
  static const consumerAppointments = '/v1/consumer/appointments';
  static String consumerAppointment(int id) => '/v1/consumer/appointments/$id';
  static String consumerAppointmentCancel(int id) => '/v1/consumer/appointments/$id/cancel';
  static const consumerOrders = '/v1/consumer/orders';
  static String consumerOrder(int id) => '/v1/consumer/orders/$id';
  static String consumerOrderCancel(int id) => '/v1/consumer/orders/$id/cancel';
  static const consumerLoyalty = '/v1/consumer/loyalty';
  static const consumerReviews = '/v1/consumer/reviews';
  static String consumerReview(int id) => '/v1/consumer/reviews/$id';
}
```

Which `RequestAuth` to use: `none` for `login`, `consumerOtp`, `consumerVerify`, `site*`,
`availability`, `paymentsDeposit`; `auto` for everything else (directory endpoints accept an
optional consumer token for `is_favorite`). The business app must never call public
`POST /v1/appointments` with a staff token (403) and only uses it as owner/admin (admin mode).

---

## 4. Auth helpers

### 4.1 `TokenStore`

```dart
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

final class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([String? initial]);
  // read/write/clear on a field
}
```

Apps implement it with `flutter_secure_storage` (not in core):

```dart
// bizcat: key 'bizcat_consumer_token'; mobile-app: key 'tizbiz_biz_token'
final class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage, this._key);
  final FlutterSecureStorage _storage; final String _key;
  @override Future<String?> read() => _storage.read(key: _key);
  @override Future<void> write(String t) => _storage.write(key: _key, value: t);
  @override Future<void> clear() => _storage.delete(key: _key);
}
```

### 4.2 `JwtClaims` (decode only)

```dart
enum TokenKind { biz, consumer, unknown }

@immutable
final class JwtClaims {
  const JwtClaims({required this.sub, this.tenantId, this.role, required this.kind, required this.typ, this.issuedAt, this.expiresAt, this.issuer});

  /// Base64url-decodes the payload (segment 2, padding restored). No signature check (the server does it).
  /// Returns null for anything that is not 3 dot-separated segments with a JSON object payload.
  static JwtClaims? tryParse(String? token);

  final int sub;               // claim sub (users.id or consumer_users.id)
  final int? tenantId;         // claim tid
  final String? role;          // claim role
  final String typ;            // claim typ; '' -> 'biz' (legacy tokens have no typ)
  final TokenKind kind;        // 'biz' -> biz, 'consumer' -> consumer, other -> unknown
  final DateTime? issuedAt;    // iat (unix, UTC)
  final DateTime? expiresAt;   // exp (unix, UTC)
  final String? issuer;        // iss

  /// exp <= now + leeway. A token without exp is not considered expired.
  bool isExpired(DateTime now, {Duration leeway = const Duration(seconds: 30)});
}
```

### 4.3 `Permissions` (mirror of `common/rbac/Permissions.php`)

```dart
abstract final class Permissions {
  static const appointmentsAll = 'appointments.all';
  static const appointmentsManage = 'appointments.manage';
  static const orders = 'orders';
  static const clients = 'clients';
  static const analytics = 'analytics';
  static const finance = 'finance';
  static const payroll = 'payroll';
  static const loyalty = 'loyalty';
  static const inventory = 'inventory';
  static const catalogManage = 'catalog.manage';
  static const teamRead = 'team.read';
  static const teamManage = 'team.manage';
  static const settingsManage = 'settings.manage';
  static const reviews = 'reviews';
  static const uploads = 'uploads';
  static const me = 'me';

  static const List<String> all = [appointmentsAll, appointmentsManage, orders, clients, analytics,
    finance, payroll, loyalty, inventory, catalogManage, teamRead, teamManage, settingsManage,
    reviews, uploads, me];

  /// business_owner => all; business_admin => all minus team.manage; staff => [orders, me]; other/null => [].
  /// (staff = exactly the staff shell: orders board + /v1/me/*; BP §2b/§2.9)
  static List<String> forRole(String? role);
}
```

`ActiveContext.permissions` (§10.10) uses the server list when present and falls back to
`Permissions.forRole(role)` when the server omits it (a server older than BACKEND-PLAN).

---

## 5. `Idempotency`

```dart
abstract final class Idempotency {
  static const String header = 'Idempotency-Key';

  /// RFC 4122 version-4 UUID, lowercase, 36 chars 'xxxxxxxx-xxxx-4xxx-Yxxx-xxxxxxxxxxxx' with Y in [89ab].
  /// Uses Random.secure() unless [random] is given (tests). No extra dependency.
  static String newKey([Random? random]);

  /// Stable deposit key per appointment + provider, as in BACKEND-PLAN §4.5: 'dep-5012-payme'.
  /// Re-tapping "To'lash" must reuse it so the server replays the same Payme checkout (no double charge).
  static String deposit(int appointmentId, {PaymentProvider provider = PaymentProvider.payme});
}
```

Usage rule for booking/order creation: the app generates **one** `newKey()` when the user opens
the confirm step and keeps it until success (or until the user changes slot/items). Retries after a
timeout reuse it; a 200 reply (`ApiResponse.isReplay`) is treated as success.

---

## 6. `JsonRead` (tolerant readers)

```dart
abstract final class JsonRead {
  /// Top-level guard used by every fromJson: Map -> itself; PHP empty array [] -> {}; else FormatException.
  static Map<String, dynamic> object(Object? v);
  /// Same, but null/[]/non-map -> null (for optional nested objects).
  static Map<String, dynamic>? objectOrNull(Object? v);

  static int integer(Object? v, [int fallback = 0]);   // int; double -> truncate; '12' / '12.0' -> 12; true -> 1; else fallback
  static int? integerOrNull(Object? v);                 // null/''/unparseable -> null
  static double number(Object? v, [double fallback = 0]);
  static double? numberOrNull(Object? v);               // '41.2756000' -> 41.2756
  static bool boolean(Object? v, [bool fallback = false]); // true/false, 1/0, '1'/'0', 'true'/'false' (any case)
  static bool? booleanOrNull(Object? v);
  static String string(Object? v, [String fallback = '']); // num -> toString; null -> fallback
  static String? stringOrNull(Object? v);               // keeps '' as ''
  static String? nonEmptyOrNull(Object? v);             // '' / whitespace -> null (logo, cover, brand colors)
  static List<String> stringList(Object? v);            // List -> strings; JSON-encoded string '["a"]' -> decoded; null -> []
  static List<T> list<T>(Object? v, T Function(Map<String, dynamic>) item); // null/{} -> []; skips non-map entries
  static DateTime? utc(Object? v);                      // Dates.parseUtc
  static DateTime? unix(Object? v);                     // Dates.fromUnix
  static LocalDate? date(Object? v);                    // LocalDate.tryParse
  static HmTime? time(Object? v);                       // HmTime.tryParse
}
```

Serialization conventions used by every `toJson()`:
- every known key is written; `null` stays `null`;
- `DateTime` from `*_at` unix fields → `Dates.toUnix(v)` int; `starts_at`/`ends_at`/`start_utc`/`end_utc`/`last_visit`/`next_at` → `Dates.formatApiUtc(v)`;
- `LocalDate` → `'YYYY-MM-DD'`; `HmTime` → `'HH:MM:SS'` for working hours/time-off, `'HH:MM'` for `OpeningHours` and `start_local`;
- enums → `wire`; booleans → `true/false` (not 0/1);
- `toJson` is a **fixed point**: `X.fromJson(x.toJson()).toJson()` deep-equals `x.toJson()` (tested with `DeepCollectionEquality`).

---

## 7. `Money`

```dart
abstract final class Money {
  /// U+00A0 NO-BREAK SPACE. This is exactly what `Number.toLocaleString('ru-RU')` emits in V8/ICU
  /// (checked: (1500000).toLocaleString('ru-RU') -> '1 500 000'), and it keeps
  /// "150 000 so'm" on one line in Flutter Text.
  static const String groupSeparator = ' ';
  static const String currency = "so'm";

  /// tiyin -> whole so'm, rounded half away from zero (Dart num.round()). 5000050 -> 50001.
  static int toSom(int tiyin);
  /// so'm -> tiyin, (som * 100).round(). 50 -> 5000; 12.5 -> 1250.
  static int fromSom(num som);

  /// "150 000 so'm" with [separator] between groups and between number and currency.
  /// null -> '—'. Negative -> '-150 000 so'm' (ASCII hyphen-minus, like apps/admin formatSom).
  static String format(int? tiyin, {bool withCurrency = true, String separator = groupSeparator});

  /// Digits only, grouped: 1500000 -> '1 500 000' (separator configurable). Accepts negative.
  static String group(int value, {String separator = groupSeparator});

  /// Short form for chart axes and chips (decimal comma, at most 1 decimal, trailing ',0' dropped):
  /// < 1 000 so'm -> '950 so'm'; < 1e6 -> '150 ming so'm'; < 1e9 -> '1,5 mln so'm'; else '2 mlrd so'm'.
  static String compact(int tiyin, {bool withCurrency = true});

  /// Parses a user-typed so'm amount ('150 000', '150000', '150 000,50', '1 500') -> tiyin.
  /// Returns null for empty or invalid input. Spaces/NBSP/U+202F are ignored; one ',' or '.' decimal (max 2 digits).
  static int? parseSomInput(String? text);
}
```

Note: JS `Math.round(-1.5)` is `-1`, Dart `(-1.5).round()` is `-2`. Only refunds/negative deltas
are affected and only at exactly half a so'm; accepted.

---

## 8. `Phone`

```dart
abstract final class Phone {
  /// Exact mirror of common\helpers\Phone::normalize: strip non-digits; < 9 digits -> null;
  /// else '+998' + last 9 digits. '90 123 45 67' -> '+998901234567'; '+998 (90) 123-45-67' -> same;
  /// '8 90 123 45 67' -> '+998901234567' (last 9); '12345' -> null.
  static String? normalize(String? input);

  /// Stricter client-side check used by forms: digit count is 9, or 12 starting with '998'.
  static bool isValid(String? input);

  /// '+998 90 123 45 67'. Input that cannot be normalized is returned trimmed, unchanged.
  static String format(String? phone);

  /// '90 123 45 67' (no country code).
  static String formatLocal(String? phone);

  /// As-you-type formatting of the 9 local digits (ignores a leading 998 / +998):
  /// '9' -> '9', '901' -> '90 1', '90123' -> '90 123', '9012345' -> '90 123 45', '901234567' -> '90 123 45 67'.
  /// Extra digits beyond 9 are dropped.
  static String formatPartial(String input);

  /// Masked for lists/logs: '+998 90 *** ** 67'.
  static String mask(String? phone);

  /// 'tel:+998901234567' (null when not normalizable).
  static Uri? telUri(String? phone);
}
```

Apps always send `Phone.normalize(...)` output (critic: the server lookup was raw-phone until
BACKEND-PLAN §2g lands).

---

## 9. Time

### 9.1 `LocalDate`

```dart
@immutable
final class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);
  /// 'YYYY-MM-DD' (also accepts 'YYYY-MM-DD HH:MM:SS' / ISO by taking the first 10 chars). Throws FormatException.
  factory LocalDate.parse(String s);
  static LocalDate? tryParse(Object? s);
  /// Takes the y/m/d FIELDS of [dt] as they are (no zone conversion).
  factory LocalDate.fromDateTime(DateTime dt);

  final int year, month, day;
  int get weekday;                         // ISO 1 = Monday .. 7 = Sunday (== WorkingHours.weekday)
  LocalDate addDays(int days);
  LocalDate addMonths(int months);         // clamps the day (31 Jan + 1 month = 28/29 Feb)
  int daysUntil(LocalDate other);          // other - this, in days
  LocalDate get mondayOfWeek;
  LocalDate get firstOfMonth;
  LocalDate get lastOfMonth;
  bool isBefore(LocalDate o); bool isAfter(LocalDate o);
  bool isSameMonth(LocalDate o);
  /// DateTime.utc(year, month, day) (for arithmetic only).
  DateTime toUtcMidnight();
  String toIso();                          // '2026-10-17'
  @override String toString() => toIso();
  // ==, hashCode, compareTo by (year, month, day)
}
```

### 9.2 `HmTime`

```dart
@immutable
final class HmTime implements Comparable<HmTime> {
  const HmTime(this.hour, this.minute);    // 0..23, 0..59 (asserted)
  /// 'HH:MM' or 'HH:MM:SS' ('9:05' accepted). Throws FormatException.
  factory HmTime.parse(String s);
  static HmTime? tryParse(Object? s);
  factory HmTime.fromMinutes(int minutesOfDay);   // 570 -> 09:30 (mod 1440)
  final int hour, minute;
  int get minutesOfDay;
  String format();     // '09:30'
  String toWire();     // '09:30:00' (working_hours / time_off writes)
  // ==, hashCode, compareTo
}
```

### 9.3 `BizTime`

```dart
/// An instant plus the business's fixed UTC offset. Never use DateTime.toLocal() for business times:
/// the device zone is irrelevant, the business zone (business.timezone, fallback Asia/Tashkent) rules.
@immutable
final class BizTime implements Comparable<BizTime> {
  const BizTime(this.utc, this.offset, this.timezone);
  final DateTime utc;          // isUtc == true
  final Duration offset;       // +05:00 for Asia/Tashkent
  final String timezone;       // 'Asia/Tashkent'
  /// utc + offset, still flagged isUtc; its FIELDS are the business wall clock. Internal helper; prefer the getters.
  DateTime get wall;
  int get year; int get month; int get day; int get hour; int get minute;
  int get weekday;             // ISO 1..7, business-local
  LocalDate get date;          // business-local calendar day
  HmTime get time;
  String get hhmm;             // '10:00'
  int get minutesOfDay;
  // ==, hashCode, compareTo by utc
}
```

### 9.4 `Dates`

```dart
abstract final class Dates {
  static const String defaultTimezone = 'Asia/Tashkent';

  /// Fixed offsets (no DST anywhere in this table). Unknown or null zone -> Asia/Tashkent (+5),
  /// the same fallback the backend uses.
  static const Map<String, Duration> fixedOffsets = {
    'Asia/Tashkent': Duration(hours: 5),
    'Asia/Samarkand': Duration(hours: 5),
    'Asia/Dushanbe': Duration(hours: 5),
    'Asia/Ashgabat': Duration(hours: 5),
    'Asia/Almaty': Duration(hours: 5),
    'Asia/Bishkek': Duration(hours: 6),
    'Europe/Moscow': Duration(hours: 3),
    'UTC': Duration.zero,
    'Etc/UTC': Duration.zero,
  };

  /// Also understands '+05:00', '+0500', 'UTC+5', 'GMT+05:00'.
  static Duration offsetOf(String? timezone);

  /// API datetime -> DateTime (isUtc true).
  /// - 'Y-m-d H:i:s' WITHOUT offset (starts_at, ends_at, start_utc, last_visit, next_at) is UTC:
  ///   '2026-10-17 05:00:00' -> DateTime.utc(2026, 10, 17, 5, 0, 0). (DateTime.parse would read it as device-local.)
  /// - 'YYYY-MM-DDTHH:MM:SS' without offset: UTC as well.
  /// - ISO with 'Z' or ±HH:MM: honoured, returned as UTC.
  /// - int / numeric string: unix seconds (created_at, updated_at, replied_at, expires_at).
  /// - null, '', '0000-00-00 00:00:00', garbage -> null.
  static DateTime? parseUtc(Object? value);

  static DateTime? fromUnix(Object? seconds);      // int|num|numeric string; 0 or negative -> null
  static int toUnix(DateTime instant);             // seconds, floor
  /// 'Y-m-d H:i:s' in UTC (converts non-UTC input with toUtc()). Used for POST starts_at and appointment ranges.
  static String formatApiUtc(DateTime instant);

  static BizTime toBizLocal(DateTime instant, [String? timezone]);
  static LocalDate localDateOf(DateTime instant, [String? timezone]);
  static LocalDate todayLocal({String? timezone, DateTime? now});
  /// Business wall clock -> UTC instant. (2026-10-17, 10:00, Tashkent) -> 2026-10-17 05:00:00Z.
  static DateTime localToUtc(LocalDate date, HmTime time, [String? timezone]);
  /// Local 00:00 of [date] as UTC. (2026-10-17, Tashkent) -> 2026-10-16 19:00:00Z.
  static DateTime startOfLocalDayUtc(LocalDate date, [String? timezone]);
}
```

### 9.5 `UzDates` (Uzbek Latin formatters; match the web exactly)

```dart
abstract final class UzDates {
  static const List<String> monthsFull = ['yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
    'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr'];          // apps/admin/src/lib/datetime.js
  static const List<String> monthsShort = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn',
    'iyl', 'avg', 'sen', 'okt', 'noy', 'dek'];                           // apps/booking/src/format.js
  /// Index 0 = Monday (ISO weekday - 1).
  static const List<String> weekdaysLong = ['Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba'];
  static const List<String> weekdaysShort = ['Dush', 'Sesh', 'Chor', 'Pay', 'Jum', 'Shan', 'Yak']; // booking day strip
  static const List<String> weekdaysMin = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];             // calendar headers

  static String weekdayLong(int isoWeekday);
  static String weekdayShort(int isoWeekday);
  static String weekdayMin(int isoWeekday);
  static String monthFull(int month);
  static String monthShort(int month);

  static String dayMonth(LocalDate d);              // '17 oktabr'
  static String dayMonthShort(LocalDate d);         // '17 okt'
  static String dayMonthYear(LocalDate d);          // '17 oktabr 2026'
  static String weekdayDayMonth(LocalDate d);       // 'Shanba, 17 oktabr'
  static String hhmm(BizTime t);                    // '09:30'
  static String timeRange(BizTime start, BizTime end); // '09:00 – 09:40' (U+2013 with spaces)

  /// 'Bugun' (d == today), 'Ertaga' (+1), 'Kecha' (-1), else null.
  static String? relativeDay(LocalDate d, {required LocalDate today});
  /// relativeDay ?? dayMonth, plus ' YYYY' when d.year != today.year: 'Bugun', 'Ertaga', '17 oktabr', '3 yanvar 2027'.
  static String dayLabel(LocalDate d, {required LocalDate today});
  /// '<dayLabel>, HH:MM': 'Bugun, 10:00', 'Ertaga, 09:30', '20 oktabr, 18:00'.
  static String dateTime(BizTime t, {required LocalDate today});
  /// apps/admin formatWeekRange: same month '13 - 19 iyul'; across months '29 iyun - 5 iyul'.
  static String weekRange(LocalDate monday);
  /// apps/booking duration(): 30 -> '30 daqiqa', 60 -> '1 soat', 90 -> '1 soat 30 daqiqa', 0 -> '0 daqiqa'.
  static String duration(int minutes);
  /// Review/notification age: < 60 s 'hozirgina'; < 60 min 'N daqiqa oldin'; < 24 h 'N soat oldin';
  /// < 7 days 'N kun oldin'; else dayLabel of the instant's Tashkent date ('12 oktabr' / '12 oktabr 2025').
  static String ago(DateTime instant, {required DateTime now, String? timezone});
}
```

---

## 10. Models

Common contract for every model class below (not repeated per class):

```dart
@immutable
final class X {
  const X({...});                                   // all fields final, named params
  factory X.fromJson(Map<String, dynamic> json);     // tolerant (JsonRead); never throws on fields
  Map<String, dynamic> toJson();                     // fixed point (see §6)
}
```

Notation in the field lists: `Type name; // json: key (source)`. "src" cites where the shape comes
from: **BP** = BACKEND-PLAN.md section, **live** = current PHP/real response.

### 10.1 Enums (`enums.dart`)

Every enum has `final String wire;`, `static X fromWire(String? s)` (unknown → the documented
fallback), and an Uzbek `label`.

```dart
enum AppointmentStatus {
  pending('pending', 'Kutilmoqda'),
  confirmed('confirmed', 'Tasdiqlangan'),
  arrived('arrived', 'Keldi'),
  completed('completed', 'Yakunlandi'),
  noShow('no_show', 'Kelmadi'),
  canceled('canceled', 'Bekor qilindi'),   // one 'l'
  unknown('unknown', "Noma'lum");
  const AppointmentStatus(this.wire, this.label);
  final String wire; final String label;
  static AppointmentStatus fromWire(String? s);          // unknown fallback
  bool get isTerminal;                                   // completed, noShow, canceled
  bool get isLive;                                       // pending, confirmed, arrived
  /// Server AppointmentController::TRANSITIONS (owner/admin, PATCH /v1/appointments/{id}).
  List<AppointmentStatus> get adminNext;
  //   pending   -> confirmed, arrived, completed, noShow, canceled
  //   confirmed -> arrived, completed, noShow, canceled
  //   arrived   -> completed, noShow, canceled
  //   terminal  -> []
  /// Staff table (PATCH /v1/me/appointments/{id}, BP §4.3) = adminNext minus canceled.
  List<AppointmentStatus> get staffNext;
}

enum OrderStatus {
  newOrder('new', 'Yangi'),
  confirmed('confirmed', 'Tasdiqlangan'),
  preparing('preparing', 'Tayyorlanmoqda'),
  ready('ready', 'Tayyor'),
  delivered('delivered', 'Topshirildi'),  // no delivery exists (phase-2 rule): 'handed over'
  cancelled('cancelled', 'Bekor qilingan'),  // two 'l's
  unknown('unknown', "Noma'lum");
  static OrderStatus fromWire(String? s);
  bool get isActive;                         // new, confirmed, preparing, ready (consumer scope=active)
  /// Kanban column order (web Orders.vue): new, confirmed, preparing, ready, delivered, cancelled.
  static const List<OrderStatus> board = [...];
  /// Suggested forward step for a one-tap button: new->confirmed->preparing->ready->delivered; else null.
  OrderStatus? get next;
}

enum Engine {
  slot('slot'), medical('medical'), catalog('catalog'), rental('rental');
  static Engine fromWire(String? s);         // null/unknown -> slot (site legacy payload has no engine)
  /// Storefront is a menu/catalog with orders (MedicalEngine extends CatalogEngine).
  bool get isCatalogStorefront;              // catalog, medical
  /// Admin Timetable shows a staff calendar (not OrdersTimeline).
  bool get hasTimetable;                     // != catalog
  bool get isRental;
  String get appointmentsTerm;               // slot 'Navbatlar', catalog 'Buyurtmalar', medical 'Qabullar', rental 'Ijaralar'
  String get servicesTerm;                   // slot 'Xizmatlar', catalog 'Menyu', medical 'Xizmatlar', rental 'Buyumlar'
  String get staffTerm;                      // slot 'Ustalar', catalog 'Xodimlar', medical 'Shifokorlar', rental 'Xodimlar'
}

enum BizRole {
  owner('business_owner', 'Egasi'), admin('business_admin', 'Administrator'), staff('staff', 'Xodim'), unknown('', "Noma'lum");
  static BizRole fromWire(String? s);
  bool get isManager;                        // owner || admin
}

enum RentalSession { morning('morning', 'Ertalab (10:00–16:00)'), evening('evening', 'Kechqurun (18:00–23:00)');
  static RentalSession? fromWire(String? s); }        // null = full day (10:00–23:00)

enum Gender { male('male', 'Erkak'), female('female', 'Ayol'); static Gender? fromWire(String? s); }

enum ReviewStatus { published('published'), hidden('hidden'); static ReviewStatus fromWire(String? s); } // fallback published

/// Only Payme is exposed in the apps (Click has a suspected tiyin/so'm 100x bug; BP §2f).
enum PaymentProvider { payme('payme'); static PaymentProvider? fromWire(String? s); }
```

Unknown values never throw. `toJson` writes `wire` (`'unknown'` for the fallback member).

### 10.2 Business (`business.dart`)

```dart
/// Compact business subset. Shapes: consumer appointments/orders (BP 4.6: id, slug, name, logo,
/// brand_color, phone, address, map_url, timezone, engine), loyalty (id, slug, name, logo, brand_color),
/// reviews.mine (id, slug, name, logo), me/staff (id, name, slug, engine, timezone, logo). Missing keys -> null.
final class BusinessRef {
  final int id;                 // json: id
  final String slug;            // json: slug ('' if missing)
  final String name;            // json: name
  final String? logo;           // json: logo
  final String? brandColor;     // json: brand_color ('#RRGGBB')
  final String? phone;          // json: phone
  final String? address;        // json: address
  final String? mapUrl;         // json: map_url
  final String? timezone;       // json: timezone (null -> use Dates.defaultTimezone)
  final Engine engine;          // json: engine (null -> slot)
}

/// Directory card (BP 4.4 GET /v1/directory/businesses; also consumer favorites).
final class BusinessCard {
  final int id;                     // json: id
  final String slug;                // json: slug
  final String name;                // json: name
  final String? category;           // json: category (barber|cafe|restaurant|clinic|rental|...)
  final String? categoryLabel;      // json: category_label
  final Engine engine;              // json: engine
  final String? tagline;            // json: tagline
  final String? logo;               // json: logo
  final String? cover;              // json: cover
  final String? brandColor;         // json: brand_color
  final String? brandColor2;        // json: brand_color_2
  final String? address;            // json: address
  final String? city;               // json: city
  final String? district;           // json: district
  final double? lat;                // json: lat (float, or decimal string, or null)
  final double? lng;                // json: lng
  final double ratingAvg;           // json: rating_avg
  final int ratingCount;            // json: rating_count
  final bool isFeatured;            // json: is_featured
  final bool onlineBookingEnabled;  // json: online_booking_enabled
  final int? priceFromTiyin;        // json: price_from_tiyin
  final bool isFavorite;            // json: is_favorite (always present; false when anonymous)
  bool get hasLocation => lat != null && lng != null;
  BusinessCard copyWith({bool? isFavorite});
}

/// GET /v1/directory/businesses/{slug} -> data.business. Every card field + detail fields.
final class BusinessDetail {
  final BusinessCard card;          // parsed from the SAME map (card keys)
  final String? phone;              // json: phone
  final String? mapUrl;             // json: map_url
  final String? description;        // json: description
  final String timezone;            // json: timezone (fallback 'Asia/Tashkent')
  final String? telegramBotUsername;// json: telegram_bot_username
  final List<OpeningHours> hours;   // json: hours
  // toJson(): card.toJson() merged with the detail keys (flat, as on the wire)
}

final class OpeningHours {
  final int weekday;                // json: weekday (ISO 1..7)
  final HmTime open;                // json: open  'HH:MM'
  final HmTime close;               // json: close 'HH:MM'
}

/// Whole GET /v1/directory/businesses/{slug} payload.
final class BusinessPage {
  final BusinessDetail business;    // json: business
  final RatingSummary rating;       // json: rating {avg, count, distribution}
  final List<Review> reviewsPreview;// json: reviews_preview
  final bool isFavorite;            // json: is_favorite
  BusinessPage copyWith({bool? isFavorite});   // also updates business.card.isFavorite
}

/// GET /v1/directory/categories item (BP 4.4).
final class Category {
  final String key;                 // json: key (barber|cafe|restaurant|clinic|rental)
  final String label;               // json: label
  final String? labelRu;            // json: label_ru
  final Engine engine;              // json: engine
  final String icon;                // json: icon (scissors|cake|utensils|stethoscope|rings)
  final int count;                  // json: count
}

/// GET /v1/site/{slug} -> business (SlotEngine::businessPayload / BusinessPresenter::site, live).
/// The legacy branch omits address/branding: all nullable.
final class SiteBusiness {
  final int id;                     // json: id
  final String name;                // json: name
  final String slug;                // json: slug
  final String? category;           // json: category
  final String? phone;              // json: phone
  final String? address;            // json: address
  final String? mapUrl;             // json: map_url
  final String timezone;            // json: timezone (fallback 'Asia/Tashkent')
  final bool onlineBookingEnabled;  // json: online_booking_enabled (default true when missing)
  final String? tagline;            // json: tagline
  final String? logo;               // json: logo
  final String? cover;              // json: cover
  final String? brandColor;         // json: brand_color
  final String? brandColor2;        // json: brand_color_2
}

/// Business-app membership (login/me businesses[]; live AuthController).
final class BusinessMembership {
  final int id;                     // json: id
  final String name;                // json: name
  final String slug;                // json: slug
  final String? category;           // json: category
  final Engine engine;              // json: engine
  final String? logo;               // json: logo
  final BizRole role;               // json: role
}
```

### 10.3 Catalog (`catalog.dart`)

```dart
/// Service / menu item / rental item. Raw AR row (live: all columns) on /v1/services and /v1/site/{slug}.
final class Service {
  final int id;                     // json: id
  final int? businessId;            // json: business_id
  final int? categoryId;            // json: category_id
  final String name;                // json: name
  final int durationMin;            // json: duration_min (default 30)
  final int priceTiyin;             // json: price_tiyin
  final int? depositTiyin;          // json: deposit_tiyin (null/0 = no prepayment)
  final bool isActive;              // json: is_active (0/1)
  final bool onlineBookable;        // json: online_bookable (0/1)
  final String? image;              // json: image
  final String? description;        // json: description
  final List<String> gallery;       // json: gallery (null -> [])
  final DateTime? createdAt;        // json: created_at (unix)
  final DateTime? updatedAt;        // json: updated_at (unix)
  bool get requiresDeposit => (depositTiyin ?? 0) > 0;
  /// Body for POST/PATCH /v1/services: name, category_id, duration_min, price_tiyin, deposit_tiyin,
  /// is_active, online_bookable, image, description, gallery.
  Map<String, dynamic> toInput();
}

final class ServiceCategory {
  final int id;                     // json: id
  final int? businessId;            // json: business_id
  final String name;                // json: name
  final int sort;                   // json: sort
  final String? image;              // json: image
  Map<String, dynamic> toInput();   // {name, sort, image}
}

/// Staff member. Shapes: business GET /v1/staff (live: id, business_id, user_id, name, specialization,
/// is_active, created_at, updated_at, commission_percent); public site (BP 4.5: id, name, specialization);
/// GET /v1/me/staff (BP 4.3: + business {id,name,slug,engine,timezone,logo}).
final class Staff {
  final int id;                     // json: id
  final int? businessId;            // json: business_id
  final int? userId;                // json: user_id
  final String name;                // json: name
  final String? specialization;     // json: specialization
  final int? commissionPercent;     // json: commission_percent (0..100)
  final bool isActive;              // json: is_active (default true when missing)
  final DateTime? createdAt;        // json: created_at
  final DateTime? updatedAt;        // json: updated_at
  final BusinessRef? business;      // json: business (me/staff only)
  /// Body for POST/PATCH /v1/staff: name, specialization, is_active, commission_percent.
  Map<String, dynamic> toInput();
}
```

### 10.4 Storefront and availability (`storefront.dart`)

```dart
/// GET /v1/site/{slug}. slot/rental: business, services, staff. catalog/medical: business, categories, items.
final class StorefrontData {
  final Engine engine;                    // json: engine (missing -> slot)
  final SiteBusiness business;            // json: business
  final List<Service> services;           // json: services ([] for catalog engines or when booking is off)
  final List<Staff> staff;                // json: staff (public shape)
  final List<CatalogCategory> categories; // json: categories (catalog engines)
  final List<Service> items;              // json: items (catalog engines, all active)
}

final class CatalogCategory {
  final int id;                     // json: id (0 = 'Boshqa', uncategorised)
  final String name;                // json: name
  final String? image;              // json: image
  final List<Service> items;        // json: items
}

/// GET /v1/staff/{id}/availability (live).
final class Availability {
  final LocalDate date;             // json: date (business-local)
  final String timezone;            // json: timezone
  final List<AvailabilitySlot> slots; // json: slots
}

final class AvailabilitySlot {
  final DateTime startUtc;          // json: start_utc 'Y-m-d H:i:s' UTC -> echo back as POST starts_at
  final DateTime endUtc;            // json: end_utc
  final HmTime startLocal;          // json: start_local 'HH:MM'
  /// 'morning' < 12:00, 'afternoon' < 17:00, else 'evening' (booking SPA slotBucket).
  String get bucket;
}

/// GET /v1/site/{slug}/booked-days -> {"booked": {"2026-11-14": ["evening"]}}; empty may be {} or [].
final class BookedDays {
  final Map<LocalDate, Set<RentalSession>> booked;   // json: booked
  bool isFullyBooked(LocalDate d);                   // both sessions taken
  bool isTaken(LocalDate d, RentalSession? session); // session null (full day) = any session taken
  // toJson(): {'booked': {iso: [wire, ...]}} (sessions sorted morning, evening)
}
```

### 10.5 Appointment (`appointment.dart`)

One class covers both shapes:
- **business shape** (`Appointment::fields()`, live + BP 4.3): flat `staff_id`, `service_id`,
  `client_name`, `client_phone`, `service_name`, `service_duration`, `staff_name`, `items`;
- **consumer shape** (BP 4.6): nested `business`, `staff{id,name}`, `service{id,name,duration_min,price_tiyin}`
  plus `can_cancel`, `can_review`, `review_id`.

Parsing prefers the flat key and falls back to the nested one.

```dart
final class Appointment {
  final int id;                       // json: id
  final int? businessId;              // json: business_id ?? business.id
  final int? clientId;                // json: client_id
  final int? consumerId;              // json: consumer_id
  final int staffId;                  // json: staff_id ?? staff.id
  final int serviceId;                // json: service_id ?? service.id
  final int? guests;                  // json: guests (rental)
  final DateTime startsAt;            // json: starts_at (UTC 'Y-m-d H:i:s'); missing -> epoch 0 UTC
  final DateTime endsAt;              // json: ends_at
  final AppointmentStatus status;     // json: status
  final String? source;               // json: source (admin|link|telegram|app)
  final int? depositTiyin;            // json: deposit_tiyin
  final bool paid;                    // json: paid (0/1/bool)
  final String? notes;                // json: notes
  final DateTime? createdAt;          // json: created_at (unix)
  final DateTime? updatedAt;          // json: updated_at (unix)
  final String? clientName;           // json: client_name
  final String? clientPhone;          // json: client_phone
  final String? serviceName;          // json: service_name ?? service.name
  final int? serviceDuration;         // json: service_duration ?? service.duration_min
  final int? servicePriceTiyin;       // json: service.price_tiyin (consumer shape only)
  final String? staffName;            // json: staff_name ?? staff.name
  final List<AppointmentItem> items;  // json: items ([] when missing)
  final BusinessRef? business;        // json: business (consumer shape)
  final bool? canCancel;              // json: can_cancel (consumer shape)
  final bool? canReview;              // json: can_review
  final int? reviewId;                // json: review_id

  bool get requiresDeposit => (depositTiyin ?? 0) > 0 && !paid;
  Duration get duration => endsAt.difference(startsAt);
  BizTime startLocal([String? timezone]);   // timezone ?? business?.timezone ?? Asia/Tashkent
  BizTime endLocal([String? timezone]);
  Appointment copyWith({AppointmentStatus? status, bool? paid, bool? canCancel, bool? canReview, int? reviewId});
  /// toJson writes every flat key above, plus 'business' (BusinessRef.toJson or null),
  /// 'service' {id, name, duration_min, price_tiyin} only when servicePriceTiyin != null,
  /// 'staff' {id, name} only when business != null (consumer shape), and can_cancel/can_review/review_id.
}

/// Appointment line (live AppointmentItem: all columns).
final class AppointmentItem {
  final int id;                       // json: id
  final int? businessId;              // json: business_id
  final int? appointmentId;           // json: appointment_id
  final String kind;                  // json: kind ('service' | 'product')
  final int? refId;                   // json: ref_id
  final String name;                  // json: name
  final int qty;                      // json: qty (default 1)
  final int priceTiyin;               // json: price_tiyin
  final DateTime? createdAt;          // json: created_at
  int get totalTiyin => qty * priceTiyin;
}
```

### 10.6 Order (`order.dart`)

```dart
/// Order::fields() (live: id, status, total_tiyin, customer_name, customer_phone, note, source,
/// created_at, items, items_count) + consumer extras (BP 4.6: business, can_cancel, can_review, review_id).
final class Order {
  final int id;                       // json: id
  final OrderStatus status;           // json: status
  final int totalTiyin;               // json: total_tiyin
  final String? customerName;         // json: customer_name
  final String? customerPhone;        // json: customer_phone
  final String? note;                 // json: note
  final String? source;               // json: source (site|bot|admin|app)
  final DateTime? createdAt;          // json: created_at (unix)
  final List<OrderItem> items;        // json: items
  final int itemsCount;               // json: items_count (fallback items.length)
  final BusinessRef? business;        // json: business (consumer only)
  final bool? canCancel;              // json: can_cancel
  final bool? canReview;              // json: can_review
  final int? reviewId;                // json: review_id
  Order copyWith({OrderStatus? status, bool? canCancel, bool? canReview, int? reviewId});
}

final class OrderItem {
  final int id;                       // json: id
  final int? serviceId;               // json: service_id
  final String name;                  // json: name
  final int priceTiyin;               // json: price_tiyin
  final int qty;                      // json: qty
  int get totalTiyin => qty * priceTiyin;
}
```

### 10.7 Client (`client.dart`, owner/admin only)

```dart
/// GET /v1/clients rows (live: id, name, phone, email, birthday, tags, created_at, visits, spent_tiyin,
/// last_visit, categories) and GET /v1/clients/{id} -> client (all columns: + business_id, notes, updated_at).
final class Client {
  final int id;                       // json: id
  final int? businessId;              // json: business_id
  final String name;                  // json: name
  final String phone;                 // json: phone
  final String? email;                // json: email
  final LocalDate? birthday;          // json: birthday 'Y-m-d'
  final String? notes;                // json: notes
  final List<String> tags;            // json: tags (array or JSON string)
  final DateTime? createdAt;          // json: created_at
  final DateTime? updatedAt;          // json: updated_at
  final int? visits;                  // json: visits (list only)
  final int? spentTiyin;              // json: spent_tiyin (list only)
  final DateTime? lastVisit;          // json: last_visit (UTC 'Y-m-d H:i:s', list only)
  final List<ClientCategory> categories; // json: categories (list only; [] otherwise)
  /// Body for POST/PATCH /v1/clients: name, phone (normalized), email, birthday, notes, tags.
  Map<String, dynamic> toInput();
}

final class ClientCategory {
  final int id;                       // json: id
  final String name;                  // json: name
  final String? color;                // json: color '#hex'
  final int? sort;                    // json: sort (client-categories index only)
}

final class ClientLoyalty {
  final int points;                   // json: points
  final int cashbackTiyin;            // json: cashback_tiyin
}

/// GET /v1/clients/{id}.
final class ClientDetail {
  final Client client;                // json: client
  final List<ClientCategory> categories; // json: categories
  final List<Appointment> history;    // json: history (last 20)
  final ClientLoyalty? loyalty;       // json: loyalty (optional)
}
```

### 10.8 Review (`review.dart`)

```dart
/// One class for ReviewPresenter::public (BP 4.4), ::mine (BP 4.6) and the business list (BP 4.7).
final class Review {
  final int id;                       // json: id
  final int rating;                   // json: rating 1..5
  final String? comment;              // json: comment
  final String authorName;            // json: author_name
  final String? serviceName;          // json: service_name
  final String? staffName;            // json: staff_name
  final String? reply;                // json: reply
  final DateTime? repliedAt;          // json: replied_at (unix)
  final DateTime? createdAt;          // json: created_at (unix)
  final ReviewStatus? status;         // json: status (mine + business)
  final int? appointmentId;           // json: appointment_id (mine + business)
  final int? orderId;                 // json: order_id (mine + business)
  final int? staffId;                 // json: staff_id (business)
  final int? serviceId;               // json: service_id (business)
  final BusinessRef? business;        // json: business {id, slug, name, logo} (mine)
  bool get hasReply => reply != null && reply!.isNotEmpty;
  Review copyWith({String? reply, DateTime? repliedAt, int? rating, String? comment});
}

/// detail `rating` {avg, count, distribution} and reviews list `meta` {avg, count, distribution}.
final class RatingSummary {
  final double avg;                   // json: avg
  final int count;                    // json: count
  final Map<int, int> distribution;   // json: distribution {"1":0,...,"5":12}; always has keys 1..5 (missing -> 0)
  static const RatingSummary empty;
  factory RatingSummary.fromMeta(PageMeta meta);   // reads meta.extra
  /// Share of [stars] in 0..1 (0 when count == 0), for the distribution bars.
  double share(int stars);
  // toJson(): {'avg', 'count', 'distribution': {'1': n, ... '5': n}}
}
```

### 10.9 Consumer (`consumer.dart`)

```dart
/// ConsumerUser::fields() (BP 3.2: id, phone, name, birthday, gender, city, locale, created_at) + GET /me stats.
final class ConsumerUser {
  final int id;                       // json: id
  final String phone;                 // json: phone
  final String? name;                 // json: name
  final LocalDate? birthday;          // json: birthday
  final Gender? gender;               // json: gender
  final String? city;                 // json: city
  final String locale;                // json: locale ('uz' | 'ru', default 'uz')
  final DateTime? createdAt;          // json: created_at
  final ConsumerStats? stats;         // json: stats (GET/PATCH /v1/consumer/me only)
  /// name ?? Phone.format(phone)
  String get displayName;
}

final class ConsumerStats {
  final int appointmentsUpcoming;     // json: appointments_upcoming
  final int appointmentsTotal;        // json: appointments_total
  final int ordersTotal;              // json: orders_total
  final int reviewsTotal;             // json: reviews_total
  final int favoritesTotal;           // json: favorites_total
}

/// POST /v1/consumer/auth/otp.
final class OtpSent {
  final bool sent;                    // json: sent
  final int ttlSec;                   // json: ttl_sec (120)
  final int retryAfterSec;            // json: retry_after_sec (60)
}

/// POST /v1/consumer/auth/verify.
final class ConsumerSession {
  final String token;                 // json: token (typ=consumer, 30 days)
  final DateTime? expiresAt;          // json: expires_at (unix)
  final bool isNew;                   // json: is_new
  final ConsumerUser consumer;        // json: consumer
}

/// GET /v1/consumer/loyalty item.
final class LoyaltyWalletEntry {
  final BusinessRef business;         // json: business {id, slug, name, logo, brand_color}
  final int clientId;                 // json: client_id
  final int points;                   // json: points
  final int cashbackTiyin;            // json: cashback_tiyin
  final int depositBalanceTiyin;      // json: deposit_balance_tiyin
  final int visits;                   // json: visits
}
```

### 10.10 Business auth (`auth.dart`)

```dart
/// users row minus password_hash (live: id, phone, name, status, created_at, updated_at, is_superadmin 0/1).
final class BizUser {
  final int id;                       // json: id
  final String phone;                 // json: phone
  final String name;                  // json: name
  final int status;                   // json: status (10 active)
  final bool isSuperadmin;            // json: is_superadmin (0/1)
  final DateTime? createdAt;          // json: created_at
  final DateTime? updatedAt;          // json: updated_at
}

/// `active` in login/me/switch (BP 4.1).
final class ActiveContext {
  final int? businessId;              // json: business_id
  final BizRole? role;                // json: role (null when no active business)
  final int? staffId;                 // json: staff_id (NEW; null if not linked)
  final List<String> permissions;     // json: permissions (NEW; missing -> Permissions.forRole(role))
  bool get hasBusiness => businessId != null;
  bool get isOwner; bool get isAdmin; bool get isStaff; bool get isManager;
  bool get hasStaffProfile => staffId != null;
  bool can(String permission) => permissions.contains(permission);
  /// The business app's shell: manager shell when role is owner/admin; staff shell when role is staff
  /// (staff without staffId sees the "profile not linked" screen + orders if permitted).
}

/// POST /v1/auth/login (BP 4.1).
final class AuthSession {
  final String token;                 // json: token
  final DateTime? expiresAt;          // json: expires_at (NEW; fallback JwtClaims.exp)
  final BizUser user;                 // json: user
  final List<BusinessMembership> businesses; // json: businesses
  final ActiveContext active;         // json: active
  BusinessMembership? get activeBusiness;    // businesses.firstWhereOrNull(id == active.businessId)
  AuthSession withMe(AuthMe me);              // replaces user, businesses, active; keeps token
  AuthSession withSwitch(SwitchResult s);     // replaces token, expiresAt, active
}

/// GET /v1/auth/me.
final class AuthMe {
  final BizUser user;                 // json: user
  final ActiveContext active;         // json: active
  final List<BusinessMembership> businesses; // json: businesses
}

/// POST /v1/auth/switch/{businessId}.
final class SwitchResult {
  final String token;                 // json: token
  final DateTime? expiresAt;          // json: expires_at
  final ActiveContext active;         // json: active
}
```

### 10.11 Team (`team.dart`)

```dart
/// GET /v1/team item, POST response, PATCH response (BP 4.2). PATCH returns only user_id, role, staff_id.
final class TeamMember {
  final int userId;                   // json: user_id
  final String? name;                 // json: name
  final String? phone;                // json: phone
  final BizRole role;                 // json: role
  final int? staffId;                 // json: staff_id
}
```

### 10.12 Schedule (`schedule.dart`)

```dart
/// GET /v1/staff/{id}/working-hours (live: id, staff_id, weekday, start_time 'HH:MM:SS', end_time)
/// and me/schedule.working_hours (BP 4.3: no staff_id).
final class WorkingHours {
  final int? id;                      // json: id
  final int? staffId;                 // json: staff_id
  final int weekday;                  // json: weekday ISO 1..7 (NOT 0 for Sunday)
  final HmTime start;                 // json: start_time
  final HmTime end;                   // json: end_time
}

/// GET /v1/staff/{id}/time-off (live: id, staff_id, date, start_time|null, end_time|null, reason) and me/schedule.time_off.
final class TimeOff {
  final int? id;                      // json: id
  final int? staffId;                 // json: staff_id
  final LocalDate date;               // json: date
  final HmTime? start;                // json: start_time (null + end null = whole day)
  final HmTime? end;                  // json: end_time
  final String? reason;               // json: reason
  bool get isFullDay => start == null && end == null;
}

/// GET /v1/me/schedule.
final class MeSchedule {
  final List<WorkingHours> workingHours;  // json: working_hours
  final List<TimeOff> timeOff;            // json: time_off
}
```

### 10.13 Reports (`reports.dart`)

```dart
/// appointments counters: analytics.appointments and me/stats.appointments.
final class AppointmentCounts {
  final int total, pending, confirmed, arrived, completed, noShow, canceled; // json: total, pending, confirmed, arrived, completed, no_show, canceled
}

/// GET /v1/analytics/overview (live AnalyticsController, owner/admin).
final class AnalyticsOverview {
  final int revenueTiyin;                       // json: revenue_tiyin
  final AppointmentCounts appointments;         // json: appointments
  final double noShowRate;                      // json: no_show_rate (percent, e.g. 6.25)
  final int clientsTotal;                       // json: clients.total
  final int clientsNew;                         // json: clients.new
  final List<AnalyticsPoint> series;            // json: series
  final List<TopServiceRow> topServices;        // json: top_services
  final List<StaffLoadRow> staffLoad;           // json: staff_load
  // toJson writes 'clients': {'total', 'new'}
}
final class AnalyticsPoint { final LocalDate date; final int revenueTiyin; final int appointments; } // json: date (UTC day), revenue_tiyin, appointments
final class TopServiceRow { final int serviceId; final String name; final int count; final int revenueTiyin; } // json: service_id, name, count, revenue_tiyin
final class StaffLoadRow { final int staffId; final String name; final int count; final int revenueTiyin; }   // json: staff_id, name, count, revenue_tiyin

/// GET /v1/payroll (live, owner/admin).
final class PayrollReport {
  final List<PayrollRow> staff;                 // json: staff
  final int totalRevenueTiyin;                  // json: totals.revenue_tiyin
  final int totalEarningsTiyin;                 // json: totals.earnings_tiyin
}
final class PayrollRow {
  final int staffId;                            // json: staff_id
  final String name;                            // json: name
  final int commissionPercent;                  // json: commission_percent
  final int appointments;                       // json: appointments (completed count)
  final int revenueTiyin;                       // json: revenue_tiyin
  final int earningsTiyin;                      // json: earnings_tiyin
}

/// GET /v1/finance/summary (live, owner/admin).
final class FinanceSummary {
  final LocalDate? from;                        // json: from
  final LocalDate? to;                          // json: to
  final int incomeTiyin;                        // json: income_tiyin
  final int refundsTiyin;                       // json: refunds_tiyin
  final int netTiyin;                           // json: net_tiyin
  final int count;                              // json: count
  final List<FinanceProviderRow> byProvider;    // json: by_provider
}
final class FinanceProviderRow { final String provider; final int amountTiyin; final int count; } // json: provider, amount_tiyin, count

/// GET /v1/finance/transactions rows (live; values may be strings: parse tolerantly).
final class FinanceTransaction {
  final int id;                                 // json: id
  final String provider;                        // json: provider (payme|click)
  final String type;                            // json: type (deposit|refund|float)
  final String status;                          // json: status (created|pending|paid|canceled|refunded)
  final int amountTiyin;                        // json: amount_tiyin
  final DateTime? createdAt;                    // json: created_at (unix)
  final int? appointmentId;                     // json: appointment_id
  final String? clientName;                     // json: client_name
  final String? serviceName;                    // json: service_name
  /// Uzbek labels: type deposit 'Depozit', refund 'Qaytarish', float 'Ustama'; status created 'Yaratildi',
  /// pending 'Kutilmoqda', paid "To'langan", canceled 'Bekor qilindi', refunded 'Qaytarildi'.
  String get typeLabel; String get statusLabel;
}

/// GET /v1/me/stats (BP 4.3).
final class MeStats {
  final LocalDate from;                         // json: range.from
  final LocalDate to;                           // json: range.to
  final String timezone;                        // json: range.timezone
  final int staffId;                            // json: staff.id
  final String staffName;                       // json: staff.name
  final int commissionPercent;                  // json: staff.commission_percent
  final AppointmentCounts appointments;         // json: appointments
  final int revenueTiyin;                       // json: revenue_tiyin
  final int earningsTiyin;                      // json: earnings_tiyin
  final int clientsServed;                      // json: clients_served
  final List<MeStatsPoint> series;              // json: series
  final int todayTotal;                         // json: today.total
  final int todayCompleted;                     // json: today.completed
  final DateTime? todayNextAt;                  // json: today.next_at (UTC string or null)
  // toJson writes nested 'range', 'staff', 'today' exactly as on the wire
}
final class MeStatsPoint {
  final LocalDate date; final int count; final int completed; final int revenueTiyin; final int earningsTiyin;
  // json: date (business-local), count, completed, revenue_tiyin, earnings_tiyin
}
```

### 10.14 Settings (`settings.dart`)

```dart
/// GET/PUT /v1/settings/booking (live keys + BP 4.8 additions + PUT-only telegram_webhook_ok/telegram_error).
final class BookingSettings {
  final String name;                  // json: name
  final String? phone;                // json: phone
  final String? tagline;              // json: tagline
  final String slug;                  // json: slug
  final bool onlineBookingEnabled;    // json: online_booking_enabled
  final int bookingLeadMin;           // json: booking_lead_min
  final int bookingHorizonDays;       // json: booking_horizon_days
  final String? logo;                 // json: logo
  final String? cover;                // json: cover
  final String? brandColor;           // json: brand_color
  final String? brandColor2;          // json: brand_color_2
  final bool telegramConnected;       // json: telegram_connected (read-only)
  final String? telegramBotUsername;  // json: telegram_bot_username (read-only)
  final String? address;              // json: address (NEW)
  final String? mapUrl;               // json: map_url (NEW)
  final String? city;                 // json: city (NEW)
  final String? district;             // json: district (NEW)
  final double? lat;                  // json: lat (NEW)
  final double? lng;                  // json: lng (NEW)
  final String? description;          // json: description (NEW)
  final bool isListed;                // json: is_listed (NEW, default true)
  final double ratingAvg;             // json: rating_avg (NEW, read-only)
  final int ratingCount;              // json: rating_count (NEW, read-only)
  final bool? telegramWebhookOk;      // json: telegram_webhook_ok (only right after a token PUT)
  final String? telegramError;        // json: telegram_error

  static const Set<String> writableKeys = {'name', 'phone', 'tagline', 'slug', 'online_booking_enabled',
    'booking_lead_min', 'booking_horizon_days', 'logo', 'cover', 'brand_color', 'brand_color_2',
    'address', 'map_url', 'city', 'district', 'lat', 'lng', 'description', 'is_listed'};

  /// Partial PUT body: only writable keys whose value differs from [original]; a value cleared to
  /// null/'' is sent as null (server clears it). Empty map = nothing to save.
  Map<String, dynamic> diff(BookingSettings original);
  BookingSettings copyWith({...every writable field...});
  /// Telegram connect/disconnect body: {'telegram_bot_token': token} ('' disconnects).
  static Map<String, dynamic> telegramTokenBody(String token);
}
```

`copyWith` for nullable fields uses the sentinel pattern (`Object? logo = _keep`) so a field can be
set to null.

### 10.15 Payments (`payment.dart`)

```dart
/// Transaction (live fields() hides business_id, external_id, idempotency_key).
final class PaymentTransaction {
  final int id;                       // json: id
  final int? appointmentId;           // json: appointment_id
  final String provider;              // json: provider
  final int amountTiyin;              // json: amount_tiyin
  final String type;                  // json: type
  final String status;                // json: status
  final DateTime? createdAt;          // json: created_at
  final DateTime? updatedAt;          // json: updated_at
}

/// POST /v1/payments/deposit (payme) response.
final class DepositCheckout {
  final PaymentTransaction transaction; // json: transaction
  final String provider;                // json: provider
  final Uri? checkoutUrl;               // json: checkout_url (open with url_launcher, external app)
}
```

Deposit flow (both apps): `POST Endpoints.paymentsDeposit` body `{"appointment_id": id, "provider": "payme"}`,
`idempotencyKey: Idempotency.deposit(id)`, `auth: RequestAuth.none`; open `checkoutUrl`; then poll
`GET /v1/consumer/appointments/{id}` (Bizcat) every 5 s for up to 2 min, or until `paid == true`.

### 10.16 Request bodies (`requests.dart`)

All have `Map<String, dynamic> toJson()` that **omits null keys**.

```dart
/// POST /v1/consumer/appointments (BP 4.6). Use with idempotencyKey.
final class ConsumerBookingRequest {
  /// {"staff_id","service_id","starts_at":'Y-m-d H:i:s' UTC,"notes"?,"name"?}
  const ConsumerBookingRequest.slot({required int staffId, required int serviceId, required DateTime startsAt, String? notes, String? name});
  /// {"staff_id","service_id","date":'YYYY-MM-DD',"session"?: 'morning'|'evening' (null = full day),"guests"?,"notes"?,"name"?}
  const ConsumerBookingRequest.rental({required int staffId, required int serviceId, required LocalDate date, RentalSession? session, int? guests, String? notes, String? name});
}

/// POST /v1/appointments with an owner/admin token (admin mode; no slot check).
/// {"staff_id","service_id","starts_at" | "date"+"session","guests"?,"client_id"? | "client":{"phone" (normalized),"name"},"notes"?,"status"?}
final class AdminBookingRequest {
  const AdminBookingRequest({required int staffId, required int serviceId, DateTime? startsAt, LocalDate? date,
    RentalSession? session, int? guests, int? clientId, String? clientName, String? clientPhone, String? notes, AppointmentStatus? status});
  // assert: startsAt != null || date != null; clientId != null || clientPhone != null
}

/// POST /v1/consumer/orders: {"slug","items":[{"service_id","qty"}],"note"?,"name"?}
final class ConsumerOrderRequest {
  const ConsumerOrderRequest({required String slug, required List<OrderLine> items, String? note, String? name});
}
final class OrderLine { const OrderLine(this.serviceId, this.qty); final int serviceId; final int qty; } // {"service_id","qty"}

/// POST /v1/consumer/reviews: exactly one of appointmentId / orderId (asserted).
/// PATCH /v1/consumer/reviews/{id}: use toPatchJson() -> {"rating","comment"}.
final class ReviewInput {
  const ReviewInput({this.appointmentId, this.orderId, required this.rating, this.comment});
  Map<String, dynamic> toPatchJson();
}

/// PATCH /v1/consumer/me: any subset of name, birthday ('Y-m-d'), gender, city, locale.
final class ConsumerProfilePatch {
  const ConsumerProfilePatch({String? name, LocalDate? birthday, Gender? gender, String? city, String? locale});
}

/// POST /v1/team: {"phone" (normalized),"name","role","password"?,"staff_id"?}
final class TeamMemberInput {
  const TeamMemberInput({required String phone, required String name, required BizRole role, String? password, int? staffId});
}
/// PATCH /v1/team/{userId}: {"role"?, "staff_id"?}. unlinkStaff:true sends "staff_id": null explicitly.
final class TeamMemberPatch {
  const TeamMemberPatch({BizRole? role, int? staffId, bool unlinkStaff = false});
}

/// POST /v1/staff/{id}/time-off: {"date","start_time"?,"end_time"?,"reason"?} (times as 'HH:MM:SS').
final class TimeOffInput {
  const TimeOffInput({required LocalDate date, HmTime? start, HmTime? end, String? reason});
}

/// PUT /v1/staff/{id}/working-hours: {"items":[{"weekday":1..7,"start_time":"09:00:00","end_time":"18:00:00"}]}.
/// Replaces the whole week; days without an entry are days off. NEVER the web's {days:[...]} shape.
final class WorkingHoursInput {
  const WorkingHoursInput(List<WorkingHours> days);
}
```

---

## 11. How the apps wire it (informative)

```dart
// Bizcat
final apiProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    config: ApiConfig.fromEnvironment(),
    tokenKind: TokenKind.consumer,
    tokenStore: SecureTokenStore(const FlutterSecureStorage(), 'bizcat_consumer_token'),
    onUnauthorized: (_) => ref.read(sessionProvider.notifier).signedOut(),
  );
  ref.onDispose(client.close);
  return client;
});

final page = await api.getPage(Endpoints.directoryBusinesses, BusinessCard.fromJson,
    query: {'q': q, 'category': cat, 'sort': 'featured', ...ApiQuery.page(1)});

final res = await api.request<Appointment>('POST', Endpoints.consumerAppointments,
    body: ConsumerBookingRequest.slot(staffId: 2, serviceId: 11, startsAt: slot.startUtc).toJson(),
    idempotencyKey: bookingKey, decode: (d) => Appointment.fromJson(JsonRead.object(d)));
// res.isCreated (201) or res.isReplay (200): both are success.

// TizBiz Biznes, staff "my day"
final today = Dates.todayLocal(timezone: business.timezone);
final list = await api.getList(Endpoints.meAppointments, Appointment.fromJson,
    query: ApiQuery.localDays(from: today, to: today));
```

---

## 12. Unit tests (`test/`)

Run: `cd mobile/tizbiz_core && ~/development/flutter/bin/dart pub get && ~/development/flutter/bin/dart analyze --fatal-infos && ~/development/flutter/bin/dart test`.
All must pass with zero analyzer issues. Tests never hit the network.

### `test/support/fake_adapter.dart`
`FakeAdapter implements HttpClientAdapter`: queue of `(int status, String body, Map<String, List<String>> headers)` or a
`DioException` to throw; records every `RequestOptions` (method, uri, headers, decoded body) in `requests`.
Helper `ApiClient testClient({TokenKind kind, TokenStore? store, UnauthorizedHandler? onUnauthorized, DateTime? now})`.

### `test/support/fixtures.dart`
`const` raw JSON strings, copied verbatim from BACKEND-PLAN.md §4 (login, me, switch, team, me/staff,
me/appointments, me/stats, me/schedule, directory categories/list/detail/reviews, consumer verify,
me, appointments, orders, loyalty, business reviews, deposit) and from the live local API
(staff with `is_active:1`, services with `online_bookable:1` and `gallery:null`, working-hours with
`'09:00:00'`, availability, analytics, payroll, finance summary, settings, login with `is_superadmin:0`).

### `test/money_test.dart`
- `Money.format(15000000) == "150 000 so'm"`
- `Money.format(5000000) == "50 000 so'm"`; `Money.format(0) == "0 so'm"`; `Money.format(99) == "1 so'm"`; `Money.format(49) == "0 so'm"`
- `Money.format(5000050) == "50 001 so'm"` (half away from zero)
- `Money.format(-1500000) == "-15 000 so'm"`; `Money.format(null) == '—'`
- `Money.format(150000000000) == "1 500 000 000 so'm"`
- `Money.format(15000000, withCurrency: false) == '150 000'`; `Money.format(15000000, separator: ' ') == "150 000 so'm"`
- `Money.group(1234567) == '1 234 567'`; `Money.group(999) == '999'`; `Money.group(-1000) == '-1 000'`
- `Money.toSom(2000000) == 20000`; `Money.fromSom(50) == 5000`; `Money.fromSom(12.5) == 1250`
- `Money.compact(15000000) == "150 ming so'm"`; `Money.compact(150000000) == "1,5 mln so'm"`; `Money.compact(100000000) == "1 mln so'm"`; `Money.compact(250000000000) == "2,5 mlrd so'm"`; `Money.compact(95000) == "950 so'm"`
- `Money.parseSomInput('150 000') == 15000000`; `('150 000') == 15000000`; `('1 500,50') == 150050`; `('12.5') == 1250`; `('') == null`; `('abc') == null`; `('1,2,3') == null`

### `test/phone_test.dart`
- normalize: `'+998 90 123 45 67'`, `'998901234567'`, `'901234567'`, `'(90) 123-45-67'`, `'8 90 123 45 67'` all → `'+998901234567'`; `'12345' → null`; `null → null`; `'' → null`
- isValid: `'901234567'` true; `'+998901234567'` true; `'12345678'` false; `'+7 901 234 56 78'` false (11 digits)
- `format('+998901234567') == '+998 90 123 45 67'`; `format('abc') == 'abc'`; `formatLocal('+998901234567') == '90 123 45 67'`
- formatPartial: `'9'→'9'`, `'90'→'90'`, `'901'→'90 1'`, `'90123'→'90 123'`, `'9012345'→'90 123 45'`, `'901234567'→'90 123 45 67'`, `'+998901234567'→'90 123 45 67'`, `'9012345678'→'90 123 45 67'`
- `mask('+998901234567') == '+998 90 *** ** 67'`; `telUri('90 123 45 67').toString() == 'tel:+998901234567'`

### `test/local_date_test.dart`
- `LocalDate.parse('2026-10-17')` fields; `toIso()` round trip; `LocalDate.parse('2026-10-17 05:00:00') == LocalDate(2026,10,17)`; `parse('17.10.2026')` throws; `tryParse(null) == null`
- weekday: `2026-10-17` is 6 (Saturday); `2026-10-19` is 1; `2026-10-18` is 7
- `addDays(15)` across month/year (`2026-12-25 + 7 == 2027-01-01`); `mondayOfWeek` of `2026-10-18` is `2026-10-12`
- `addMonths(1)` of `2026-01-31` is `2026-02-28`; `lastOfMonth` of `2028-02-10` is `2028-02-29`
- `daysUntil`, ordering (`sort()`), `==`/`hashCode` usable as Map key

### `test/hm_time_test.dart`
- `HmTime.parse('09:00:00') == HmTime(9,0)`; `parse('9:05').format() == '09:05'`; `toWire() == '09:05:00'`; `fromMinutes(570).format() == '09:30'`; `parse('24:00')` throws; ordering

### `test/dates_test.dart`
- `parseUtc('2026-10-17 05:00:00') == DateTime.utc(2026,10,17,5)` and `.isUtc` true
- `parseUtc('2026-10-17T05:00:00')` same; `parseUtc('2026-10-17T10:00:00+05:00') == DateTime.utc(2026,10,17,5)`; `parseUtc('2026-10-17T05:00:00Z')` same
- `parseUtc(1792054800) == DateTime.fromMillisecondsSinceEpoch(1792054800000, isUtc: true)`; `parseUtc('1792054800')` same
- `parseUtc(null)`, `parseUtc('')`, `parseUtc('0000-00-00 00:00:00')`, `parseUtc('garbage')` → null
- `formatApiUtc(DateTime.utc(2026,10,17,5)) == '2026-10-17 05:00:00'`; non-UTC input converted (`DateTime.utc(...).toLocal()` → same string)
- `toBizLocal(DateTime.utc(2026,10,17,5), 'Asia/Tashkent')`: hour 10, minute 0, `date == LocalDate(2026,10,17)`, `hhmm == '10:00'`
- day rollover: `toBizLocal(DateTime.utc(2026,10,16,19,30)).date == LocalDate(2026,10,17)`, hhmm `'00:30'`
- `offsetOf(null) == 5h`; `offsetOf('Europe/Moscow') == 3h`; `offsetOf('Mars/Base') == 5h`; `offsetOf('+06:00') == 6h`; `offsetOf('UTC+3') == 3h`
- `localToUtc(LocalDate(2026,10,17), HmTime(10,0)) == DateTime.utc(2026,10,17,5)`
- `startOfLocalDayUtc(LocalDate(2026,10,17)) == DateTime.utc(2026,10,16,19)`
- `todayLocal(now: DateTime.utc(2026,10,16,19,0,1)) == LocalDate(2026,10,17)`; `now: DateTime.utc(2026,10,16,18,59,59)` → `2026-10-16`

### `test/api_query_test.dart`
- `appointments(from: 2026-10-17, to: 2026-10-17)` → `{'from':'2026-10-16 19:00:00','to':'2026-10-17 18:59:59'}`; with `staffId: 2, status: confirmed` adds `'staff':2,'status':'confirmed'`; null keys absent
- `orders(from: 2026-10-17, to: 2026-10-17)` → `from == 1792177200` (2026-10-16 19:00Z), `to == 1792263600` (exclusive next local midnight)
- `utcDays` / `localDays` → `{'from':'2026-10-01','to':'2026-10-17'}`; `localDays()` → `{}`
- `availability(date: 2026-10-19, serviceId: 2)` → `{'date':'2026-10-19','service_id':2}`; `page(2, perPage: 50)` → `{'page':2,'per_page':50}`

### `test/uz_dates_test.dart`
- `dayMonth(2026-10-17) == '17 oktabr'`; `dayMonth(2026-09-01) == '1 sentabr'`; `dayMonthShort(2026-07-18) == '18 iyl'`; `dayMonthYear(2026-10-17) == '17 oktabr 2026'`
- `weekdayLong(1) == 'Dushanba'`, `weekdayLong(7) == 'Yakshanba'`, `weekdayShort(6) == 'Shan'`, `weekdayMin(3) == 'Ch'`; `weekdayDayMonth(2026-10-17) == 'Shanba, 17 oktabr'`
- relativeDay with today 2026-10-17: same → 'Bugun'; 10-18 → 'Ertaga'; 10-16 → 'Kecha'; 10-20 → null
- `dayLabel(2027-01-03, today: 2026-10-17) == '3 yanvar 2027'`; `dayLabel(2026-10-20, ...) == '20 oktabr'`
- `dateTime(toBizLocal(2026-10-17 05:00Z), today: 2026-10-17) == 'Bugun, 10:00'`; next day → `'Ertaga, 10:00'`
- `timeRange(10:00, 10:40) == '10:00 – 10:40'`
- `weekRange(2026-07-13) == '13 - 19 iyul'`; `weekRange(2026-06-29) == '29 iyun - 5 iyul'`
- `duration(30) == '30 daqiqa'`, `(60) == '1 soat'`, `(90) == '1 soat 30 daqiqa'`, `(0) == '0 daqiqa'`
- ago with now = 2026-10-17 07:00Z: 30 s → 'hozirgina'; 5 min → '5 daqiqa oldin'; 3 h → '3 soat oldin'; 2 days → '2 kun oldin'; 10 days → '7 oktabr'; 400 days → `'12 sentabr 2025'`

### `test/json_read_test.dart`
- `integer(1) == 1`, `integer('12') == 12`, `integer('12.0') == 12`, `integer(12.9) == 12`, `integer(null) == 0`, `integer('x', 7) == 7`, `integerOrNull('') == null`
- `numberOrNull('41.2756000') == 41.2756`, `numberOrNull(69) == 69.0`, `numberOrNull(null) == null`
- `boolean(1)`, `boolean('1')`, `boolean(true)`, `boolean('TRUE')` true; `boolean(0)`, `boolean('0')`, `boolean(null)` false
- `object([]) == {}`; `object('x')` throws FormatException; `objectOrNull([]) == null`
- `stringList(['a','b'])`, `stringList('["a","b"]')` → `['a','b']`; `stringList(null) == []`
- `list(null, f) == []`, `list({}, f) == []`, `list([{'id':1}, 'junk'], f)` → one item
- `nonEmptyOrNull('  ') == null`

### `test/jwt_claims_test.dart`
Build tokens in the test (`base64Url` of header/payload, dummy signature).
- payload `{"iss":"tizbiz.uz","iat":1792187436,"exp":1792792236,"sub":4,"tid":2,"role":"business_owner"}` (the live token, no typ) → `kind == TokenKind.biz`, `typ == 'biz'`, `sub == 4`, `tenantId == 2`, `expiresAt == DateTime.utc(...)` from 1792792236
- `"typ":"consumer"` → consumer; `"typ":"x"` → unknown
- `tryParse('abc')`, `tryParse('a.b')`, `tryParse('a.!!!.c')`, `tryParse(null)` → null; payload without base64 padding parses
- `isExpired(now)` true at `exp - 10s` (30 s leeway), false at `exp - 60s`; no exp → false

### `test/idempotency_test.dart`
- `newKey()` matches `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`; 1000 keys are unique; `newKey(Random(1)) == newKey(Random(1))`
- `deposit(5012) == 'dep-5012-payme'`

### `test/permissions_test.dart` and `test/enums_test.dart`
- `forRole('business_owner') == Permissions.all`; admin = all minus `team.manage` (15 items, contains `finance`); staff = `['orders','me']`; `forRole(null) == []`; `forRole('consumer') == []`
- `AppointmentStatus.fromWire('no_show') == noShow`; `fromWire('cancelled') == unknown` (one 'l' only); `canceled.isTerminal`
- `pending.adminNext == [confirmed, arrived, completed, noShow, canceled]`; `confirmed.staffNext == [arrived, completed, noShow]`; `arrived.staffNext == [completed, noShow]`; `completed.adminNext == []`
- `OrderStatus.fromWire('new') == newOrder`; `fromWire('canceled') == unknown` (orders use 'cancelled'); `newOrder.next == confirmed`; `delivered.next == null`; `board.length == 6`
- `Engine.fromWire(null) == slot`, `fromWire('xyz') == slot`, `fromWire('rental') == rental`; `medical.isCatalogStorefront` true; `catalog.hasTimetable` false
- `BizRole.fromWire('business_admin').isManager` true; `RentalSession.fromWire(null) == null`

### `test/api_client_test.dart`
1. GET unwrap: body `{"data":{"x":1}}` → returns `{'x':1}`; request URL is `https://api.test/v1/auth/me` (base `https://api.test/` trailing slash trimmed); header `Accept: application/json`.
2. Envelope with meta: `getPage` on `{"data":[{"id":1}],"meta":{"page":1,"per_page":20,"total":5,"pages":1}}` → 1 item, `meta.total == 5`, `hasMore == false`; reviews meta with `avg/count/distribution` lands in `meta.extra` and `RatingSummary.fromMeta` reads it.
3. `getPage` without meta → `PageMeta.single(n)`; `getList` with `{"data":[]}` and with `{"data":{}}` → `[]`.
4. 204 empty body on `delete` → completes with null.
5. Token attach: store holds a biz token, client kind biz → `Authorization: Bearer <t>`; `RequestAuth.none` → no Authorization.
6. Kind mismatch: consumer client, store holds a biz token → no Authorization header AND store cleared; `setToken(bizToken)` on a consumer client throws `ArgumentError`.
7. Expired token (clock after exp) → not attached, store cleared, `onUnauthorized` not called.
8. 401 with token: response `{"errors":[{"status":"401","title":"Unauthorized","detail":"Your request was made with invalid credentials."}]}` → throws `ApiException` with `isUnauthorized`, `message == 'Sessiya tugadi. Qaytadan kiring.'`; store cleared; hook called once. Two concurrent 401s for the same token → hook called once.
9. 401 on `login` with `RequestAuth.none` → `detail == "Telefon yoki parol noto'g'ri."`, hook NOT called, store untouched.
10. 422 with pointers: two items (`phone`, `items[2].end_time`) → `fieldErrors == {'phone': ..., 'items[2].end_time': ...}`, `isValidation`, `message` = first item detail.
11. 422 generic (no pointer, `"Bu bron uchun oldindan to'lov talab qilinmaydi."`) → `fieldErrors` empty, `isValidation`, `message` = that detail.
12. 409 → `isConflict`, `detail == 'Tanlangan vaqt band.'`; `toString()` contains `409`.
13. 403 `No active business selected.` → `message == 'Faol biznes tanlanmagan.'`; 403 `Insufficient role for this action.` → `"Bu amal uchun ruxsatingiz yo'q."`
14. 429 with header `Retry-After: 42` → `retryAfter == Duration(seconds: 42)`, `isRateLimited`.
15. Error body `{"errors":[{"status":"409","title":"Error","detail":""}]}` (lost `{ok:false}` text) → `message == "Amalni bajarib bo'lmadi: ma'lumot o'zgargan."`.
16. Non-JSON 500 (`<html>`) → `ApiException(kind http, status 500, isServer)`, Uzbek fallback message.
17. Transport: adapter throws `DioException(type: connectionTimeout)` → `kind timeout`, `status 0`, `isNetwork`; `connectionError` → `kind network`, message `"Internet aloqasi yo'q. Qayta urinib ko'ring."`; cancel → `isCancelled`.
18. Idempotency: `post(..., idempotencyKey: 'k1')` sends header `Idempotency-Key: k1` and `Content-Type: application/json`; JSON body decoded equals input.
19. Replay: `request('POST', ...)` with status 200 → `isReplay`; 201 → `isCreated`.
20. Query encoding: `{'a': null, 'b': true, 'c': LocalDate(2026,10,17), 'd': DateTime.utc(2026,10,17,5), 'e': AppointmentStatus.noShow, 'f': 3}` → URL query `b=1&c=2026-10-17&d=2026-10-17+05%3A00%3A00&e=no_show&f=3` (no `a`).
21. Only allowed headers are ever sent: every recorded request's header names ⊆ {`accept`, `content-type`, `authorization`, `idempotency-key`} (CORS guard).
22. `uploadImage(bytes, filename: 'a.jpg', contentType: 'image/jpeg')` sends multipart with field `file` and part content type `image/jpeg`; returns `data.url`.
23. `log` sink receives `'GET /v1/me/stats -> 200 (N ms)'` and the line never contains the token or the body.

### `test/models/*_test.dart` (one file per model file)
For every fixture: `fromJson` succeeds, spot-check fields, and the fixed-point property
`DeepCollectionEquality().equals(X.fromJson(x.toJson()).toJson(), x.toJson())`. Required spot checks:
- **auth**: login fixture → `user.isSuperadmin == false` from `0`; `active.staffId == null`; `permissions` contains `team.manage`; `businesses.first.engine == Engine.slot`; `activeBusiness?.slug == 'shox-barber'`. Legacy login (no `expires_at`, no `staff_id`, no `permissions`, role `staff`) → `expiresAt == null`, `permissions == ['orders','me']`. `withSwitch` replaces token/active; `withMe` keeps token.
- **team**: GET item with `staff_id: 2`; PATCH response `{"user_id":31,"role":"staff","staff_id":2}` → name/phone null.
- **catalog**: live service (`is_active:1`, `online_bookable:1`, `gallery:null`, `deposit_tiyin:1000000`) → bools true, gallery `[]`, `requiresDeposit`; `toInput()` keys exactly the 10 listed. Staff public shape `{id,name,specialization}` → `isActive == true`, `userId == null`. me/staff → `business.timezone == 'Asia/Tashkent'`, `commissionPercent == 40`.
- **storefront**: slot payload (with `staff` public items) and catalog payload (`categories[0].id == 0`, no `staff` key → `[]`); payload without `engine` → `Engine.slot`. Availability → first slot `startUtc == DateTime.utc(2026,10,19,4)`, `startLocal == HmTime(9,0)`, bucket `'morning'`. BookedDays `{"booked":{"2026-11-14":["morning","evening"],"2026-11-15":["evening"]}}` → `isFullyBooked(11-14)`, `isTaken(11-15, morning) == false`, `isTaken(11-15, null) == true`; `{"booked":[]}` → empty.
- **appointment**: me/appointments item → `startsAt == DateTime.utc(2026,10,17,5)`, `status == confirmed`, `paid == true`, `staffName == 'Usta Jahongir'`, `serviceDuration == 40`, `business == null`; `startLocal().hhmm == '10:00'`. Consumer item → `staffId == 2` (from nested), `serviceName == 'Soch olish + soqol'`, `servicePriceTiyin == 8000000`, `business.slug == 'shox-barber'`, `canCancel == false`. Item with `paid: 0` and `deposit_tiyin: 2000000` → `requiresDeposit`. Missing `items` → `[]`.
- **order**: business order (no business key) and consumer order (`items_count:1`, `can_cancel:true`, `status 'new'` → `OrderStatus.newOrder`).
- **client**: list row with `tags` as `'["vip"]'` string and `last_visit:'2026-10-01 06:00:00'`; detail with `history` and `loyalty` absent → `loyalty == null`.
- **review**: public item (`replied_at` unix), mine item with `business`, business item with `staff_id`; `RatingSummary` with distribution missing key `"2"` → `distribution[2] == 0`; `share(5) == 0.8` for 12/15.
- **business**: directory card with `lat: 41.2756` and a second with `lat: "41.2756000"` → both `41.2756`; `rating_avg: 4.73`; `copyWith(isFavorite: true)`. Detail → `hours.first.open == HmTime(9,0)`, `reviewsPreview.length == 1`. Category list (2 items). `BusinessPage.copyWith(isFavorite: true)` also flips `business.card.isFavorite`.
- **consumer**: verify → `token`, `isNew == false`, `consumer.gender == Gender.female`; GET me → `stats.favoritesTotal == 2`, `birthday == LocalDate(1996,4,12)`; OtpSent; loyalty entry → `cashbackTiyin == 1500000`.
- **schedule**: live working hours (`'09:00:00'`) → `start == HmTime(9,0)`; me/schedule time-off with null times → `isFullDay`; `WorkingHoursInput([...]).toJson()` → `{'items':[{'weekday':1,'start_time':'09:00:00','end_time':'20:00:00'}]}` (no `id`, no `staff_id`).
- **reports**: analytics fixture (series zero-filled, `no_show_rate: 0` int → `0.0`); payroll (`totals`); finance summary (`from` → LocalDate); finance transaction with string values (`"id":"301"`, `"amount_tiyin":"2000000"`) → ints; me/stats (`todayNextAt == DateTime.utc(2026,10,17,9,30)`, `series.first.earningsTiyin == 9600000`, toJson re-nests `range`/`staff`/`today`).
- **settings**: live settings without the NEW keys → `isListed == true`, `lat == null`; `diff`: change `tagline` and clear `map_url` → `{'tagline': 'X', 'map_url': null}`; unchanged → `{}`; read-only `rating_avg` never in a diff.
- **payment**: deposit response → `checkoutUrl.host == 'checkout.paycom.uz'`, `transaction.amountTiyin == 2000000`.
- **requests**: `ConsumerBookingRequest.slot(staffId:2, serviceId:11, startsAt: DateTime.utc(2026,10,18,5), notes:'Soqolni qisqa qiling', name: 'Aziza')` → exactly BP 4.6 slot body; `.rental(..., date: 2026-11-14, session: evening, guests: 180)` → `{'staff_id':5,'service_id':40,'date':'2026-11-14','session':'evening','guests':180}`; `.rental(session: null)` has no `session` key. `AdminBookingRequest(clientPhone: '90 111 11 11', clientName: 'Ali', ...)` → `client.phone == '+998901111111'`. `ReviewInput(rating: 5)` without ids → `AssertionError`; `ReviewInput(appointmentId: 4990, rating: 5, comment: 'Juda yoqdi!').toJson()` exact. `TeamMemberPatch(unlinkStaff: true).toJson() == {'staff_id': null}`; `TeamMemberPatch(role: BizRole.staff).toJson() == {'role': 'staff'}`. `ConsumerProfilePatch(locale: 'ru').toJson() == {'locale': 'ru'}`. `TimeOffInput(date: 2026-10-25, reason: 'Dam olish')` → `{'date':'2026-10-25','reason':'Dam olish'}`.

---

## 13. Done criteria

1. `dart analyze --fatal-infos` clean; `dart test` green; `grep -r "package:flutter" lib test` and
   `grep -rE "dart:(io|html)" lib` both empty.
2. Every model in §10 exists with the listed fields, `fromJson` and `toJson`, and has a fixture test.
3. `bizcat` and `mobile-app` both add the path dependency and `flutter build web` succeeds for each
   with `tizbiz_core` imported (verifies web compatibility of dio + the package).
4. No model field, endpoint path or query encoding is defined in either app; they come from here.
