# Backend plan: mobile apps (Bizcat consumer and TizBiz Biznes)

Status: **source of truth** for backend implementers (B1, B2) and for the Flutter developers
(`bizcat/`, `mobile-app/`, `mobile/tizbiz_core`). Written 2026-10-17 against the working tree
of `main` (including the uncommitted rental/address/guests changes listed in `git status`).

Everything here is **additive** Yii2 code that follows the existing conventions:
`common\rest\Controller`, the `common\rest\Envelope` envelope, `common\db\Migration`, and
module `bootstrap()` URL rules. All money is integer **tiyin**. All `starts_at` and `ends_at`
values are UTC `Y-m-d H:i:s` strings. All `created_at` and `updated_at` values are unix
seconds (int).

---

## 0. Ground rules and facts the plan relies on

These facts were checked in the code.

| Fact | Where |
|---|---|
| JWT = HS256, claims `iss, iat, exp, sub, tid, role`; no `typ`; ttl 7 days (`params['jwt.ttl']`) | `common/components/Jwt.php`, `common/config/params.php` |
| `User::findIdentityByAccessToken` trusts `tid` and `role` from the token. It never re-reads `business_user`. | `common/models/User.php:101-112` |
| `requireRole()` compares `$user->activeRole` (the token claim) | `common/rest/Controller.php:70-76` |
| Tenant scoping applies only when `tid !== null` | `common/db/ActiveRecord.php:32-42` |
| `HttpBearerAuth` on an `authOptional()` action **swallows** a 401, so the caller becomes anonymous | yii2 2.0.55 `filters/auth/AuthMethod.php:63-67` |
| `AuthMethod::$user` can point at any `yii\web\User` instance. A consumer identity can therefore use its own component. | same file, line 32 |
| Envelope `code` is only the numeric exception code. String error codes are not possible without changing the Envelope, so this plan uses none. | `common/rest/Envelope.php` |
| CORS allowed headers lack `Idempotency-Key`, which breaks Flutter **web** | `common/rest/Controller.php:31`, `common/rest/Cors.php:28` |
| `AppointmentController::upsertClient` looks up `Client` by the RAW phone | `api/modules/booking/controllers/AppointmentController.php` (private `upsertClient`) |
| Any authed business token on `POST v1/appointments` = admin mode (no slot/past checks, status override). This includes staff tokens and `tid=null` tokens. | `AppointmentController::actionCreate` (`$isPublic = $this->currentUser() === null`) |
| `SlotEngine::publicData()` returns raw `Staff` AR, which exposes `user_id` and `commission_percent` | `common/engines/SlotEngine.php` |
| `Business` has no `fields()` whitelist (it contains `telegram_bot_token`) | `common/models/Business.php` |
| Register stores the `engine` that the client sends. `Register.vue` sends `rental -> 'slot'`. | `api/modules/auth/controllers/AuthController.php::actionRegister`, `apps/corporate/src/views/Register.vue:12` |
| Real SMS sender exists: `api\modules\notify\services\SmsSender::send(string $phone, string $text): bool`. It returns false and logs a warning when it is not configured. | `api/modules/notify/services/SmsSender.php` |
| `orders.business_id`/`client_id` are `integer` (not bigint); every other id is `bigint` | `console/migrations/m260810_090000_create_orders.php` |
| Local dev DB is **MySQL 5.7.39** (MAMP); prod is **MariaDB 10.11**. Use no functional indexes, no CHECK constraints and no FULLTEXT. | `common/config/main-local.php`, `SELECT version()` |
| Local DB has NOT applied `m260917_120000` / `m260917_140000` yet (no `businesses.address`). `yii migrate` will apply them first. | local DB |
| Demo slugs differ by environment: prod has `shox-barber, aziza-tortlari, restoran, sanatrix, serenada`; local has `barber, tort, restoran, klinika, ijara` | `SeedController::actionDaily` defaults vs local `businesses` |

**Module ids and namespaces assumed.** The orchestrator registers these in `api/config/main.php`,
under `modules` AND in the `bootstrap` array:

| Module id | Class | Owner |
|---|---|---|
| `me` | `api\modules\me\Module` (`controllerNamespace = 'api\modules\me\controllers'`) | B1 |
| `consumer` | `api\modules\consumer\Module` (`controllerNamespace = 'api\modules\consumer\controllers'`) | B2 |
| `directory` | `api\modules\directory\Module` (`controllerNamespace = 'api\modules\directory\controllers'`) | B2 |

Business-side reviews do **not** get their own module. They live in the existing `crm` module as
`api\modules\crm\controllers\ReviewController`, with routes added to `api/modules/crm/Module.php`
(B2). Nobody else edits `api/config/main.php`.

---

## 1. Migrations

All migrations go in `console/migrations/`, in the global namespace, with `use common\db\Migration;`,
`public function safeUp(): void` / `safeDown(): void`, and `$this->tableOptions()` as the 3rd
`createTable` argument. Every PK is `bigPrimaryKey()` and every FK column is `bigInteger()`. The
index and FK names follow `idx-<table>-<cols>`, `uq-<table>-<cols>` and `fk-<table>-<ref>`.

Apply order is by filename. The two uncommitted `m260917_*` migrations run before these.

### 1.1 `m261017_100000_add_directory_fields_to_businesses.php` (B2)

`addColumn('{{%businesses}}', ...)`:

| Column | Type | Default | Position |
|---|---|---|---|
| `city` | `string(64)->null()` | NULL | after `map_url` |
| `district` | `string(64)->null()` | NULL | after `city` |
| `lat` | `decimal(10,7)->null()` | NULL | after `district` |
| `lng` | `decimal(10,7)->null()` | NULL | after `lat` |
| `description` | `text()->null()` | NULL | after `tagline` |
| `is_listed` | `boolean()->notNull()->defaultValue(true)` | 1 | after `status` |
| `rating_avg` | `decimal(3,2)->notNull()->defaultValue(0)` | 0.00 | after `is_listed` |
| `rating_count` | `integer()->notNull()->defaultValue(0)` | 0 | after `rating_avg` |
| `featured_until` | `integer()->null()` | NULL (unix ts) | after `rating_count` |

Indexes:
- `idx-businesses-directory` on (`status`, `is_listed`, `category`)
- `idx-businesses-city` on (`city`)
- `idx-businesses-rating` on (`rating_avg`)

`safeDown`: drop the indexes, then drop the columns in reverse order.

### 1.2 `m261017_100100_create_consumer_users.php` (B2)

Table `{{%consumer_users}}`:

| Column | Type |
|---|---|
| `id` | `bigPrimaryKey()` |
| `phone` | `string(32)->notNull()`: canonical `+998XXXXXXXXX`; after deletion it becomes `deleted-<id>` |
| `name` | `string(128)->null()` |
| `birthday` | `date()->null()` |
| `gender` | `string(8)->null()`: `male` or `female` |
| `city` | `string(64)->null()` |
| `locale` | `string(5)->notNull()->defaultValue('uz')`: `uz` or `ru` |
| `status` | `smallInteger()->notNull()->defaultValue(10)`: 10 active, 0 blocked/deleted |
| `last_login_at` | `integer()->null()` |
| `deleted_at` | `integer()->null()` |
| `created_at` | `integer()->notNull()` |
| `updated_at` | `integer()->notNull()` |

Indexes: `uq-consumer_users-phone` UNIQUE (`phone`).

### 1.3 `m261017_100200_create_consumer_otp_codes.php` (B2)

Table `{{%consumer_otp_codes}}`:

| Column | Type |
|---|---|
| `id` | `bigPrimaryKey()` |
| `phone` | `string(32)->notNull()` |
| `code_hash` | `char(64)->notNull()`: `hash_hmac('sha256', phone.'|'.code, params['jwt.secret'])` |
| `attempts` | `smallInteger()->notNull()->defaultValue(0)` |
| `expires_at` | `integer()->notNull()` |
| `consumed_at` | `integer()->null()` |
| `ip` | `string(45)->null()` |
| `created_at` | `integer()->notNull()` |

Indexes: `idx-consumer_otp_codes-phone-created` (`phone`, `created_at`) and
`idx-consumer_otp_codes-ip-created` (`ip`, `created_at`). No FK.

### 1.4 `m261017_100300_create_consumer_favorites.php` (B2)

Table `{{%consumer_favorites}}`: `id` bigPK, `consumer_id` bigint notNull, `business_id` bigint
notNull, `created_at` integer notNull.
- `uq-consumer_favorites-consumer-business` UNIQUE (`consumer_id`, `business_id`)
- `idx-consumer_favorites-business` (`business_id`)
- `fk-consumer_favorites-consumer` -> `consumer_users.id` CASCADE/CASCADE
- `fk-consumer_favorites-business` -> `businesses.id` CASCADE/CASCADE

### 1.5 `m261017_100400_add_consumer_id_to_appointments_orders.php` (B2)

- `appointments.consumer_id` `bigInteger()->null()->after('client_id')`
  - `idx-appointments-consumer` (`consumer_id`, `starts_at`)
  - `fk-appointments-consumer` -> `consumer_users.id` **SET NULL** / CASCADE
- `orders.consumer_id` `bigInteger()->null()->after('client_id')`
  - `idx-orders-consumer` (`consumer_id`, `created_at`)
  - `fk-orders-consumer` -> `consumer_users.id` **SET NULL** / CASCADE

`safeDown`: drop the FKs, indexes and columns.

### 1.6 `m261017_100500_create_reviews.php` (B2)

Table `{{%reviews}}`:

| Column | Type |
|---|---|
| `id` | `bigPrimaryKey()` |
| `business_id` | `bigInteger()->notNull()` |
| `consumer_id` | `bigInteger()->null()` (NULL after account deletion) |
| `appointment_id` | `bigInteger()->null()` |
| `order_id` | `bigInteger()->null()` |
| `staff_id` | `bigInteger()->null()` (snapshot from the appointment; no FK because staff is soft-deleted) |
| `service_id` | `bigInteger()->null()` (snapshot; no FK) |
| `author_name` | `string(64)->notNull()`: masked snapshot, e.g. `Aziza K.` |
| `rating` | `smallInteger()->notNull()`: 1..5 |
| `comment` | `text()->null()` (max 1000 chars, validated) |
| `status` | `string(16)->notNull()->defaultValue('published')`: `published` or `hidden` |
| `reply` | `text()->null()` |
| `replied_at` | `integer()->null()` |
| `replied_by` | `bigInteger()->null()`: users.id |
| `created_at` | `integer()->notNull()` |
| `updated_at` | `integer()->notNull()` |

Indexes and FKs:
- `uq-reviews-appointment` UNIQUE (`appointment_id`): one review per appointment (several NULLs are allowed)
- `uq-reviews-order` UNIQUE (`order_id`): one review per order
- `idx-reviews-business-status-created` (`business_id`, `status`, `created_at`)
- `idx-reviews-consumer-created` (`consumer_id`, `created_at`)
- `fk-reviews-business` -> `businesses.id` CASCADE/CASCADE
- `fk-reviews-consumer` -> `consumer_users.id` SET NULL/CASCADE
- `fk-reviews-appointment` -> `appointments.id` SET NULL/CASCADE
- `fk-reviews-order` -> `orders.id` SET NULL/CASCADE

### 1.7 `m261017_100600_add_unique_user_to_staff.php` (B1)

1. Data fix (driver-agnostic PHP). For each (`business_id`, `user_id`) pair with `user_id IS NOT NULL`
   that has more than one row, keep the lowest `staff.id` and set `user_id = NULL` on the others.
2. `createIndex('uq-staff-business-user', '{{%staff}}', ['business_id', 'user_id'], true)`.
   NULLs are allowed many times.

`safeDown`: `dropIndex('uq-staff-business-user', '{{%staff}}')`.

**Not in this iteration.** Device-token tables (`consumer_devices`, `business_user_devices`) and
notification inbox columns are planned for LATER, when FCM keys exist. Do not create them now.

---

## 2. Security hardening (a) to (h)

### (a) JWT `typ` claim: B1

**`common/components/Jwt.php`** (B1). The new signature is backward compatible:

```php
public const TYP_BIZ = 'biz';
public const TYP_CONSUMER = 'consumer';

/** $ttl null => params['jwt.ttl'] (7 days). */
public static function issue(int $userId, ?int $tenantId = null, ?string $role = null,
                             string $typ = self::TYP_BIZ, ?int $ttl = null): string
// payload adds 'typ' => $typ. All other claims stay the same.

/** Token type from a parsed payload; a missing typ means a legacy business token. */
public static function typ(array $payload): string   // returns $payload['typ'] ?? 'biz'

/** exp of a freshly issued token, for responses: time() + ($ttl ?? params['jwt.ttl']). */
public static function expiresAt(?int $ttl = null): int
```

B2 calls `Jwt::issue($consumer->id, null, null, Jwt::TYP_CONSUMER, (int) Yii::$app->params['consumer.jwt.ttl'])`
and `Jwt::parse()` / `Jwt::typ()`. **B1 lands `Jwt.php` first, as its first commit.** B2 codes
against the signature above.

**`common/models/User.php::findIdentityByAccessToken`** (B1). It returns `null` when
`Jwt::typ($payload) !== 'biz'`. A consumer token on any business endpoint therefore gets 401, and
on an `authOptional` action the caller is anonymous.

**Consumer identity** (B2). `common/models/ConsumerUser.php` implements `IdentityInterface`. Its
`findIdentityByAccessToken` accepts only `typ === 'consumer'`, and only rows with `status = 10`
and `deleted_at IS NULL`. The user component is created lazily by
`common/components/ConsumerAuth.php`:

```php
final class ConsumerAuth {
    /** Registers (once) and returns Yii::$app->consumerUser:
     *  ['class'=>yii\web\User::class,'identityClass'=>ConsumerUser::class,
     *   'enableSession'=>false,'enableAutoLogin'=>false,'loginUrl'=>null] */
    public static function userComponent(): \yii\web\User;
    public static function current(): ?ConsumerUser;   // identity or null
}
```

The consumer and directory controllers replace `$behaviors['authenticator']` with
`['class' => HttpBearerAuth::class, 'user' => ConsumerAuth::userComponent(), 'optional' => $this->authOptional()]`.
`Yii::$app->user` stays empty on those requests. That keeps `tenant` null, so B2 must filter
every query explicitly by `consumer_id` / `business_id`.

### (b) Staff role gates: B1, plus B2 for its own files

Mechanism: add `$this->requireRole(Business::ROLE_OWNER, Business::ROLE_ADMIN);` as the first
line of each action marked **S: deny** in the matrix (§2.9). After (d), roles come from the DB.

Endpoint-by-endpoint changes:

| Controller::action | Before | After | Owner |
|---|---|---|---|
| `payroll/PayrollController::actionIndex` | any member | owner, admin | B1 |
| `analytics/AnalyticsController::actionOverview` | any member | owner, admin | B1 |
| `crm/ClientController::actionIndex`, `actionView` | any member | owner, admin | B1 |
| `crm/ClientCategoryController::actionIndex` | any member | owner, admin | B1 |
| `loyalty/DepositController::actionBalances`, `actionView` | any member | owner, admin | B1 |
| `loyalty/LoyaltyController::actionView` | any member | owner, admin | B1 |
| `loyalty/CertificateController::actionIndex`, `actionView` | any member | owner, admin | B1 |
| `loyalty/LoyaltyRuleController::actionIndex`, `actionView` | any member | owner, admin | B1 |
| `loyalty/DiscountRuleController::actionIndex`, `actionView` | any member | owner, admin | B1 |
| `loyalty/AutoCategoryRuleController::actionIndex`, `actionView` | any member | owner, admin | B1 |
| `loyalty/SubscriptionTypeController::actionIndex`, `actionView` | any member | owner, admin | B1 |
| `loyalty/SettingsController::actionView` | any member | owner, admin | B1 |
| `loyalty/ReferralController::actionIndex`, `actionCreate` | any member (create had NO role check) | owner, admin | B1 |
| `inventory/ProductController::actionIndex`, `actionView`, `actionSummary`, `actionMovements` | any member (exposes `cost_tiyin`) | owner, admin | B1 |
| `auth/TeamController::actionIndex` | any member | owner, admin | B1 |
| `booking/AppointmentController::actionIndex`, `actionView` | any member | owner, admin. Staff use `/v1/me/appointments`. | **B2** |
| `booking/AppointmentController::actionCreate` with a business token | any token = admin mode | owner/admin = admin mode; `staff` -> 403 `Insufficient role for this action.`; token with `tid=null` -> 403 `No active business selected.` | **B2** |
| `catalog/OrderController::actionIndex`, `actionUpdate` | any member / O,A,S | **unchanged: O, A, S allowed** (kitchen board) + `tenant->require()` | **B2** |
| `booking/StaffController::actionIndex`, `actionView` | any member (raw rows expose every colleague's `commission_percent` and `user_id`) | owner, admin | B1 |
| `booking/ServiceController::actionIndex`, `actionView` | any member | owner, admin | B1 |
| `booking/ServiceCategoryController::actionIndex`, `actionView` | any member | owner, admin | B1 |
| `booking/ScheduleController::actionWorkingHours`, `actionTimeOff` (GET) | any member | owner, admin. Staff read their own hours via `GET /v1/me/schedule`. | B1 |
| `booking/SettingsController::actionView` | any member | owner, admin | **B2** (B2 already edits this file for §4.8) |
| `booking/UploadController::actionCreate` | O, A, S | owner, admin | B1 |

Rule used for the staff column: **staff may call exactly what the TizBiz Biznes staff shell calls,
nothing more** (BIZNES-SPEC §10, §6.2 rows 28-33): `POST /v1/auth/login`, `GET /v1/auth/me`,
`POST /v1/auth/switch/{id}`, `GET/PATCH /v1/me/*`, `GET /v1/orders` and `PATCH /v1/orders/{id}`.
Every other tenant route answers 403 to a staff token.

Unchanged and already correct: finance (O,A), payments refund (O,A), every write action (O,A),
team writes (O only), settings update (O,A).

Breaking change, on purpose: staff-role users of the **web admin** keep only the Orders board
(`apps/admin` `Orders.vue` / `OrdersTimeline.vue` call only `/v1/orders`). Every other page
(CRM, analytics, payroll, loyalty, inventory, team, appointments, staff, services, schedule,
booking settings, image upload) answers 403. A front-desk or registrar user needs the
`business_admin` role.

### (c) `tid = null` cross-tenant reads: add `Yii::$app->tenant->require()`

Put the call on the first line of each action or private finder listed here. A finder also covers
the view, update and delete actions that call it.

| File | Action / finder | Owner |
|---|---|---|
| `api/modules/booking/controllers/StaffController.php` | `actionIndex`, `findStaff` | B1 |
| `api/modules/booking/controllers/ServiceController.php` | `actionIndex`, `findService` | B1 |
| `api/modules/booking/controllers/ServiceCategoryController.php` | `actionIndex`, `findCategory` | B1 |
| `api/modules/booking/controllers/ScheduleController.php` | `findStaff` (covers working-hours GET/PUT, time-off GET/POST/DELETE) | B1 |
| `api/modules/loyalty/controllers/LoyaltyRuleController.php` | `actionIndex`, `findRule` | B1 |
| `api/modules/loyalty/controllers/DiscountRuleController.php` | `actionIndex`, `findRule` | B1 |
| `api/modules/loyalty/controllers/AutoCategoryRuleController.php` | `actionIndex`, `findRule` | B1 |
| `api/modules/loyalty/controllers/CertificateController.php` | `actionIndex` (`findCertificate` already has it) | B1 |
| `api/modules/loyalty/controllers/SubscriptionTypeController.php` | `actionIndex` (`findType` already has it) | B1 |
| `api/modules/loyalty/controllers/ReferralController.php` | `actionIndex` | B1 |
| `api/modules/catalog/controllers/OrderController.php` | `actionIndex`, `actionUpdate` | **B2** |

Already present, so no change: `AppointmentController::actionIndex/View`, `TeamController::*`,
`ClientController` (index, `findClient`), `ClientCategoryController` (index, `findCategory`),
`ProductController` (index, summary, `findProduct`), `DepositController::*`,
`LoyaltyController::*`, loyalty `SettingsController::activeRule`, booking
`SettingsController::business()`, `AnalyticsController`, `PayrollController`, `FinanceController`,
`PaymentController::actionRefund`.

### (d) Membership re-check per request: B1

**`common/models/BusinessUser.php`** (B1) adds:

```php
/** Role of $userId in $businessId if the membership exists AND businesses.status = 10, else null.
 *  Cached 60 s under key "bu-role:{$businessId}:{$userId}" (stores '' for "none"). */
public static function activeRole(int $userId, int $businessId): ?string;
public static function forgetRole(int $businessId, int $userId): void;   // cache delete
// afterSave() and afterDelete() call forgetRole($this->business_id, $this->user_id)
```

**`User::findIdentityByAccessToken`** (B1). After loading the user, when `tid !== null`:
1. `$role = BusinessUser::activeRole($user->id, $tid)`
2. If `$role === null`, return `null`. This gives 401 on protected actions and anonymous access on
   optional ones.
3. Otherwise set `$user->activeRole = $role`. The DB value overrides the token claim.

Effect: `DELETE v1/team/<id>` and `PATCH v1/team/<id>` invalidate the cache through
`afterSave`/`afterDelete`. The removed member's next request gets **401**, and the demoted
member's next request runs with the new role. When a business is deactivated, its members get
401 within 60 s at most.

### (e) Public payloads use explicit presenters: B2

New files (B2):
- `common/presenters/StaffPresenter.php`: `public(Staff $s): array` returns `{id, name, specialization}`.
- `common/presenters/BusinessPresenter.php`:
  - `site(Business $b): array`: exactly today's `SlotEngine::businessPayload` keys.
  - `card(Business $b, array $extra = []): array`: the directory card (§4.4).
  - `detail(Business $b): array`: card plus the detail fields.
  - `consumerSubset(Business $b): array`: `{id, slug, name, logo, brand_color, phone, address, map_url, timezone, engine}`.
- `common/presenters/ReviewPresenter.php`: `public(Review $r): array` and `mine(Review $r): array`.

Changes:
- `common/engines/SlotEngine.php::publicData`: `'staff' => array_map([StaffPresenter::class,'public'], Staff::find()...->all())`.
  Make `businessPayload()` delegate to `BusinessPresenter::site()`. The keys stay the same.
- `api/modules/site/controllers/SiteController.php::actionView` (legacy branch): staff goes
  through `StaffPresenter::public`.
- Never return a `Business` AR from any new endpoint, and never return `telegram_bot_token`,
  `features`, `tariff` or `commission_percent` publicly.

### (f) Server-side booking rules on public and consumer create: B2

`api/modules/booking/services/BookingService.php` (new) enforces these rules for modes `public`
and `consumer`. Mode `admin` skips them, as it does today.

| Rule | Error |
|---|---|
| `staff.is_active` and the staff exists | 404 `Xodim topilmadi.` |
| `business.status === 10` | 404 `Biznes topilmadi.` |
| `business.online_booking_enabled` | 403 `Bu biznesda onlayn yozilish yopiq.` |
| `service.business_id === staff.business_id` | 404 `Bu biznes uchun xizmat topilmadi.` |
| `service.is_active && service.online_bookable` | 400 `Bu xizmatni bron qilish mumkin emas.` |
| Slot path: `starts_at` in the future and equal to an offered `AvailabilityService::slots()` slot (lead and horizon are already inside) | 400 `starts_at kelajakda bo'lishi kerak.` / 409 `Tanlangan vaqt band.` |
| Rental path: local session start >= now + `booking_lead_min` minutes | 400 `Sana bron qilish oralig'idan tashqarida.` |
| Rental path: local date <= today(local) + `booking_horizon_days` | 400 `Sana bron qilish oralig'idan tashqarida.` |
| Rental path: no live appointment of the business overlaps | 409 `Bu sana allaqachon band.` |

`AvailabilityController::actionIndex` (B2) adds two checks. Staff whose business has `status != 10`
gives 404 `Xodim topilmadi.`. When `!online_booking_enabled`, or the service is not
`is_active && online_bookable`, it returns `{date, timezone, slots: []}`.

`SiteController::actionBookedDays` (B2) adds one fix. An appointment whose local span covers both
sessions (local start < 17:00 and local end > 17:00, e.g. the 10:00-23:00 default) reports
`["morning","evening"]`. It also returns the bookable window the rental rules above enforce, and
`to` defaults to today + `booking_horizon_days` (was +120):
`{"booked":{...},"min_date":"2026-10-17","max_date":"2026-11-16","lead_min":0}` (`min_date` = the
local day of now + `booking_lead_min`). The storefront `CalendarStep.vue` disables days outside
`min_date..max_date` and days whose chosen session (morning 10:00, evening 18:00, none 10:00)
starts before now + `lead_min`.

Concurrency: the overlap check and the insert run in one transaction that first locks the staff
row (slot) or the business row (rental) with `SELECT ... FOR UPDATE`, so parallel bookings of the
same staff/hall queue and the loser gets 409. The idempotency key is re-checked under that lock and
remembered before commit, so a concurrent same-key retry replays (200) instead of booking twice.

Admin mode: a `client_id` must belong to the staff's business, else 422 pointer `client_id`
`Mijoz topilmadi.`.

`PaymentController::actionDeposit` (B2) adds two guards before the idempotent replay:
`appointment.paid` gives 409 `Bu bron uchun to'lov allaqachon qilingan.`, and status in
`canceled|no_show|completed` gives 409 `Bu bron uchun to'lov qilib bo'lmaydi.`. Click stays as it
is; the apps never send `provider: "click"`.

The PSP side re-checks the booking (`Transaction::appointmentClosed()`): Payme CheckPerform /
CreateTransaction / PerformTransaction answer -31008 and Click Prepare / Complete answer "canceled"
when the appointment is `canceled|no_show|completed`. `Transaction::markAppointmentPaid()` never
touches a released (canceled/no_show) booking; it logs a refund warning instead.

### (g) `upsertClient` phone normalization: B2

In `BookingService::upsertClient()` (moved out of `AppointmentController`), run
`$phone = \common\helpers\Phone::normalize((string) $client['phone']) ?? (string) $client['phone'];`
**before** the `Client::find()->andWhere(['business_id'=>..,'phone'=>$phone])` lookup. Nothing
needs a backfill, because `Client::beforeValidate` already normalized the stored rows.

`upsertClient(..., bool $overwrite = false)`: only admin mode passes `true`. Public, consumer and
order input never renames an existing CRM client; it only fills an empty name (or a name equal to
the phone) and an empty email. A new client is always named from the input. `orders.customer_name`
still records the name typed for that order.

### (h) Register: `rental` -> engine `rental`: B1

- `api/modules/auth/controllers/AuthController.php::actionRegister`: after reading
  `$businessInput`, if `($businessInput['category'] ?? null) === 'rental'` then `$business->engine = 'rental'`,
  whatever was sent.
- `apps/corporate/src/views/Register.vue:12`: change `engine: 'slot'` to `engine: 'rental'`.
- No data migration for already registered rental businesses in this iteration. To check:
  `SELECT id,slug FROM businesses WHERE category='rental' AND engine<>'rental'`.

### 2.8 CORS: B1

Add `Idempotency-Key` to `Access-Control-Request-Headers` in `common/rest/Controller.php` and to
`Access-Control-Allow-Headers` in `common/rest/Cors.php`.

### 2.9 Role and permission matrix: every existing tenant route

Legend: **Y** = allow, **N** = 403, **req+** = `tenant->require()` added by this plan.
"✱" marks a change in behavior. Public, webhook, sms and superadmin routes are unchanged and
not listed.

| Route | Owner | Admin | Staff | Tenant require |
|---|---|---|---|---|
| GET /v1/auth/me | Y | Y | Y (staff shell) | n/a (shape changed §4.1) |
| POST /v1/auth/switch/{businessId} | Y | Y | Y (staff shell) | n/a |
| GET /v1/team | Y | Y | **N ✱** | yes |
| POST /v1/team | Y | N | N | yes |
| PATCH /v1/team/{userId} | Y | N | N | yes |
| DELETE /v1/team/{userId} | Y | N | N | yes |
| GET /v1/staff, GET /v1/staff/{id} | Y | Y | **N ✱** | **req+** |
| POST /v1/staff, PUT/PATCH/DELETE /v1/staff/{id} | Y | Y | N | via finder **req+** |
| GET /v1/service-categories[/{id}] | Y | Y | **N ✱** | **req+** |
| POST/PUT/PATCH/DELETE /v1/service-categories[/{id}] | Y | Y | N | **req+** |
| GET /v1/services[/{id}] | Y | Y | **N ✱** | **req+** |
| POST/PUT/PATCH/DELETE /v1/services[/{id}] | Y | Y | N | **req+** |
| GET /v1/settings/booking | Y | Y | **N ✱** | yes |
| PUT /v1/settings/booking | Y | Y | N | yes |
| POST /v1/uploads | Y | Y | **N ✱** | (role implies tid) |
| GET /v1/staff/{id}/working-hours | Y | Y | **N ✱** | **req+** |
| PUT /v1/staff/{id}/working-hours | Y | Y | N | **req+** |
| GET /v1/staff/{id}/time-off | Y | Y | **N ✱** | **req+** |
| POST /v1/staff/{id}/time-off, DELETE /v1/staff/{sid}/time-off/{id} | Y | Y | N | **req+** |
| GET /v1/appointments, GET /v1/appointments/{id} | Y | Y | **N ✱** | yes |
| POST /v1/appointments (with business token) | Y (admin mode) | Y (admin mode) | **N ✱** | **req+ ✱** |
| PATCH /v1/appointments/{id} | Y | Y | N | (role implies tid) |
| GET /v1/orders | Y | Y | Y (staff shell) | **req+** |
| PATCH /v1/orders/{id} | Y | Y | Y (staff shell) | **req+** |
| GET /v1/clients, GET /v1/clients/{id} | Y | Y | **N ✱** | yes |
| POST/PUT/PATCH/DELETE /v1/clients[/{id}], PUT /v1/clients/{id}/categories | Y | Y | N | yes |
| GET /v1/client-categories | Y | Y | **N ✱** | yes |
| POST/PUT/PATCH/DELETE /v1/client-categories[/{id}] | Y | Y | N | yes |
| GET /v1/loyalty/{clientId} | Y | Y | **N ✱** | yes |
| POST /v1/loyalty/earn, /v1/loyalty/redeem | Y | Y | N | yes |
| GET /v1/loyalty/rules[/{id}] | Y | Y | **N ✱** | **req+** |
| writes /v1/loyalty/rules | Y | Y | N | **req+** |
| GET /v1/loyalty/discount-rules[/{id}] | Y | Y | **N ✱** | **req+** |
| writes /v1/loyalty/discount-rules | Y | Y | N | **req+** |
| GET /v1/loyalty/auto-category-rules[/{id}] | Y | Y | **N ✱** | **req+** |
| writes + POST .../apply | Y | Y | N | **req+** |
| GET /v1/loyalty/settings | Y | Y | **N ✱** | yes |
| PUT /v1/loyalty/settings | Y | Y | N | yes |
| GET /v1/certificates[/{id}] | Y | Y | **N ✱** | **req+** (index) |
| writes /v1/certificates | Y | Y | N | yes |
| GET /v1/subscription-types[/{id}] | Y | Y | **N ✱** | **req+** (index) |
| writes /v1/subscription-types | Y | Y | N | yes |
| GET /v1/deposits/balances, GET /v1/deposits/{clientId} | Y | Y | **N ✱** | yes |
| POST /v1/deposits | Y | Y | N | yes |
| GET /v1/referrals | Y | Y | **N ✱** | **req+** |
| POST /v1/referrals | Y | Y | **N ✱** | yes |
| POST /v1/referrals/{id}/credit | Y | Y | N | yes |
| POST /v1/payments/{id}/refund | Y | Y | N | yes |
| GET /v1/analytics/overview | Y | Y | **N ✱** | yes |
| GET /v1/finance/summary, /v1/finance/transactions | Y | Y | N | yes |
| GET /v1/payroll | Y | Y | **N ✱** | yes |
| GET /v1/products, /{id}, /summary, /{id}/movements | Y | Y | **N ✱** | yes |
| POST/PUT/PATCH/DELETE /v1/products[/{id}], POST /{id}/stock | Y | Y | N | yes |
| **NEW** GET /v1/reviews, POST /v1/reviews/{id}/reply | Y | Y | N | yes |
| **NEW** GET/PATCH /v1/me/* | Y* | Y* | Y* (staff shell) | yes (*needs a linked active staff row) |

Consumer (`/v1/consumer/*`) and directory (`/v1/directory/*`) routes are not tenant routes: a
business token gets 401 on consumer routes and is treated as anonymous on directory routes (§2a).

`common/rbac/Permissions.php` (B1, new) mirrors this matrix as data so that `/auth/me` can return
it:

```php
final class Permissions {
  public const ALL = ['appointments.all','appointments.manage','orders','clients','analytics',
    'finance','payroll','loyalty','inventory','catalog.manage','team.read','team.manage',
    'settings.manage','reviews','uploads','me'];
  public static function forRole(?string $role): array;
  // business_owner => ALL; business_admin => ALL minus 'team.manage';
  // staff => ['orders','me'] (exactly the staff shell: orders board + /v1/me/*); null => []
}
```

---

## 3. New and changed code, by file

### 3.1 B1 files

| File | Kind | What |
|---|---|---|
| `common/components/Jwt.php` | change | `typ` claim, `$ttl`, `typ()`, `expiresAt()` (§2a) |
| `common/models/User.php` | change | typ check + DB role (§2a, §2d) |
| `common/models/BusinessUser.php` | change | `activeRole()`, `forgetRole()`, cache bust in `afterSave`/`afterDelete` |
| `common/models/Staff.php` | change | rules: `user_id` must be a `business_user` of `business_id` (422 pointer `user_id`, `Bu foydalanuvchi ushbu biznes a'zosi emas.`); unique (`business_id`,`user_id`) skipOnEmpty (`Bu foydalanuvchi boshqa xodimga bog'langan.`); a row already linked to one user is never re-pointed to another (`Bu xodim boshqa hisobga bog'langan.`) |
| `common/rest/Controller.php` | change | CORS header (§2.8). Nothing else. |
| `common/rest/Cors.php` | change | CORS header |
| `common/rbac/Permissions.php` | new | §2.9 |
| `api/modules/auth/controllers/AuthController.php` | change | login/me/switch shapes (§4.1), register engine fix (§2h) |
| `api/modules/auth/controllers/TeamController.php` | change | staff gate on index, `staff_id` support (§4.2), unlink staff on delete |
| `api/modules/me/Module.php` | new | routes §4.3 |
| `api/modules/me/controllers/BaseMeController.php` | new | abstract, extends `common\rest\Controller`; `protected function staff(): Staff`: `tenant->require()`, then `Staff::find()->where(['user_id'=>currentUser()->id,'is_active'=>1])->one()` (tenant-scoped), otherwise 404 `Hisobingiz xodim profiliga bog'lanmagan.`; `protected function tz(): DateTimeZone` (business tz, fallback Asia/Tashkent) |
| `api/modules/me/controllers/MeController.php` | new | `actionStaff`, `actionStats`, `actionSchedule` |
| `api/modules/me/controllers/AppointmentController.php` | new | `actionIndex`, `actionView`, `actionUpdate` |
| `api/modules/booking/controllers/{Staff,Service,ServiceCategory,Schedule}Controller.php` | change | `tenant->require()` (§2c) + owner/admin gate on the GET actions (§2b) |
| `api/modules/booking/controllers/UploadController.php` | change | owner/admin only (§2b; staff removed) |
| `api/modules/crm/controllers/{Client,ClientCategory}Controller.php` | change | staff gates |
| `api/modules/analytics/controllers/AnalyticsController.php` | change | staff gate |
| `api/modules/payroll/controllers/PayrollController.php` | change | staff gate |
| `api/modules/inventory/controllers/ProductController.php` | change | staff gates |
| `api/modules/loyalty/controllers/*.php` (all 9 controllers) | change | staff gates + `tenant->require()` |
| `apps/corporate/src/views/Register.vue` | change | rental engine |
| `console/migrations/m261017_100600_add_unique_user_to_staff.php` | new | §1.7 |
| `console/controllers/SeedStaffController.php` | new | `yii seed-staff` (§6) |

### 3.2 B2 files

| File | Kind | What |
|---|---|---|
| `common/config/params.php` | change | consumer params (below) |
| `common/models/Business.php` | change | rules for city, district (string 64), lat (`number`, -90..90), lng (-180..180), description (string max 2000), is_listed (boolean, default true), rating_avg/rating_count/featured_until (safe, not user-writable); `@property` docs |
| `common/models/Appointment.php` | change | `SOURCE_APP = 'app'` added to the source range; `consumer_id` integer rule; `getConsumer()`, `getBusiness()` |
| `common/models/Order.php` | change | `'app'` added to `SOURCES`; `consumer_id` integer rule; `getBusiness()` |
| `common/models/ConsumerUser.php` | new | IdentityInterface; table `consumer_users`; phone normalized in `beforeValidate`; `fields()`: `id, phone, name, birthday, gender, city, locale, created_at` |
| `common/models/ConsumerOtpCode.php` | new | not tenant-scoped |
| `common/models/ConsumerFavorite.php` | new | TimestampBehavior with `updatedAtAttribute=false` |
| `common/models/Review.php` | new | `isTenantScoped() = true`; rules: rating integer 1..5, comment string max 1000, reply string 1..1000, status in [published, hidden]; `afterSave`/`afterDelete` call `self::recomputeBusinessRating(int $businessId)`, which sets `businesses.rating_avg = ROUND(AVG(rating),2)` and `rating_count = COUNT(*)` over `status='published'` |
| `common/components/ConsumerAuth.php` | new | §2a |
| `common/helpers/Categories.php` | new | directory category catalog (§4.4) |
| `common/presenters/{Business,Staff,Review}Presenter.php` | new | §2e |
| `common/engines/SlotEngine.php` | change | presenters (§2e) |
| `api/modules/site/controllers/SiteController.php` | change | legacy staff presenter; booked-days full-day fix |
| `api/modules/booking/services/BookingService.php` | new | create logic extracted from `AppointmentController::actionCreate`, `createRentalBooking`, `upsertClient`, `sellProducts`, `businessTimezone` |
| `api/modules/booking/controllers/AppointmentController.php` | change | `actionCreate` delegates to `BookingService`; `actionIndex/View` staff gate; `TRANSITIONS` unchanged; `actionUpdate` (and `/v1/me` PATCH, kitchen `PATCH /v1/orders/{id}`) now decide the transition on the row re-read `FOR UPDATE` (kitchen: 409 `Buyurtma holati o'zgargan. Sahifani yangilang.` if it changed since read) |
| `api/modules/booking/controllers/AvailabilityController.php` | change | §2f |
| `api/modules/booking/controllers/SettingsController.php` | change | GET/PUT include the directory fields (§4.8); `actionView` gets the owner/admin gate (§2b) |
| `api/modules/catalog/services/OrderService.php` | new | create logic extracted from `OrderController::actionCreate` + Client upsert + idempotency |
| `api/modules/catalog/controllers/OrderController.php` | change | delegates to `OrderService`; `tenant->require()` on index/update |
| `api/modules/billing/controllers/PaymentController.php` | change | deposit guards (§2f) |
| `api/modules/crm/Module.php` | change | review routes, added BEFORE the `UrlRule`s |
| `api/modules/crm/controllers/ReviewController.php` | new | business-side reviews |
| `api/modules/consumer/Module.php` | new | routes §4.6; `bootstrap()` also calls `ConsumerAuth::userComponent()` |
| `api/modules/consumer/components/ConsumerController.php` | new | abstract base: overrides the authenticator; `protected function consumer(): ConsumerUser` (401 if null) |
| `api/modules/consumer/controllers/{Auth,Me,Favorite,Appointment,Order,Loyalty,Review}Controller.php` | new | §4.6 |
| `api/modules/consumer/services/OtpService.php` | new | issue, verify, rate limits |
| `api/modules/consumer/services/ConsumerLinker.php` | new | back-link by phone, anonymize on delete |
| `api/modules/directory/Module.php` | new | routes §4.4 |
| `api/modules/directory/controllers/DirectoryController.php` | new | §4.4 |
| `console/migrations/m261017_100000..100500_*.php` | new | §1.1-§1.6 |
| `console/controllers/SeedConsumerController.php` | new | `yii seed-consumer` (§6) |

New `common/config/params.php` keys (B2):

```php
'consumer.jwt.ttl' => 60 * 60 * 24 * 30,              // 30 days, no refresh token
'consumer.otp.ttl' => 120,                             // seconds
'consumer.otp.resend_after' => 60,                     // seconds per phone
'consumer.otp.max_per_hour_phone' => 5,
'consumer.otp.max_per_hour_ip' => 20,
'consumer.otp.max_attempts' => 5,
'consumer.otp.demo_phones' => array_values(array_filter(array_map('trim', explode(',',
    getenv('CONSUMER_DEMO_PHONES') ?: '+998900000001,+998900000002,+998900000003')))),
'consumer.otp.demo_code' => getenv('CONSUMER_DEMO_OTP_CODE') ?: '1111',
```

### 3.3 `BookingService` contract (B2 internal; documented so that review is easy)

```php
namespace api\modules\booking\services;
final class BookingService {
  public const MODE_PUBLIC = 'public', MODE_ADMIN = 'admin', MODE_CONSUMER = 'consumer';
  /**
   * $body = the same JSON body as POST v1/appointments (staff_id, service_id, starts_at | date+session,
   *         guests, client{phone,name,email}, client_id (admin only), notes, products (admin only), status (admin only)).
   * Consumer mode: client = {phone: $consumer->phone, name: $body['name'] ?? $consumer->name ?? phone};
   *                sets consumer_id; source = 'app'; status = 'pending'.
   * Public mode: source = 'link'. Admin mode: source = 'admin' (unchanged behaviour).
   * Idempotency cache key: 'appt:idem:{bid}:{key}' (public/admin), 'appt:idem:c{consumerId}:{bid}:{key}' (consumer), 24 h.
   * @return array{0: Appointment, 1: bool}  [model, replayed]. When $model->hasErrors() the caller returns fail422($model).
   * @throws BadRequestHttpException|NotFoundHttpException|ConflictHttpException|ForbiddenHttpException
   */
  public function create(array $body, string $mode, ?string $idempotencyKey, ?\common\models\ConsumerUser $consumer = null): array;
}
```

`AppointmentController::actionCreate` picks the mode like this:
- no `currentUser()` -> public
- `activeTenantId === null` -> 403 `No active business selected.`
- role owner or admin -> admin
- role staff -> 403

A replay returns status **200**; a new booking returns **201**.

`OrderService::create(array $body, string $mode /* public|consumer */, ?string $idempotencyKey, ?ConsumerUser $consumer): array{0: Order, 1: bool}`.
It keeps today's public behavior (slug, server-side prices, Telegram `init_data`) and adds the following:
- Upserts `Client` by normalized phone and sets `orders.client_id`, in both modes.
- Consumer mode: `customer_name` and `customer_phone` come from the profile (body `name` may
  override the name), `consumer_id` is set, `source='app'`, and the business must have
  `online_booking_enabled`, otherwise 403 `Bu biznes hozir onlayn buyurtma qabul qilmaydi.`.
  The public web keeps its current behavior.
- Honors `Idempotency-Key` on both POST /v1/orders and /v1/consumer/orders, with cache keys
  `order:idem:{bid}:{key}` and `order:idem:c{cid}:{key}` for 24 h. Same-key requests are
  serialized by a named DB lock (`GET_LOCK`, 10 s; FileCache `add()` is not atomic): a request
  queued on the lock replays the winner's order (200); a lock timeout gives 409
  `So'rov hali bajarilmoqda. Birozdan keyin qayta urinib ko'ring.`.

---

## 4. Endpoints

Conventions for every endpoint:
- Base `https://api.tizbiz.uz`, header `Authorization: Bearer <jwt>`.
- Success is `{"data": ...}`; paginated responses are `{"data":[...], "meta":{"page","per_page","total","pages"}}`.
- Errors are `{"errors":[{"status":"409","title":"Conflict","detail":"..."}]}`. Field errors are
  422 `{"errors":[{"status":"422","title":"Validation error","detail":"...","source":{"pointer":"phone"}}]}`.
- A 204 has no body.
- Auth levels:
  - **public**: no token.
  - **optional-consumer**: anonymous or consumer token.
  - **consumer**: consumer token required, otherwise 401.
  - **business-member**: any role.
  - **owner+admin**.
  - **staff-self**: any member with a linked active staff row.

### 4.1 Changed: auth (B1)

#### POST /v1/auth/login: public

Request: `{"phone":"+998 90 111 11 11","password":"secret123"}`

Response 200 (new keys marked `// NEW`):
```json
{"data":{
  "token":"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "expires_at":1792818720,
  "user":{"id":4,"phone":"+998901111111","name":"Shoxrux Karimov","status":10,"is_superadmin":false,"created_at":1784364000,"updated_at":1792213920},
  "businesses":[{"id":2,"name":"Shox Barber","slug":"shox-barber","category":"barber","engine":"slot","logo":"https://api.tizbiz.uz/uploads/202609/a1b2.png","role":"business_owner"}],
  "active":{"business_id":2,"role":"business_owner","staff_id":null,
            "permissions":["appointments.all","appointments.manage","orders","clients","analytics","finance","payroll","loyalty","inventory","catalog.manage","team.read","team.manage","settings.manage","reviews","uploads","me"]}
}}
```
`expires_at` and `active.staff_id`/`active.permissions` are new. `staff_id` = the id of the
active Staff row with `business_id = active.business_id AND user_id = user.id`, or null.
Token claims: `typ:"biz"`.

Errors: 401 `Telefon yoki parol noto'g'ri.`

#### GET /v1/auth/me: any business token
```json
{"data":{"user":{...},"active":{"business_id":2,"role":"staff","staff_id":7,"permissions":["orders","me"]},"businesses":[...]}}
```
Errors: 401 (consumer token, expired token, or removed member).

#### POST /v1/auth/switch/{businessId}: any business token
Response: `{"data":{"token":"eyJ...","expires_at":1792818720,"active":{"business_id":3,"role":"staff","staff_id":12,"permissions":["orders","me"]}}}`.
Errors: 403 `Siz bu biznesning a'zosi emassiz.` and 403 `Bu biznes faol emas.`

#### POST /v1/auth/register: public
Request and response shapes are unchanged. Behavior change: `business.category === "rental"`
stores `engine:"rental"`.

### 4.2 Changed: team (B1)

#### GET /v1/team: owner+admin (staff now gets 403)
```json
{"data":[
  {"user_id":4,"name":"Shoxrux Karimov","phone":"+998901111111","role":"business_owner","staff_id":null},
  {"user_id":31,"name":"Usta Jahongir","phone":"+998931110001","role":"staff","staff_id":2}
]}
```
`staff_id` = the lowest-id Staff row in this business with `user_id` = the member, or null.

#### POST /v1/team: owner
Request: `{"phone":"+998931110001","name":"Usta Jahongir","role":"staff","password":"secret123","staff_id":2}`.
`staff_id` is optional.

Response 201: `{"data":{"user_id":31,"name":"Usta Jahongir","phone":"+998931110001","role":"staff","staff_id":2}}`

Errors:
- 400 bad phone, role or password (a non-string `role` is 400 `Noto'g'ri rol.`, never 500)
- 409 `Bu foydalanuvchi allaqachon jamoa a'zosi.`
- 422 pointer `staff_id` `Xodim topilmadi.` (not in this business)
- 409 `Bu xodim boshqa hisobga bog'langan.` (staff row already has another `user_id`)

The membership insert and the link happen in one transaction.

#### PATCH /v1/team/{userId}: owner
Request: `{"role":"staff"}`, `{"staff_id":2}`, `{"staff_id":null}` (unlink) or both keys. At least
one key is required, otherwise 400 `role yoki staff_id talab qilinadi.`.

Linking first clears `user_id` on any other staff row of this business with this user.

Response: `{"data":{"user_id":31,"role":"staff","staff_id":2}}`

Errors: 404 member; 422 pointer `role` (last owner); 400 `Noto'g'ri rol.` (unknown or non-string
`role`); the same `staff_id` errors as POST.

POST and PATCH bust the member's cached role again after commit (`BusinessUser::forgetRole`), as
DELETE does, so a concurrent request cannot re-cache the old role for `ROLE_CACHE_TTL`.

Linking a login to a staff row happens only here (owner). `POST/PATCH /v1/staff {user_id}` is
owner-only too: an admin may only echo the current value (else 403), and a row already linked to
another account answers 409 `Bu xodim boshqa hisobga bog'langan.` (unlink with `user_id: null`
first). `Staff::validateUserLink` also refuses re-pointing a linked row (422 pointer `user_id`).

#### DELETE /v1/team/{userId}: owner
Response: 204. Behavior change: also runs
`Staff::updateAll(['user_id'=>null],['business_id'=>$bid,'user_id'=>$userId])`. The cache is
busted, so the member's token gets 401 on its next call.

### 4.3 New: staff self-service `/v1/me/*` (B1, module `me`)

Routes in `api/modules/me/Module.php`:
```php
'GET v1/me/staff' => 'me/me/staff',
'GET v1/me/stats' => 'me/me/stats',
'GET v1/me/schedule' => 'me/me/schedule',
'GET v1/me/appointments' => 'me/appointment/index',
'GET v1/me/appointments/<id:\d+>' => 'me/appointment/view',
'PATCH v1/me/appointments/<id:\d+>' => 'me/appointment/update',
```
Auth for all of them: **staff-self**. Errors common to all:
- 401 for no token, a consumer token, or a removed member
- 403 `No active business selected.`
- 404 `Hisobingiz xodim profiliga bog'lanmagan.` when no active staff row is linked

Local dates use the business timezone (fallback `Asia/Tashkent`).

#### GET /v1/me/staff
```json
{"data":{"id":2,"business_id":2,"name":"Usta Jahongir","specialization":"Sartarosh","commission_percent":40,"is_active":true,
         "business":{"id":2,"name":"Shox Barber","slug":"shox-barber","engine":"slot","timezone":"Asia/Tashkent","logo":null}}}
```

#### GET /v1/me/appointments?from=2026-10-17&to=2026-10-17&status=confirmed
- `from` and `to` are business-local `YYYY-MM-DD`; both default to today (local).
- The range is at most 62 days, otherwise 400 `Sana oralig'i 62 kundan oshmasligi kerak.`
- A malformed date gives 400 `Yaroqli sana (YYYY-MM-DD) talab qilinadi.`
- `status` is optional and must be one of `Appointment::STATUSES`.

The server converts the range to UTC bounds `[from 00:00 local, to 23:59:59 local]` and forces
`staff_id = me`. Results are ordered by `starts_at` ASC and are not paginated. Items use the
`Appointment::fields()` shape, unchanged:
```json
{"data":[{"id":5012,"business_id":2,"client_id":881,"consumer_id":17,"staff_id":2,"service_id":11,"guests":null,
  "starts_at":"2026-10-17 05:00:00","ends_at":"2026-10-17 05:40:00","status":"confirmed","source":"app",
  "deposit_tiyin":2000000,"paid":true,"notes":null,"created_at":1792054800,"updated_at":1792054800,
  "client_name":"Aziza Karimova","client_phone":"+998900000001","service_name":"Soch olish + soqol",
  "service_duration":40,"staff_name":"Usta Jahongir","items":[]}]}
```

#### GET /v1/me/appointments/{id}
Response: the same item shape. Errors: 404 `Bron topilmadi.` if the appointment is not this
staff member's (tenant-scoped + `staff_id` filter).

#### PATCH /v1/me/appointments/{id}
Request: `{"status":"arrived"}`. The staff transition table is local to
`me/AppointmentController`; it is `AppointmentController::TRANSITIONS` minus `canceled`:

| from | allowed to |
|---|---|
| pending | confirmed, arrived, completed, no_show |
| confirmed | arrived, completed, no_show |
| arrived | completed, no_show |
| completed / no_show / canceled | (none) |

Same status = no-op 200. The transition is decided on the row re-read with `SELECT ... FOR UPDATE`
in a transaction (a consumer cancel committed meanwhile makes it 409). `completed` triggers
`Yii::$app->trigger('appointmentCompleted', new Event(['sender'=>$model]))` after commit, which
credits loyalty.

Response: the appointment.

Errors:
- 400 `status talab qilinadi.` / `Noma'lum holat.`
- 404
- 409 `Holatni 'X' dan 'Y' ga o'zgartirib bo'lmaydi.`

#### GET /v1/me/stats?from=2026-10-01&to=2026-10-17
Defaults: `from` = the first day of the current local month, `to` = today (local); at most 366
days. Revenue = SUM(`services.price_tiyin`) over completed appointments (the same formula as
payroll). Earnings = `intval(revenue * commission_percent / 100)`.
```json
{"data":{
  "range":{"from":"2026-10-01","to":"2026-10-17","timezone":"Asia/Tashkent"},
  "staff":{"id":2,"name":"Usta Jahongir","commission_percent":40},
  "appointments":{"total":64,"pending":2,"confirmed":3,"arrived":0,"completed":52,"no_show":4,"canceled":3},
  "revenue_tiyin":416000000,"earnings_tiyin":166400000,"clients_served":41,
  "series":[{"date":"2026-10-01","count":4,"completed":3,"revenue_tiyin":24000000,"earnings_tiyin":9600000}],
  "today":{"total":6,"completed":2,"next_at":"2026-10-17 09:30:00"}
}}
```
`series` has one zero-filled entry per local day. `today.next_at` = the earliest `starts_at`
>= now with status pending, confirmed or arrived, or null. Errors: 400 bad date.

#### GET /v1/me/schedule?from=2026-10-17&to=2026-12-16
`from`/`to` filter time-off only (local dates; default today..today+60).
```json
{"data":{
  "working_hours":[{"id":21,"weekday":1,"start_time":"09:00:00","end_time":"20:00:00"}],
  "time_off":[{"id":4,"date":"2026-10-25","start_time":null,"end_time":null,"reason":"Dam olish"}]
}}
```

### 4.4 New: directory (B2, module `directory`, optional-consumer)

Routes in `api/modules/directory/Module.php`. The specific rule comes first.
```php
'GET v1/directory/categories' => 'directory/directory/categories',
'GET v1/directory/businesses' => 'directory/directory/index',
'GET v1/directory/businesses/<slug:[a-z0-9-]+>/reviews' => 'directory/directory/reviews',
'GET v1/directory/businesses/<slug:[a-z0-9-]+>' => 'directory/directory/view',
```
`authOptional()` = all 4 actions. The authenticator uses `ConsumerAuth::userComponent()`.
A business token, or any invalid token, means anonymous.

`common/helpers/Categories.php::all()` returns these entries, in this order:

| key | label (uz) | label_ru | engine | icon |
|---|---|---|---|---|
| barber | Barber / Go'zallik saloni | Барбершоп / Салон красоты | slot | scissors |
| cafe | Kafe / Tortlar | Кафе / Торты | catalog | cake |
| restaurant | Restoran | Ресторан | catalog | utensils |
| clinic | Klinika / Tibbiyot | Клиника / Медицина | medical | stethoscope |
| rental | To'yxona / Ijara | Тойхона / Прокат | rental | rings |

#### GET /v1/directory/categories: public
```json
{"data":[{"key":"barber","label":"Barber / Go'zallik saloni","label_ru":"Барбершоп / Салон красоты","engine":"slot","icon":"scissors","count":1},
         {"key":"cafe","label":"Kafe / Tortlar","label_ru":"Кафе / Торты","engine":"catalog","icon":"cake","count":1}]}
```
`count` counts businesses with `status=10 AND is_listed=1` and that category. Every known key is
returned, including `count: 0`.

#### GET /v1/directory/businesses: optional-consumer
`sort`, `q`, `category`, `engine` and `city` must be strings: an array (`?q[]=x`) gives 400
`<name> noto'g'ri.`.

Query parameters:

| Parameter | Behavior |
|---|---|
| `q` | LIKE on name, tagline, description, address |
| `category` | exact key |
| `engine` | `slot` also matches `engine IS NULL` |
| `city` | exact, case-insensitive |
| `sort` | `featured` (default: featured first, then rating_avg DESC, rating_count DESC, id DESC), `rating`, `new` (id DESC) or `name` (name ASC) |
| `page` | default 1 |
| `per_page` | default 20, clamped 1..50 |

Base filter: `status=10 AND is_listed=1`.

Response:
```json
{"data":[{
  "id":2,"slug":"shox-barber","name":"Shox Barber","category":"barber","category_label":"Barber / Go'zallik saloni",
  "engine":"slot","tagline":"Chilonzordagi eng yaxshi soch turmaklari","logo":"https://api.tizbiz.uz/uploads/202609/a1b2.png",
  "cover":null,"brand_color":"#1E1B4B","brand_color_2":null,"address":"Chilonzor 9-kvartal, 12-uy","city":"Toshkent",
  "district":"Chilonzor","lat":41.2756,"lng":69.2034,"rating_avg":4.73,"rating_count":15,"is_featured":false,
  "online_booking_enabled":true,"price_from_tiyin":5000000,"is_favorite":true}],
 "meta":{"page":1,"per_page":20,"total":5,"pages":1}}
```
Card field notes:
- `lat`/`lng` are floats or null.
- `rating_avg` is a float.
- `is_featured` = `featured_until > now`.
- `price_from_tiyin` = MIN(`price_tiyin`) over services with `is_active=1` (and `online_bookable=1`
  for slot/rental), or null.
- `is_favorite` is always present: `false` when anonymous.

Errors: 400 `Noto'g'ri saralash.` for an unknown `sort`.

#### GET /v1/directory/businesses/{slug}: optional-consumer
Works for `status=10` even when `is_listed=0` (deep links).
```json
{"data":{
  "business":{ /* every card field above */ "phone":"+998901111111","map_url":"https://yandex.uz/maps/-/CDabc",
               "description":"Erkaklar uchun zamonaviy barbershop. 5 nafar tajribali usta.","timezone":"Asia/Tashkent",
               "telegram_bot_username":"shoxbarber_bot",
               "hours":[{"weekday":1,"open":"09:00","close":"21:00"},{"weekday":7,"open":"10:00","close":"18:00"}] },
  "rating":{"avg":4.73,"count":15,"distribution":{"1":0,"2":0,"3":1,"4":2,"5":12}},
  "reviews_preview":[{"id":88,"rating":5,"comment":"Usta juda e'tiborli, soch ajoyib chiqdi!","author_name":"Aziza K.",
                      "service_name":"Soch olish","staff_name":"Usta Jahongir","reply":"Rahmat, yana kutamiz!",
                      "replied_at":1791636000,"created_at":1791500000}],
  "is_favorite":false
}}
```
Detail field notes:
- `hours` = per weekday, MIN(`start_time`) and MAX(`end_time`) over the `working_hours` of
  active staff, formatted `HH:MM`. Weekdays with no rows are omitted.
- `reviews_preview` = the 3 latest published reviews.
- Services, menu and staff still come from **GET /v1/site/{slug}**.

Errors: 404 `Biznes topilmadi.`

#### GET /v1/directory/businesses/{slug}/reviews?rating=5&page=1&per_page=20: public
```json
{"data":[ /* ReviewPresenter::public items as above */ ],
 "meta":{"page":1,"per_page":20,"total":15,"pages":1,"avg":4.73,"count":15,"distribution":{"1":0,"2":0,"3":1,"4":2,"5":12}}}
```
Only `status='published'`, ordered `created_at DESC`. Errors: 404.

### 4.5 Changed: public storefront payloads (B2)

- **GET /v1/site/{slug}**: `staff[]` items become `{"id":2,"name":"Usta Jahongir","specialization":"Sartarosh"}`
  (`business_id`, `user_id`, `commission_percent`, `is_active` and timestamps are removed). The
  `business` keys are unchanged. Flutter must still default `engine` to `slot` when it is missing.
- **GET /v1/site/{slug}/booked-days**: a full-day booking now reports both sessions.
- **GET /v1/staff/{id}/availability**: 404 for an inactive business; empty `slots` when booking is
  closed or the service is not bookable.
- **POST /v1/appointments**:
  - public rules from §2f
  - staff token -> 403
  - `tid=null` token -> 403
  - phone is normalized before the client lookup
  - response shape unchanged, plus `consumer_id: null` (`Appointment::fields()` lists every column, so a freshly
    inserted row also carries its null `consumer_id`/`guests`/`notes`)
  - a non-string `starts_at`/`date`/`session` gives 400, not 500
- **POST /v1/orders**:
  - honors `Idempotency-Key` (replay returns 200)
  - sets `client_id`
  - the response shape (`Order::fields()`) is unchanged
- **POST /v1/payments/deposit**: new 409 guards (§2f). Request:
  `{"appointment_id":5012,"provider":"payme"}` with header
  `Idempotency-Key: dep-5012-payme`. Response 201:
  `{"data":{"transaction":{"id":301,"provider":"payme","amount_tiyin":2000000,"type":"deposit","status":"created","appointment_id":5012,"created_at":1792213920,...},"provider":"payme","checkout_url":"https://checkout.paycom.uz/bT0..."}}`.
  A replay returns 200 with the same payload.

### 4.6 New: consumer (B2, module `consumer`)

Routes in `api/modules/consumer/Module.php`:
```php
'POST v1/consumer/auth/otp' => 'consumer/auth/otp',
'POST v1/consumer/auth/verify' => 'consumer/auth/verify',
'GET v1/consumer/me' => 'consumer/me/view',
'PATCH v1/consumer/me' => 'consumer/me/update',
'DELETE v1/consumer/me' => 'consumer/me/delete',
'GET v1/consumer/favorites' => 'consumer/favorite/index',
'PUT v1/consumer/favorites/<businessId:\d+>' => 'consumer/favorite/add',
'DELETE v1/consumer/favorites/<businessId:\d+>' => 'consumer/favorite/remove',
'GET v1/consumer/appointments' => 'consumer/appointment/index',
'POST v1/consumer/appointments' => 'consumer/appointment/create',
'GET v1/consumer/appointments/<id:\d+>' => 'consumer/appointment/view',
'POST v1/consumer/appointments/<id:\d+>/cancel' => 'consumer/appointment/cancel',
'GET v1/consumer/orders' => 'consumer/order/index',
'POST v1/consumer/orders' => 'consumer/order/create',
'GET v1/consumer/orders/<id:\d+>' => 'consumer/order/view',
'POST v1/consumer/orders/<id:\d+>/cancel' => 'consumer/order/cancel',
'GET v1/consumer/loyalty' => 'consumer/loyalty/index',
'GET v1/consumer/reviews' => 'consumer/review/index',
'POST v1/consumer/reviews' => 'consumer/review/create',
'PATCH v1/consumer/reviews/<id:\d+>' => 'consumer/review/update',
'DELETE v1/consumer/reviews/<id:\d+>' => 'consumer/review/delete',
```
All routes need a **consumer** token except `auth/otp` and `auth/verify` (public). A missing,
invalid or business token gives 401.

#### POST /v1/consumer/auth/otp: public
Request: `{"phone":"90 000 00 01"}`. The phone is normalized; invalid gives 422 pointer `phone`
`Telefon raqam noto'g'ri.`.

Response 200: `{"data":{"sent":true,"ttl_sec":120,"retry_after_sec":60}}`

Behavior:
- Demo phone (in `consumer.otp.demo_phones`): store the hash of `consumer.otp.demo_code`, send no
  SMS, apply no rate limit.
- Otherwise: generate a 6-digit `random_int(100000, 999999)` code, store its hash, and call
  `SmsSender::send($phone, "Bizcat: tasdiqlash kodi {code}. Uni hech kimga bermang.")`.
- If the send returns false: log `Yii::warning('Consumer OTP SMS failed for '.$maskedPhone, 'consumer')`
  (never the code), mark the row consumed and respond **503** `SMS yuborib bo'lmadi. Keyinroq urinib ko'ring.`
- Earlier unconsumed codes for that phone are marked consumed.
- Rate limits count every non-demo `consumer_otp_codes` row, failed sends included. Demo rows are
  stored with `ip = NULL` and are also excluded by phone from the per-IP count, so demo logins never
  eat an IP's budget. The 60 s resend check uses the `created_at` of the latest row for the phone;
  the hourly limits count rows from the last 3600 s per phone and per `ip` (`Yii::$app->request->userIP`).
- The checks and the insert run under named DB locks (`GET_LOCK`, IP lock first, then phone lock;
  `common\helpers\DbLock`), so parallel requests cannot all pass the checks. Not getting a lock
  within 5 s gives 429. The SMS is sent after the locks are released (the row already counts).
- Behind a reverse proxy, set env `TRUSTED_PROXIES` (comma-separated CIDRs) → params
  `request.trustedHosts`; the consumer module's `bootstrap()` then trusts `CF-Connecting-IP` /
  `X-Forwarded-For` (`request.ipHeaders`) from those hosts only. Empty (default) = `REMOTE_ADDR`.

Errors:
- 422
- 429 `Kodni qayta yuborish uchun {n} soniya kuting.` (resend < 60 s; header `Retry-After: n`)
- 429 `Juda ko'p urinish. Keyinroq urinib ko'ring.` (more than 5 per hour per phone, or more than 20 per hour per IP)
- 503

#### POST /v1/consumer/auth/verify: public
Request: `{"phone":"+998900000001","code":"1111","name":"Aziza"}`. `name` is used only when the
account is created.

Response 200:
```json
{"data":{"token":"eyJ...","expires_at":1794805920,"is_new":false,
  "consumer":{"id":17,"phone":"+998900000001","name":"Aziza Karimova","birthday":null,"gender":"female","city":"Toshkent","locale":"uz","created_at":1792195200}}}
```
Behavior:
1. Take the latest unconsumed, unexpired code for the phone and reserve one attempt atomically
   (`UPDATE ... SET attempts = attempts + 1 WHERE id=? AND consumed_at IS NULL AND expires_at > now
   AND attempts < max_attempts`; 0 rows = fail). A wrong code then burns the code once
   `attempts >= max_attempts`. Parallel guesses therefore never exceed `max_attempts`.
2. On success: mark the code consumed with `WHERE consumed_at IS NULL` (only the request that
   affects the row wins, so one code yields one token); find or create the `consumer_users` row;
   set `last_login_at`.
3. Run `ConsumerLinker::backLink($consumer)`:
   - `UPDATE appointments SET consumer_id=:cid WHERE consumer_id IS NULL AND client_id IN (SELECT id FROM clients WHERE phone=:phone)`
   - `UPDATE orders SET consumer_id=:cid WHERE consumer_id IS NULL AND customer_phone=:phone`
4. Issue the token with `typ="consumer"`, ttl 30 days.

Back-links follow later phone corrections: when the business changes a client's phone
(`Client::afterSave`, `Client::relinkConsumers`), that client's appointments linked to a consumer
other than the owner of the NEW phone are unlinked (except `source='app'` bookings the consumer
made), and unclaimed ones are linked to the new phone's consumer, if any.

Phone matching is strict everywhere: `common\helpers\Phone::normalize` accepts only 9 local digits
or 12 digits starting with `998` (else null), and `AuthController::normalizePhone` reuses it. A
foreign or malformed number typed on the business side is stored as typed and never matches a
consumer.

Errors:
- 422 pointer `code` `Kod noto'g'ri yoki muddati o'tgan.`
- 422 pointer `phone`
- 403 `Hisob bloklangan.` (status 0 and not deleted)

#### GET /v1/consumer/me
```json
{"data":{"id":17,"phone":"+998900000001","name":"Aziza Karimova","birthday":"1996-04-12","gender":"female","city":"Toshkent","locale":"uz","created_at":1792195200,
         "stats":{"appointments_upcoming":1,"appointments_total":6,"orders_total":2,"reviews_total":3,"favorites_total":2}}}
```

#### PATCH /v1/consumer/me
Request: any subset of `{"name":"Aziza K.","birthday":"1996-04-12","gender":"female","city":"Toshkent","locale":"ru"}`.
The phone cannot be changed.

Response: the same shape as GET.

Errors: 422 with pointers (`birthday` must be `Y-m-d`; `gender` must be `male` or `female`;
`locale` must be `uz` or `ru`).

#### DELETE /v1/consumer/me
Response: 204. `ConsumerLinker::anonymize()` runs in one transaction:
- `consumer_users` row: `phone='deleted-<id>'`, `name/birthday/gender/city=NULL`, `status=0`, `deleted_at=now`
- `reviews` of this consumer: `author_name="O'chirilgan foydalanuvchi"`, `consumer_id=NULL` (ratings are kept)
- the consumer's `consumer_favorites` rows are deleted
- `appointments` and `orders`: `consumer_id=NULL` (the business keeps its rows)

The old token then gets 401.

#### GET /v1/consumer/favorites
`{"data":[ /* BusinessPresenter::card with is_favorite:true */ ]}`. Ordered by favorite
`created_at DESC`; businesses with `status=10` only; not paginated.

#### PUT /v1/consumer/favorites/{businessId} and DELETE /v1/consumer/favorites/{businessId}
Response: 204. Both are idempotent. PUT on an unknown or inactive business gives 404
`Biznes topilmadi.`.

#### GET /v1/consumer/appointments?scope=upcoming&page=1&per_page=20
| scope | Filter | Order |
|---|---|---|
| `upcoming` (default) | `starts_at >= now(UTC)` AND status in pending/confirmed/arrived | ASC |
| `past` | everything else | DESC |

`per_page` is clamped to 1..50. Filter `consumer_id = me`.

```json
{"data":[{
  "id":5012,"status":"confirmed","starts_at":"2026-10-18 05:00:00","ends_at":"2026-10-18 05:40:00","guests":null,
  "deposit_tiyin":2000000,"paid":true,"notes":null,"source":"app","created_at":1792054800,
  "business":{"id":2,"slug":"shox-barber","name":"Shox Barber","logo":null,"brand_color":"#1E1B4B","phone":"+998901111111",
              "address":"Chilonzor 9-kvartal, 12-uy","map_url":null,"timezone":"Asia/Tashkent","engine":"slot"},
  "staff":{"id":2,"name":"Usta Jahongir"},
  "service":{"id":11,"name":"Soch olish + soqol","duration_min":40,"price_tiyin":8000000},
  "can_cancel":false,"can_review":false,"review_id":null}],
 "meta":{"page":1,"per_page":20,"total":1,"pages":1}}
```
- `can_cancel` = status in pending/confirmed AND `starts_at > now` AND `paid == false`.
- `can_review` = status `completed` AND no review for this appointment.
- `notes` is returned only for client-made bookings (`source` in `app`, `link`, `telegram`); for
  `admin` bookings (back-linked by phone) it is `null`, because those notes are staff-internal.
- `scope` must be a string (`?scope[]=` gives 400).

#### GET /v1/consumer/appointments/{id}
Response: the same item. Errors: 404 `Bron topilmadi.` if `consumer_id != me`. Flutter polls this
endpoint after Payme checkout to show `paid`/`confirmed`.

#### POST /v1/consumer/appointments
Header `Idempotency-Key: <uuid per booking attempt>`.

Slot request:
`{"staff_id":2,"service_id":11,"starts_at":"2026-10-18 05:00:00","notes":"Soqolni qisqa qiling","name":"Aziza"}`.

Rental request:
`{"staff_id":5,"service_id":40,"date":"2026-11-14","session":"evening","guests":180}`.

No `client`, `client_id`, `status` or `products` are accepted; they are ignored.

Response **201** (a replay returns **200**): the item shape above, with `can_cancel:true`.

Errors:
- 400 (missing ids or `starts_at`, past time, service not bookable, rental window)
- 403 `Bu biznesda onlayn yozilish yopiq.`
- 404 staff, service or business
- 409 `Tanlangan vaqt band.` / `Bu vaqt allaqachon band qilingan.` / `Bu sana allaqachon band.`
- 422

#### POST /v1/consumer/appointments/{id}/cancel
Request: `{"reason":"Rejam o'zgardi"}`. `reason` is optional; it is appended to `notes` as
`Mijoz bekor qildi: ...`.

Sets status `canceled` (allowed from pending and confirmed by `TRANSITIONS`). The checks run on the
row re-read with `SELECT ... FOR UPDATE` inside a transaction, so a concurrent staff/PSP change is
never overwritten. Deposit transactions still in `created` (no PSP holds them yet) are set to
`canceled` (`Appointment::afterSave`, for every path that releases a booking).

Response: the item.

Errors:
- 404
- 409 `Bu bronni bekor qilib bo'lmaydi.` (status, or `starts_at` <= now)
- 409 `Oldindan to'lov qilingan bronni bekor qilish uchun biznes bilan bog'laning.` (`paid`)
- 409 `To'lov jarayonda. Bekor qilish uchun biznes bilan bog'laning.` (a deposit transaction is
  `pending`, i.e. Payme CreateTransaction / Click Prepare already ran)

#### GET /v1/consumer/orders?scope=active&page=1
| scope | Status |
|---|---|
| `active` (default) | new, confirmed, preparing, ready |
| `past` | delivered, cancelled |

`page` default 1; `per_page` default 20, clamped to 1..50 (same as appointments). Filter
`consumer_id = me`. Ordered `id DESC`.

```json
{"data":[{"id":702,"status":"new","total_tiyin":45000000,"customer_name":"Aziza Karimova","customer_phone":"+998900000001",
  "note":"Tug'ilgan kun uchun yozuv: Lola 7 yosh","source":"app","created_at":1792213920,
  "items":[{"id":1501,"service_id":61,"name":"Napoleon torti (1 kg)","price_tiyin":22500000,"qty":2}],"items_count":1,
  "business":{"id":3,"slug":"aziza-tortlari","name":"Aziza Tortlari","logo":null,"brand_color":"#F26A35","phone":"+998902222222",
              "address":"Yunusobod 4-kvartal","map_url":null,"timezone":"Asia/Tashkent","engine":"catalog"},
  "can_cancel":true,"can_review":false,"review_id":null}],
 "meta":{"page":1,"per_page":20,"total":1,"pages":1}}
```
- `can_cancel` = status `new`.
- `can_review` = status `delivered` and no review exists.

#### GET /v1/consumer/orders/{id}
Response: the item. Errors: 404 `Buyurtma topilmadi.`

#### POST /v1/consumer/orders
Header `Idempotency-Key`. Request:
`{"slug":"aziza-tortlari","items":[{"service_id":61,"qty":2}],"note":"Soat 17:00 da olib ketaman","name":"Aziza"}`.

Response 201 (a replay returns 200): the item.

Errors:
- 404 `Biznes topilmadi.`
- 400 `Savat bo'sh.` / `Mahsulotlar topilmadi.`
- 403 `Bu biznes hozir onlayn buyurtma qabul qilmaydi.`
- 500 `Buyurtma yaratishda xatolik.`

#### POST /v1/consumer/orders/{id}/cancel
Sets `cancelled` when the status is `new`, as one conditional `UPDATE ... WHERE status='new'` (a
kitchen transition made meanwhile wins). Response: the item.

Errors: 404; 409 `Buyurtmani faqat yangi holatda bekor qilish mumkin.`

#### GET /v1/consumer/loyalty
The query joins `clients` (`phone = consumer.phone`) with `businesses` (`status=10`), LEFT JOINs
`loyalty_accounts` on `client_id`, and sums `deposit_transactions.delta_tiyin`. Visits = completed
appointments of that client. Ordered by `cashback_tiyin DESC`, then `visits DESC`.
```json
{"data":[{"business":{"id":2,"slug":"shox-barber","name":"Shox Barber","logo":null,"brand_color":"#1E1B4B"},
          "client_id":881,"points":120,"cashback_tiyin":1500000,"deposit_balance_tiyin":0,"visits":5}]}
```

#### GET /v1/consumer/reviews
`{"data":[ReviewPresenter::mine]}`. Each `mine` item = the public fields plus
`business:{id,slug,name,logo}`, `appointment_id`, `order_id` and `status`. Ordered `id DESC`,
not paginated.

#### POST /v1/consumer/reviews
Request: `{"appointment_id":4990,"rating":5,"comment":"Juda yoqdi!"}` or
`{"order_id":690,"rating":4}`. Exactly one of the two ids is required.

Rules:
- The item must have `consumer_id = me`.
- An appointment must be `completed`; an order must be `delivered`.
- `business_id`, `staff_id` and `service_id` are copied from the appointment. For an order,
  `service_id` = the first item.
- `author_name` = first name + the initial of the last word of `consumer.name`, e.g. `Aziza K.`.
  A consumer without a name gets `Mijoz`.

Response 201: the `mine` item.

Errors:
- 400 `appointment_id yoki order_id talab qilinadi.`
- 404 (not mine)
- 409 `Faqat yakunlangan tashrif uchun sharh qoldirish mumkin.`
- 409 `Bu tashrif uchun sharh allaqachon qoldirilgan.`
- 422 pointer `rating` or `comment`

#### PATCH /v1/consumer/reviews/{id}
Request: `{"rating":4,"comment":"..."}`. Response: the `mine` item. Errors: 404; 422.

#### DELETE /v1/consumer/reviews/{id}
Response: 204. The business rating is recomputed. Errors: 404.

### 4.7 New: business-side reviews (B2, `crm` module, owner+admin)

Routes, added to `api/modules/crm/Module.php` before the `UrlRule`s:
```php
'GET v1/reviews' => 'crm/review/index',
'POST v1/reviews/<id:\d+>/reply' => 'crm/review/reply',
```

#### GET /v1/reviews?rating=&has_reply=0|1&page=1&per_page=20
Tenant-scoped, any status, ordered `created_at DESC`.
```json
{"data":[{"id":88,"rating":5,"comment":"Usta juda e'tiborli!","author_name":"Aziza K.","status":"published",
          "appointment_id":4990,"order_id":null,"staff_id":2,"staff_name":"Usta Jahongir","service_id":11,"service_name":"Soch olish",
          "reply":null,"replied_at":null,"created_at":1791500000}],
 "meta":{"page":1,"per_page":20,"total":15,"pages":1,"avg":4.73,"count":15,"distribution":{"1":0,"2":0,"3":1,"4":2,"5":12}}}
```
Errors: 401; 403 (staff, or no tenant).

#### POST /v1/reviews/{id}/reply
Request: `{"reply":"Rahmat! Sizni yana kutamiz."}`. Sets `reply`, `replied_at=now` and
`replied_by=user.id`; a second call overwrites. Response: the item.

Errors: 404 `Sharh topilmadi.`; 422 pointer `reply` (empty or more than 1000 characters).

### 4.8 Changed: GET/PUT /v1/settings/booking (B2)

The GET payload adds these keys:
`"address":"Chilonzor 9-kvartal, 12-uy","map_url":null,"city":"Toshkent","district":"Chilonzor","lat":41.2756,"lng":69.2034,"description":"...","is_listed":true,"rating_avg":4.73,"rating_count":15`.

PUT (owner+admin) also accepts `address, map_url, city, district, lat, lng, description, is_listed`.
`null` or `""` clears nullable fields. 422 pointers use the column names.

### 4.9 Endpoint count

- New: me 6 + directory 4 + consumer 21 + crm reviews 2 = **33**.
- Changed shape or behavior: auth/login, auth/me, auth/switch, auth/register, team GET/POST/PATCH/DELETE,
  settings/booking GET/PUT, site/{slug}, site/{slug}/booked-days, staff/{id}/availability,
  appointments POST/GET list/GET one, orders POST/GET/PATCH, payments/deposit = **21**.
- Plus the role-gate-only changes in the §2.9 matrix.

---

## 5. File ownership: two parallel implementers

**Rule: a file appears in exactly one column. If you need something from a file you do not own,
use only the API stated here.**

### B1: security hardening, staff `/me`, auth and team

Owns every file in §3.1. Specifically:
- `common/components/Jwt.php`
- `common/models/{User,BusinessUser,Staff}.php`
- `common/rest/{Controller,Cors}.php`
- `common/rbac/Permissions.php`
- `api/modules/auth/**`
- `api/modules/me/**`
- `api/modules/booking/controllers/{Staff,Service,ServiceCategory,Schedule,Upload}Controller.php`
- `api/modules/crm/controllers/{Client,ClientCategory}Controller.php`
- `api/modules/analytics/**`, `api/modules/payroll/**`, `api/modules/inventory/**`
- `api/modules/loyalty/controllers/**`
- `apps/corporate/src/views/Register.vue`
- `console/migrations/m261017_100600_*`
- `console/controllers/SeedStaffController.php`

**Order:** commit `Jwt.php` (§2a) first.

### B2: consumer, directory, reviews, BookingService/OrderService extraction

Owns every file in §3.2. Specifically:
- `common/config/params.php`
- `common/models/{Business,Appointment,Order,ConsumerUser,ConsumerOtpCode,ConsumerFavorite,Review}.php`
- `common/components/ConsumerAuth.php`
- `common/helpers/Categories.php`
- `common/presenters/**`
- `common/engines/SlotEngine.php`
- `api/modules/site/**`
- `api/modules/booking/controllers/{Appointment,Availability,Settings}Controller.php`
- `api/modules/booking/services/BookingService.php`
- `api/modules/catalog/**`
- `api/modules/billing/controllers/PaymentController.php`
- `api/modules/crm/Module.php`, `api/modules/crm/controllers/ReviewController.php`
- `api/modules/consumer/**`, `api/modules/directory/**`
- `console/migrations/m261017_100000..100500_*`
- `console/controllers/SeedConsumerController.php`

### Cross-owner APIs (call these; do not edit the owner's file)

| B2 uses (owned by B1) | Exact API |
|---|---|
| `Jwt` | `Jwt::issue(int $sub, ?int $tid=null, ?string $role=null, string $typ='biz', ?int $ttl=null): string`, `Jwt::parse(string): ?array`, `Jwt::typ(array): string`, `Jwt::expiresAt(?int $ttl=null): int`, `Jwt::TYP_CONSUMER` |
| `common\rest\Controller` | unchanged: `authOptional()`, `currentUser()`, `requireRole(...)`, `body()`, `created()`, `fail422()`. B2 overrides `behaviors()['authenticator']` in its own base classes. |
| `User` | `findIdentityByAccessToken` rejects non-`biz` tokens and loads `activeRole` from the DB. B2 relies on `currentUser()?->activeRole` / `activeTenantId` in `AppointmentController::actionCreate`. |
| `Staff` | read-only use. B2 never writes `staff.user_id`. |

| B1 uses (owned by B2) | Exact API |
|---|---|
| `Appointment` | existing constants/relations only (`STATUS_*`, `STATUSES`, `getClient()`, `getService()`, `getStaff()`, `fields()`). B1 does not add constants to it. |
| `Business` | read-only (`timezone`, `name`, `slug`, `engine`, `logo`, `status`) |
| `common/config/params.php` | B1 needs no new params (role cache TTL = class constant `BusinessUser::ROLE_CACHE_TTL = 60`) |

Off limits to both: `api/config/main.php` (orchestrator), `console/controllers/SeedController.php`
(has uncommitted changes; leave it alone), and `packages/api-client` (Flutter has its own typed
models in `mobile/tizbiz_core`).

---

## 6. Seed commands and demo credentials

Both commands are idempotent (safe to re-run) and resolve demo businesses by slug with aliases
(prod slug first, then local):
`shox-barber|barber`, `aziza-tortlari|tort`, `restoran`, `sanatrix|klinika`, `serenada|ijara`.
A missing business is printed as `skip` and the command continues.

### 6.1 `php yii seed-staff` (B1: `console/controllers/SeedStaffController.php`, `actionIndex`)

For each business in the plan below:
1. Take the first N active staff rows ordered by `id`. If there are none, create a Staff row
   `Demo xodim` (`specialization` `Xodim`).
2. For each staff row, find or create the `users` row with the planned phone. Name = the staff
   name, status 10, password always set to `secret123`.
3. Upsert `business_user(role='staff')`; keep the existing role if the user is already a member.
4. Set `staff.user_id`. Skip when it is already linked to a different user, and print a warning.
5. Print the final table.

| Business | Staff rows | Login phones (password `secret123`) |
|---|---|---|
| shox-barber | first 2 | +998931110001, +998931110002 |
| aziza-tortlari | first 1 | +998932220001 |
| sanatrix | first 2 | +998933330001, +998933330002 |
| serenada | first 1 | +998934440001 |

### 6.2 `php yii seed-consumer` (B2: `console/controllers/SeedConsumerController.php`, `actionIndex`)

1. **Directory fields**: `city='Toshkent'`, `is_listed=1`, plus:

   | slug | district | lat | lng | description |
   |---|---|---|---|---|
   | shox-barber | Chilonzor | 41.2756000 | 69.2034000 | Erkaklar uchun zamonaviy barbershop: soch turmagi, soqol dizayni va parvarish. |
   | aziza-tortlari | Yunusobod | 41.3665000 | 69.2890000 | Buyurtma asosida uy tortlari, shirinliklar va bayram to'plamlari. |
   | restoran | Yakkasaroy | 41.2860000 | 69.2630000 | Milliy taomlar: palov, shashlik, somsa. Oilaviy muhit. |
   | sanatrix | Mirobod | 41.2895000 | 69.2870000 | Ko'p tarmoqli klinika: UZI, tahlillar, shifokor qabuli. |
   | serenada | Sergeli | 41.2270000 | 69.2200000 | To'y va tantanalar uchun zamonaviy zal, 300 mehmongacha. |

   `address` is left as it is. Set it only if NULL (`<district> tumani`). Set `featured_until`
   = now + 30 days for `shox-barber` only.

2. **Demo consumers**, which can log in with OTP `1111`:

   | Phone | Name | City |
   |---|---|---|
   | +998900000001 | Aziza Karimova | Toshkent |
   | +998900000002 | Bobur Rahimov | Toshkent |
   | +998900000003 | Dilnoza Yusupova | Toshkent |

   Plus 12 review-only consumers, which cannot log in because they are not on the demo list:
   +998977000101 .. +998977000112 with realistic names (Sardor Aliyev, Nigora Rashidova,
   Jasur Toshpulatov, Malika Ergasheva, Kamola Saidova, Sanjar Yusupov, Gulnora Aliyeva,
   Otabek Nazarov, Feruza Karimova, Shoxrux Mirzayev, Zilola Umarova, Islom Tursunov).

3. **Per demo business, 8-15 reviews** (count = `10 + business_id % 6`, at most what exists).
   - Slot, medical and rental: use existing `completed` appointments with `consumer_id IS NULL`
     and no review. Set the appointment's `consumer_id` to a reviewer and create the review.
     Rating is 5 (60%), 4 (30%) or 3 (10%), with Uzbek comments picked from a list of 15+
     vertical-specific texts (barber, cake, clinic, hall, restaurant).
     `created_at` = the appointment `ends_at` + 1..48 h.
     About 40% of the reviews get an owner reply such as `Rahmat! Sizni yana kutamiz.`, with
     `replied_by` = the owner user.
   - Catalog: use `delivered` orders the same way. If there are fewer than 8, insert delivered
     orders for reviewers from active services (`source='app'`, `created_at` 3..40 days ago).
   - `restoran` with no services: skip with a message.
   - Afterwards call `Review::recomputeBusinessRating($bid)` for each business.

4. **Rich data for +998900000001 (Aziza)**:
   - Client rows (normalized phone) in shox-barber, aziza-tortlari and sanatrix.
   - `loyalty_accounts`: shox-barber `points=120, cashback_tiyin=1500000`; aziza-tortlari `points=40, cashback_tiyin=500000`.
   - 3 past completed shox-barber appointments (two reviewed, one not, so `can_review=true`).
   - 1 upcoming `pending` shox-barber appointment at the first `AvailabilityService::slots()`
     slot within the next 7 days (first active staff, first online-bookable service, `source='app'`).
   - 1 delivered aziza-tortlari order without a review, and 1 order in status `new`.
   - Favorites: shox-barber, aziza-tortlari.

5. **+998900000002 (Bobur)**: 1 upcoming serenada rental booking (next free evening 30+ days out,
   guests 150) and 1 favorite (serenada).

6. **+998900000003 (Dilnoza)**: empty account, for first-run UX testing.

7. Run `ConsumerLinker::backLink()` for the 3 demo consumers, then print the summary table.

### 6.3 Demo credentials

Business slugs differ per environment (§0): prod slug first, local slug in brackets. The local
owner phones below were checked in the local DB (`business_user`); the prod owner phones come from
the same seed and must be re-checked after the deploy (`SELECT b.slug,u.phone FROM businesses b
JOIN business_user bu ON bu.business_id=b.id AND bu.role='business_owner' JOIN users u ON u.id=bu.user_id`).

| App | Business (prod [local]) | Engine | Role | Phone | Secret |
|---|---|---|---|---|---|
| TizBiz Biznes | shox-barber [barber] | slot | business_owner | +998901111111 | secret123 |
| TizBiz Biznes | aziza-tortlari [tort] | catalog | business_owner | +998902222222 | secret123 |
| TizBiz Biznes | restoran [restoran] | catalog | business_owner | +998905555555 | secret123 |
| TizBiz Biznes | sanatrix [klinika] | medical | business_owner | +998903333333 | secret123 |
| TizBiz Biznes | serenada [ijara] | rental | business_owner | +998904444444 | secret123 |
| TizBiz Biznes | shox-barber [barber] | slot | staff | +998931110001, +998931110002 | secret123 |
| TizBiz Biznes | aziza-tortlari [tort] | catalog | staff | +998932220001 | secret123 |
| TizBiz Biznes | sanatrix [klinika] | medical | staff | +998933330001, +998933330002 | secret123 |
| TizBiz Biznes | serenada [ijara] | rental | staff | +998934440001 | secret123 |
| Bizcat | n/a | n/a | consumer (rich data) | +998900000001 | OTP 1111 |
| Bizcat | n/a | n/a | consumer (rental booking) | +998900000002 | OTP 1111 |
| Bizcat | n/a | n/a | consumer (empty) | +998900000003 | OTP 1111 |

The staff rows exist only after `php yii seed-staff`; the consumers only after
`php yii seed-consumer`.

Note: +998900000001 is also the local business user "Demo Owner" (`users` table). Consumer
accounts live in `consumer_users`, so the two never collide.

---

## 7. Verification plan

### 7.1 Static and migrate
```bash
cd /Users/jahongirxushboqov/Sites/startup
git status --porcelain | awk '{print $2}' | grep '\.php$' | xargs -n1 php -l      # every touched PHP file
php yii migrate --interactive=0          # applies m260917_* then m261017_100000..100600
php yii migrate/down 7 --interactive=0 && php yii migrate --interactive=0   # reversibility (local only)
php yii seed-staff && php yii seed-consumer && php yii seed-consumer        # second run = no duplicates
```

### 7.2 curl checks
`API=https://api.startup` (MAMP; add `-k`), or `http://127.0.0.1:8899` with
`php -S 127.0.0.1:8899 -t api/web api/web/router.php`. Helper: `j(){ curl -sk -o /dev/stdout -w ' %{http_code}\n' "$@"; }`

| # | Check | Expected |
|---|---|---|
| 1 | `POST /v1/auth/login {"phone":"+998901111111","password":"secret123"}` -> OWNER | 200, `active.staff_id` null, `permissions` has `team.manage` |
| 2 | login `+998931110001` -> STAFF | 200, `active.role=staff`, `active.staff_id` int, `active.permissions == ["orders","me"]` |
| 3 | `GET /v1/me/staff` (STAFF) | 200 |
| 4 | `GET /v1/me/appointments?from=<today>&to=<today+7>` (STAFF) | 200, every `staff_id` == me |
| 5 | `PATCH /v1/me/appointments/{a pending one} {"status":"confirmed"}` (STAFF) | 200 |
| 6 | `PATCH /v1/me/appointments/{same} {"status":"canceled"}` (STAFF) | 409 |
| 7 | `PATCH /v1/me/appointments/{other staff's id}` (STAFF) | 404 |
| 8 | `GET /v1/me/stats` (STAFF) | 200 |
| 9 | `GET /v1/me/staff` (OWNER, not linked) | 404 |
| 10 | **NEG** `GET /v1/payroll` (STAFF) | **403** |
| 11 | **NEG** `GET /v1/analytics/overview`, `/v1/clients`, `/v1/deposits/balances`, `/v1/certificates`, `/v1/products`, `/v1/team`, `/v1/appointments`, `/v1/loyalty/settings`, `/v1/staff`, `/v1/services`, `/v1/service-categories`, `/v1/staff/{id}/working-hours`, `/v1/settings/booking`, and `POST /v1/uploads` (STAFF) | **403** each |
| 12 | `GET /v1/orders` and `PATCH /v1/orders/{id} {"status":"preparing"}` with staff `+998932220001` | 200 / 200 |
| 13 | **NEG** `POST /v1/appointments` (STAFF token, valid body) | **403** |
| 14 | `GET /v1/payroll` (OWNER) | 200 |
| 15 | `POST /v1/team {"phone":"+998939990001","name":"Test","role":"staff","password":"secret123"}` (OWNER), login as that user -> T | 201, 200 |
| 16 | `GET /v1/auth/me` with T | 200 |
| 17 | `DELETE /v1/team/{T.user_id}` (OWNER), then **NEG** `GET /v1/auth/me` with T | 204, then **401** |
| 18 | Demote check: add admin -> token A2, `PATCH /v1/team/{id} {"role":"staff"}`, **NEG** `GET /v1/clients` with A2 | 200, then **403** |
| 19 | SMS-only or no-business user token (tid=null): **NEG** `GET /v1/staff`, `/v1/services`, `/v1/orders`, `/v1/certificates`, `/v1/referrals`, `/v1/loyalty/rules` | **403** each |
| 20 | `POST /v1/consumer/auth/otp {"phone":"+998900000001"}` | 200 `sent:true` |
| 21 | `POST /v1/consumer/auth/verify {"phone":"+998900000001","code":"0000"}` | 422 pointer `code` |
| 22 | `POST /v1/consumer/auth/verify {"phone":"+998900000001","code":"1111"}` -> C | 200 |
| 23 | `POST /v1/consumer/auth/otp {"phone":"+998977000101"}` twice within 60 s | 200 or 503 (no SMS configured), then **429** |
| 24 | **NEG** `GET /v1/appointments` with C | **401** |
| 25 | **NEG** `GET /v1/auth/me` with C | **401** |
| 26 | **NEG** `GET /v1/consumer/me` with OWNER token | **401** |
| 27 | `GET /v1/consumer/me`, `/v1/consumer/appointments?scope=past`, `/v1/consumer/loyalty`, `/v1/consumer/favorites` (C) | 200 each; past has one `can_review:true` |
| 28 | `GET /v1/directory/categories` | 200 |
| 29 | `GET /v1/directory/businesses?sort=rating` (anon) | 200, `is_favorite:false`, no `telegram_bot_token`/`features`/`tariff` keys |
| 30 | same with C | `is_favorite:true` for shox-barber |
| 31 | `GET /v1/directory/businesses/shox-barber` and `/reviews` | 200 / 200 with `meta.distribution` |
| 32 | `GET /v1/site/shox-barber` | 200, staff items have only `id,name,specialization` |
| 33 | `GET /v1/staff/{id}/availability?date=<next working day>&service_id=..` -> slot S (`starts_at` = the slot's `start_utc` string; slots are objects `{start_utc,end_utc,start_local}`), then `POST /v1/consumer/appointments` with `Idempotency-Key: k1` (C) | **201**; same request again -> **200**, same id |
| 34 | Same slot again with a new key | **409** |
| 35 | `POST /v1/consumer/appointments/{id}/cancel` (C) | 200 status `canceled` |
| 36 | Set `online_booking_enabled=false` on shox-barber (owner PUT settings), then public `POST /v1/appointments` | **403**; restore afterwards |
| 37 | Public `POST /v1/appointments` with `client.phone:"90 000 00 01"` | 201, `client_id` = the existing client of `+998900000001` (not null) |
| 38 | `POST /v1/consumer/reviews {"appointment_id":<can_review one>,"rating":5}` -> 201; repeat | 201, then **409**; business `rating_count` +1 |
| 39 | `POST /v1/consumer/orders {"slug":"aziza-tortlari","items":[{"service_id":X,"qty":1}]}` + key | 201; `POST .../cancel` -> 200 |
| 40 | `GET /v1/reviews` (OWNER shox-barber) and `POST /v1/reviews/{id}/reply` | 200 / 200; STAFF -> 403 |
| 41 | `POST /v1/payments/deposit {"appointment_id":<canceled>,"provider":"payme"}` | **409** |
| 42 | `OPTIONS /v1/consumer/appointments` with `Access-Control-Request-Headers: idempotency-key` | 204, `Access-Control-Allow-Headers` contains `Idempotency-Key` |
| 43 | `POST /v1/auth/register` with `category:"rental", engine:"slot"` (throwaway slug), then `GET /v1/site/<slug>` | engine `rental` |
| 44 | `DELETE /v1/consumer/me` with a fresh +998900000003 token, then `GET /v1/consumer/me` with the same token | 204, then **401** |

### 7.2.1 Integrator run notes (2026-10-17, local MySQL 5.7, `php -S` on MAMP PHP 8.2)
- `yii migrate` also applied 5 older pending `m2609*_sms_*` migrations that were never run locally (14 in total).
- Check #12 picks the newest `new`/`confirmed` tort order. Locally that is Aziza's seeded `new` order, so re-run
  `php yii seed-consumer` afterwards (it recreates the missing order). Checks #38 and #44 also consume demo state:
  delete the new review on Aziza's reviewable visit (`DELETE /v1/consumer/reviews/{id}`) and re-run `seed-consumer`
  so that +998900000003 exists again.
- Rental `booking_horizon_days` is 30 locally, so consumer rental tests must pick a date at most 30 days ahead.

### 7.3 Regression
The web admin `apps/admin` (owner login) and the storefront `apps/booking` (`?slug=` flows: slot,
catalog, rental) must still work end to end: book, pay (Payme URL returned), order, and booked-days.
Run the existing e2e suite if it is present (memory: 45/45).
