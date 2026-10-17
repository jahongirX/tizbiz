<?php

namespace api\modules\booking\services;

use common\helpers\Phone;
use common\models\Appointment;
use common\models\AppointmentItem;
use common\models\Business;
use common\models\Client;
use common\models\ConsumerUser;
use common\models\Product;
use common\models\Service;
use common\models\Staff;
use common\models\StockMovement;
use DateInterval;
use DateTimeImmutable;
use DateTimeZone;
use Yii;
use yii\web\BadRequestHttpException;
use yii\web\ConflictHttpException;
use yii\web\ForbiddenHttpException;
use yii\web\NotFoundHttpException;

/**
 * Appointment creation shared by POST /v1/appointments (public booking link and
 * admin) and POST /v1/consumer/appointments (Bizcat app).
 *
 * Modes:
 *  - public:   anonymous booking link. Server-side booking rules enforced; source=link.
 *  - consumer: Bizcat consumer. Same rules; client = the consumer's phone; consumer_id
 *              set; source=app; status=pending.
 *  - admin:    business owner/admin. Rules skipped (backfill / override allowed),
 *              may set status, client_id and attach products; source=admin.
 *
 * business_id is always derived from the staff row, never trusted from input.
 * Overlap with a live appointment yields 409; the check and the insert run in one
 * transaction that first locks the staff row (slot) or business row (rental)
 * FOR UPDATE, so concurrent requests queue instead of double-booking.
 * Idempotency-Key is honored for 24 h; the key is re-checked under that lock.
 */
final class BookingService
{
    public const MODE_PUBLIC = 'public';
    public const MODE_ADMIN = 'admin';
    public const MODE_CONSUMER = 'consumer';

    private const UTC_FORMAT = 'Y-m-d H:i:s';

    /** Body value as a string; arrays/objects (malformed JSON input) become '' so they fail validation with a 400, not a 500. */
    private static function scalar($v): string
    {
        return is_scalar($v) ? (string) $v : '';
    }
    private const IDEM_TTL = 86400;

    /**
     * @param array $body the POST v1/appointments JSON body
     * @return array{0: Appointment, 1: bool} [model, replayed]. When $model->hasErrors()
     *         the caller returns fail422($model).
     * @throws BadRequestHttpException|NotFoundHttpException|ConflictHttpException|ForbiddenHttpException
     */
    public function create(array $body, string $mode, ?string $idempotencyKey, ?ConsumerUser $consumer = null): array
    {
        if (!in_array($mode, [self::MODE_PUBLIC, self::MODE_ADMIN, self::MODE_CONSUMER], true)) {
            throw new \InvalidArgumentException('Unknown booking mode: ' . $mode);
        }
        if ($mode === self::MODE_CONSUMER && $consumer === null) {
            throw new \InvalidArgumentException('Consumer mode requires a consumer.');
        }
        $enforce = $mode !== self::MODE_ADMIN;

        $staffId = (int) ($body['staff_id'] ?? 0);
        $serviceId = (int) ($body['service_id'] ?? 0);
        if ($staffId <= 0 || $serviceId <= 0) {
            throw new BadRequestHttpException('staff_id va service_id talab qilinadi.');
        }

        // Staff drives the tenant: in admin mode tenant scoping also confirms the
        // staff belongs to the caller's business.
        $staff = Staff::findOne($staffId);
        if ($staff === null || !$staff->is_active) {
            throw new NotFoundHttpException('Xodim topilmadi.');
        }
        $businessId = (int) $staff->business_id;

        // Idempotency key is scoped to the resolved business (and, for consumers,
        // to the consumer) so keys can never collide with or replay another
        // tenant's / another consumer's booking.
        $cacheKey = null;
        if ($idempotencyKey !== null && $idempotencyKey !== '') {
            $cacheKey = $mode === self::MODE_CONSUMER
                ? 'appt:idem:c' . (int) $consumer->id . ':' . $businessId . ':' . $idempotencyKey
                : 'appt:idem:' . $businessId . ':' . $idempotencyKey;
        }
        $replay = $this->replay($cacheKey, $businessId, $mode === self::MODE_CONSUMER ? (int) $consumer->id : null);
        if ($replay !== null) {
            return [$replay, true];
        }

        $business = Business::findOne($businessId);
        if ($enforce) {
            if ($business === null || (int) $business->status !== Business::STATUS_ACTIVE) {
                throw new NotFoundHttpException('Biznes topilmadi.');
            }
            if (!$business->online_booking_enabled) {
                throw new ForbiddenHttpException('Bu biznesda onlayn yozilish yopiq.');
            }
        }

        $service = Service::find()
            ->andWhere(['id' => $serviceId, 'business_id' => $businessId])
            ->one();
        if ($service === null) {
            throw new NotFoundHttpException('Bu biznes uchun xizmat topilmadi.');
        }
        if ($enforce && !($service->is_active && $service->online_bookable)) {
            throw new BadRequestHttpException('Bu xizmatni bron qilish mumkin emas.');
        }

        // Rental / wedding-hall engine: whole-day (or session) hall reservation,
        // one event per slot of the day across the business.
        if ($business !== null && (string) $business->engine === 'rental') {
            return $this->createRental($body, $mode, $staff, $service, $business, $cacheKey, $consumer);
        }

        return $this->createSlot($body, $mode, $staff, $service, $businessId, $cacheKey, $consumer);
    }

    /** Return the appointment previously created under this idempotency key, if any. */
    private function replay(?string $cacheKey, int $businessId, ?int $consumerId): ?Appointment
    {
        if ($cacheKey === null || !Yii::$app->has('cache')) {
            return null;
        }
        $cachedId = Yii::$app->cache->get($cacheKey);
        if ($cachedId === false) {
            return null;
        }
        $existing = Appointment::findOne((int) $cachedId);
        if ($existing === null || (int) $existing->business_id !== $businessId) {
            return null;
        }
        if ($consumerId !== null && (int) $existing->consumer_id !== $consumerId) {
            return null;
        }
        return $existing;
    }

    private function remember(?string $cacheKey, Appointment $model): void
    {
        if ($cacheKey !== null && Yii::$app->has('cache')) {
            Yii::$app->cache->set($cacheKey, (int) $model->id, self::IDEM_TTL);
        }
    }

    private function forget(?string $cacheKey): void
    {
        if ($cacheKey !== null && Yii::$app->has('cache')) {
            Yii::$app->cache->delete($cacheKey);
        }
    }

    /** SELECT ... FOR UPDATE on one primary-key row (MySQL 5.7 / MariaDB 10.11). */
    private function lockRow(string $table, int $id): void
    {
        Appointment::getDb()
            ->createCommand('SELECT id FROM ' . $table . ' WHERE id = :id FOR UPDATE', [':id' => $id])
            ->queryScalar();
    }

    /** @return array{0: Appointment, 1: bool} */
    private function createSlot(array $body, string $mode, Staff $staff, Service $service, int $businessId, ?string $cacheKey, ?ConsumerUser $consumer): array
    {
        $enforce = $mode !== self::MODE_ADMIN;

        // Parse starts_at as an absolute instant: a string carrying an explicit
        // tz/offset is honored as-is; a plain 'Y-m-d H:i:s' is treated as UTC —
        // matching the start_utc value the availability endpoint hands back.
        $tzName = self::businessTimezone($staff->business);
        $utc = new DateTimeZone('UTC');
        $startsAtInput = trim(self::scalar($body['starts_at'] ?? null));
        if ($startsAtInput === '') {
            throw new BadRequestHttpException('starts_at talab qilinadi.');
        }
        try {
            $start = new DateTimeImmutable($startsAtInput, $utc);
        } catch (\Throwable $e) {
            throw new BadRequestHttpException('starts_at yaroqli sana-vaqt emas.');
        }
        $startUtc = $start->setTimezone($utc);
        $endUtc = $startUtc->modify('+' . (int) $service->duration_min . ' minutes');
        $startStr = $startUtc->format(self::UTC_FORMAT);
        $endStr = $endUtc->format(self::UTC_FORMAT);

        if ($enforce) {
            if ($startUtc <= new DateTimeImmutable('now', $utc)) {
                throw new BadRequestHttpException('starts_at kelajakda bo\'lishi kerak.');
            }
            // The exact slot must be one the availability engine offers (working
            // hours, time-off, service grid, lead time and horizon). The
            // transactional overlap check below still guards the race.
            $localDate = $startUtc->setTimezone(new DateTimeZone($tzName))->format('Y-m-d');
            $availability = (new AvailabilityService())->slots($staff, $localDate, (int) $service->id);
            $offered = false;
            foreach ($availability['slots'] as $slot) {
                if ($slot['start_utc'] === $startStr) {
                    $offered = true;
                    break;
                }
            }
            if (!$offered) {
                throw new ConflictHttpException('Tanlangan vaqt band.');
            }
        }

        $model = $this->newModel($body, $mode, $staff, $service, $businessId, $consumer);
        if ($model->hasErrors()) {
            return [$model, false];
        }
        $model->starts_at = $startStr;
        $model->ends_at = $endStr;
        $notes = $body['notes'] ?? null;
        $model->notes = is_string($notes) && trim($notes) !== '' ? $notes : null;

        $tx = Appointment::getDb()->beginTransaction();
        try {
            // Serialize bookings of this staff member: the row lock is taken
            // before any read of the transaction, so a waiting request's overlap
            // check (and idempotency replay) sees the row the winner committed.
            $this->lockRow(Staff::tableName(), (int) $staff->id);
            $replay = $this->replay($cacheKey, $businessId, $consumer !== null ? (int) $consumer->id : null);
            if ($replay !== null) {
                $tx->rollBack();
                return [$replay, true];
            }
            $conflict = Appointment::find()
                ->andWhere(['staff_id' => $staff->id])
                ->andWhere(['not in', 'status', Appointment::RELEASED_STATUSES])
                ->andWhere(['<', 'starts_at', $endStr])
                ->andWhere(['>', 'ends_at', $startStr])
                ->exists();
            if ($conflict) {
                throw new ConflictHttpException('Bu vaqt allaqachon band qilingan.');
            }
            if (!$model->save()) {
                $tx->rollBack();
                return [$model, false];
            }
            // Admin only: sell attached products (line items + stock decrement).
            if ($mode === self::MODE_ADMIN) {
                $this->sellProducts($body['products'] ?? null, $businessId, (int) $model->id);
            }
            // Remember while the lock is held, so a same-key request queued on the
            // lock replays instead of answering 409.
            $this->remember($cacheKey, $model);
            $tx->commit();
        } catch (\Throwable $e) {
            if ($tx->getIsActive()) {
                $tx->rollBack();
            }
            $this->forget($cacheKey);
            throw $e;
        }

        return [$model, false];
    }

    /**
     * Whole-day / session hall booking for the rental engine (wedding halls). No
     * slot grid: the client picks a package, a guest count, a date and a session.
     * Session hours: morning 10:00–16:00, evening 18:00–23:00, none = 10:00–23:00.
     */
    /** @return array{0: Appointment, 1: bool} */
    private function createRental(array $body, string $mode, Staff $staff, Service $service, Business $business, ?string $cacheKey, ?ConsumerUser $consumer): array
    {
        $enforce = $mode !== self::MODE_ADMIN;
        $businessId = (int) $business->id;
        $tz = new DateTimeZone(self::businessTimezone($business));
        $utc = new DateTimeZone('UTC');

        $dateInput = trim(self::scalar($body['date'] ?? null) ?: self::scalar($body['starts_at'] ?? null));
        if ($dateInput === '') {
            throw new BadRequestHttpException('Sana talab qilinadi.');
        }
        $dateOnly = substr($dateInput, 0, 10);
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $dateOnly)) {
            throw new BadRequestHttpException('Sana yaroqli emas.');
        }
        $session = strtolower(trim(self::scalar($body['session'] ?? null)));
        [$startH, $endH] = $session === 'evening' ? [18, 23] : ($session === 'morning' ? [10, 16] : [10, 23]);
        $day = DateTimeImmutable::createFromFormat('!Y-m-d', $dateOnly, $tz);
        if ($day === false || $day->format('Y-m-d') !== $dateOnly) {
            throw new BadRequestHttpException('Sana yaroqli emas.');
        }
        $localStart = $day->setTime($startH, 0);
        $localEnd = $day->setTime($endH, 0);

        if ($enforce) {
            $nowLocal = new DateTimeImmutable('now', $tz);
            $todayLocal = $nowLocal->setTime(0, 0);
            if ($day < $todayLocal) {
                throw new BadRequestHttpException('Sana kelajakda bo\'lishi kerak.');
            }
            $leadMin = max(0, (int) $business->booking_lead_min);
            $minStart = $nowLocal->add(new DateInterval('PT' . $leadMin . 'M'));
            $horizonDays = max(0, (int) $business->booking_horizon_days);
            $maxDay = $todayLocal->add(new DateInterval('P' . $horizonDays . 'D'));
            if ($localStart < $minStart || $day > $maxDay) {
                throw new BadRequestHttpException('Sana bron qilish oralig\'idan tashqarida.');
            }
        }

        $startStr = $localStart->setTimezone($utc)->format(self::UTC_FORMAT);
        $endStr = $localEnd->setTimezone($utc)->format(self::UTC_FORMAT);

        $guests = (int) ($body['guests'] ?? 0);
        if ($guests < 1) {
            $guests = 0; // optional; 0 means "not specified"
        }

        $model = $this->newModel($body, $mode, $staff, $service, $businessId, $consumer);
        if ($model->hasErrors()) {
            return [$model, false];
        }
        // Rental bookings always start pending (no admin status override, as before).
        $model->status = Appointment::STATUS_PENDING;
        $model->guests = $guests > 0 ? $guests : null;
        $model->starts_at = $startStr;
        $model->ends_at = $endStr;
        $notesParts = [];
        if ($session === 'morning') {
            $notesParts[] = 'Ertalab';
        } elseif ($session === 'evening') {
            $notesParts[] = 'Kechqurun';
        }
        if ($guests > 0) {
            $notesParts[] = $guests . ' mehmon · ' . (int) ceil($guests / 10) . ' stol';
        }
        $extraNote = $body['notes'] ?? null;
        if (is_string($extraNote) && trim($extraNote) !== '') {
            $notesParts[] = $extraNote;
        }
        $model->notes = $notesParts ? implode(' · ', $notesParts) : null;

        // One event per time span: reject if any live appointment of the business
        // overlaps. The business row lock serializes concurrent hall bookings.
        $tx = Appointment::getDb()->beginTransaction();
        try {
            $this->lockRow(Business::tableName(), $businessId);
            $replay = $this->replay($cacheKey, $businessId, $consumer !== null ? (int) $consumer->id : null);
            if ($replay !== null) {
                $tx->rollBack();
                return [$replay, true];
            }
            $conflict = Appointment::find()
                ->andWhere(['business_id' => $businessId])
                ->andWhere(['not in', 'status', Appointment::RELEASED_STATUSES])
                ->andWhere(['<', 'starts_at', $endStr])
                ->andWhere(['>', 'ends_at', $startStr])
                ->exists();
            if ($conflict) {
                throw new ConflictHttpException('Bu sana allaqachon band.');
            }
            if (!$model->save()) {
                $tx->rollBack();
                return [$model, false];
            }
            $this->remember($cacheKey, $model);
            $tx->commit();
        } catch (\Throwable $e) {
            if ($tx->getIsActive()) {
                $tx->rollBack();
            }
            $this->forget($cacheKey);
            throw $e;
        }

        return [$model, false];
    }

    /** Common fields of a new appointment for the given mode. */
    private function newModel(array $body, string $mode, Staff $staff, Service $service, int $businessId, ?ConsumerUser $consumer): Appointment
    {
        $model = new Appointment();
        $model->business_id = $businessId;
        $model->staff_id = (int) $staff->id;
        $model->service_id = (int) $service->id;
        $model->deposit_tiyin = $service->deposit_tiyin !== null ? (int) $service->deposit_tiyin : null;
        $model->paid = false;
        $model->status = Appointment::STATUS_PENDING;

        if ($mode === self::MODE_CONSUMER) {
            $name = isset($body['name']) && is_string($body['name']) && trim($body['name']) !== '' ? trim($body['name']) : null;
            $model->client_id = $this->upsertClient(
                $businessId,
                ['phone' => (string) $consumer->phone, 'name' => $name],
                $consumer->name ?: (string) $consumer->phone
            );
            $model->consumer_id = (int) $consumer->id;
            $model->source = Appointment::SOURCE_APP;
            return $model;
        }

        if ($mode === self::MODE_ADMIN) {
            $clientId = $body['client_id'] ?? null;
            if (!empty($clientId)) {
                // The client must belong to the staff's business (no cross-tenant refs).
                $exists = is_scalar($clientId) && ctype_digit((string) $clientId) && Client::find()
                    ->andWhere([Client::tableName() . '.id' => (int) $clientId, Client::tableName() . '.business_id' => $businessId])
                    ->exists();
                if (!$exists) {
                    $model->addError('client_id', 'Mijoz topilmadi.');
                    return $model;
                }
                $model->client_id = (int) $clientId;
            } else {
                $model->client_id = $this->upsertClient($businessId, is_array($body['client'] ?? null) ? $body['client'] : null, null, true);
            }
            // An admin may set the initial status (e.g. "keldi"); otherwise pending.
            $reqStatus = $body['status'] ?? null;
            if (is_string($reqStatus) && in_array($reqStatus, Appointment::STATUSES, true)) {
                $model->status = $reqStatus;
            }
            $model->source = Appointment::SOURCE_ADMIN;
            return $model;
        }

        // Public booking link.
        $model->client_id = $this->upsertClient($businessId, is_array($body['client'] ?? null) ? $body['client'] : null, null);
        $model->source = Appointment::SOURCE_LINK;
        return $model;
    }

    /**
     * Upsert a Client by (business, normalized phone). The phone is normalized
     * BEFORE the lookup so "90 000 00 01" finds the stored "+998900000001".
     * $fallbackName names a newly created client when $client['name'] is empty.
     * An existing client's name/email is only replaced when $overwrite is true
     * (admin mode); public and consumer input only fills an empty name (or a
     * phone-as-name placeholder) and an empty email, never renames a CRM client.
     * Returns the client id, or null when no phone was given / the save failed.
     */
    public function upsertClient(int $businessId, ?array $client, ?string $fallbackName, bool $overwrite = false): ?int
    {
        if (!is_array($client) || empty($client['phone']) || !is_scalar($client['phone'])) {
            return null;
        }
        $rawPhone = (string) $client['phone'];
        $phone = Phone::normalize($rawPhone) ?? $rawPhone;
        $givenName = isset($client['name']) && is_string($client['name']) && trim($client['name']) !== ''
            ? trim($client['name'])
            : null;

        $model = Client::find()
            ->andWhere(['business_id' => $businessId, 'phone' => $phone])
            ->one();
        if ($model === null) {
            $model = new Client();
            $model->business_id = $businessId;
            $model->phone = $phone;
            $model->name = $givenName ?? ($fallbackName !== null && $fallbackName !== '' ? $fallbackName : $phone);
        } elseif ($givenName !== null
            && ($overwrite || trim((string) $model->name) === '' || (string) $model->name === (string) $model->phone)) {
            $model->name = $givenName;
        }
        if (isset($client['email']) && is_string($client['email']) && $client['email'] !== ''
            && ($overwrite || $model->getIsNewRecord() || trim((string) $model->email) === '')) {
            $model->email = $client['email'];
        }

        if (!$model->save()) {
            // Do not fail the booking over a CRM upsert issue.
            return $model->getIsNewRecord() ? null : (int) $model->id;
        }
        return (int) $model->id;
    }

    /**
     * Sell products attached to an admin booking. $products = [{id, qty}]. Each
     * becomes a snapshotted appointment_item and decrements stock via a 'sale'
     * stock movement. Runs inside the create transaction.
     */
    private function sellProducts($products, int $businessId, int $appointmentId): void
    {
        if (!is_array($products)) {
            return;
        }
        foreach ($products as $row) {
            if (!is_array($row) || empty($row['id'])) {
                continue;
            }
            $qty = max(1, (int) ($row['qty'] ?? 1));
            $product = Product::find()
                ->andWhere(['id' => (int) $row['id'], 'business_id' => $businessId])
                ->one();
            if ($product === null) {
                continue;
            }

            $item = new AppointmentItem();
            $item->business_id = $businessId;
            $item->appointment_id = $appointmentId;
            $item->kind = AppointmentItem::KIND_PRODUCT;
            $item->ref_id = (int) $product->id;
            $item->name = (string) $product->name;
            $item->qty = $qty;
            $item->price_tiyin = (int) $product->price_tiyin;
            $item->save(false);

            $product->stock_qty = (int) $product->stock_qty - $qty;
            $product->save(false, ['stock_qty', 'updated_at']);

            $mv = new StockMovement();
            $mv->business_id = $businessId;
            $mv->product_id = (int) $product->id;
            $mv->delta_qty = -$qty;
            $mv->type = StockMovement::TYPE_SALE;
            $mv->reason = 'Bron #' . $appointmentId;
            $mv->save(false);
        }
    }

    /** Valid IANA timezone of the business, falling back to Asia/Tashkent. */
    public static function businessTimezone(?Business $business): string
    {
        $tz = $business !== null ? (string) $business->timezone : '';
        if ($tz === '') {
            return 'Asia/Tashkent';
        }
        try {
            new DateTimeZone($tz);
        } catch (\Throwable $e) {
            return 'Asia/Tashkent';
        }
        return $tz;
    }
}
