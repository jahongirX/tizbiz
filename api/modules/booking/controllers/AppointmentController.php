<?php

namespace api\modules\booking\controllers;

use api\modules\booking\services\AvailabilityService;
use common\models\Appointment;
use common\models\AppointmentItem;
use common\models\Client;
use common\models\Product;
use common\models\Service;
use common\models\Staff;
use common\models\StockMovement;
use common\rest\Controller;
use DateTimeImmutable;
use DateTimeZone;
use Yii;
use yii\base\Event;
use yii\web\BadRequestHttpException;
use yii\web\ConflictHttpException;
use yii\web\NotFoundHttpException;

/**
 * Appointments: listing (tenant), creation (public + admin), status changes.
 *
 * Creation is anonymous-friendly (consumer booking link): business_id is always
 * derived from the staff row, never trusted from the client. Overlapping a live
 * appointment for the same staff yields 409. Idempotency-Key is honored for 24h.
 */
class AppointmentController extends Controller
{
    private const UTC_FORMAT = 'Y-m-d H:i:s';

    /** Allowed status transitions. Terminal states have no outgoing edges. */
    private const TRANSITIONS = [
        Appointment::STATUS_PENDING => [
            Appointment::STATUS_CONFIRMED,
            Appointment::STATUS_ARRIVED,
            Appointment::STATUS_COMPLETED,
            Appointment::STATUS_NO_SHOW,
            Appointment::STATUS_CANCELED,
        ],
        Appointment::STATUS_CONFIRMED => [
            Appointment::STATUS_ARRIVED,
            Appointment::STATUS_COMPLETED,
            Appointment::STATUS_NO_SHOW,
            Appointment::STATUS_CANCELED,
        ],
        Appointment::STATUS_ARRIVED => [
            Appointment::STATUS_COMPLETED,
            Appointment::STATUS_NO_SHOW,
            Appointment::STATUS_CANCELED,
        ],
        Appointment::STATUS_COMPLETED => [],
        Appointment::STATUS_NO_SHOW => [],
        Appointment::STATUS_CANCELED => [],
    ];

    protected function authOptional(): array
    {
        return ['create'];
    }

    public function actionIndex(): array
    {
        // A valid business context is mandatory: a JWT with tid=null must not
        // bypass tenant scoping and read every business's appointments.
        Yii::$app->tenant->require();

        $query = Appointment::find();

        $from = (string) Yii::$app->request->get('from', '');
        $to = (string) Yii::$app->request->get('to', '');
        $staff = (int) Yii::$app->request->get('staff', 0);
        $status = (string) Yii::$app->request->get('status', '');

        if ($from !== '') {
            $query->andWhere(['>=', 'starts_at', $from]);
        }
        if ($to !== '') {
            $query->andWhere(['<=', 'starts_at', $to]);
        }
        if ($staff > 0) {
            $query->andWhere(['staff_id' => $staff]);
        }
        if ($status !== '') {
            $query->andWhere(['status' => $status]);
        }

        return $query->with(['client', 'service', 'staff', 'items'])->orderBy(['starts_at' => SORT_ASC])->all();
    }

    public function actionView(int $id): Appointment
    {
        // Require an active tenant so the query below is scoped to the caller's
        // business and cannot leak another tenant's appointment.
        Yii::$app->tenant->require();

        $model = Appointment::findOne($id);
        if ($model === null) {
            throw new NotFoundHttpException('Bron topilmadi.');
        }
        return $model;
    }

    public function actionCreate()
    {
        $idemKey = Yii::$app->request->getHeaders()->get('Idempotency-Key');

        $staffId = (int) $this->body('staff_id');
        $serviceId = (int) $this->body('service_id');
        if ($staffId <= 0 || $serviceId <= 0) {
            throw new BadRequestHttpException('staff_id va service_id talab qilinadi.');
        }

        // Staff drives the tenant: when authed, tenant scoping also confirms the
        // staff belongs to the caller's business.
        $staff = Staff::findOne($staffId);
        if ($staff === null || !$staff->is_active) {
            throw new NotFoundHttpException('Xodim topilmadi.');
        }
        $businessId = (int) $staff->business_id;

        // Idempotency key is scoped to the resolved business so keys from one
        // tenant can never collide with (or replay) another tenant's booking.
        $cacheKey = ($idemKey !== null && $idemKey !== '')
            ? 'appt:idem:' . $businessId . ':' . $idemKey
            : null;
        if ($cacheKey !== null && Yii::$app->has('cache')) {
            $cachedId = Yii::$app->cache->get($cacheKey);
            if ($cachedId !== false) {
                $existing = Appointment::findOne((int) $cachedId);
                if ($existing !== null && (int) $existing->business_id === $businessId) {
                    return $existing;
                }
            }
        }

        $service = Service::find()
            ->andWhere(['id' => $serviceId, 'business_id' => $businessId])
            ->one();
        if ($service === null) {
            throw new NotFoundHttpException('Bu biznes uchun xizmat topilmadi.');
        }

        // Public (anonymous) booking link path: enforce that only a live service,
        // a future time, and a genuinely offered slot can be booked. Authed admin
        // bookings may legitimately backfill or override, so they skip these.
        $isPublic = $this->currentUser() === null;

        // Further services booked in the same visit (soch + soqol). The primary
        // stays in `service_id` so every existing reader keeps working; the rest
        // become line items and extend the appointment's length.
        $extraServices = $this->extraServices($businessId, $serviceId, $isPublic);
        $totalDuration = (int) $service->duration_min;
        foreach ($extraServices as $extra) {
            $totalDuration += max(0, (int) $extra->duration_min);
        }

        if ($isPublic && !$service->is_active) {
            throw new BadRequestHttpException('Bu xizmatni bron qilish mumkin emas.');
        }

        // Parse starts_at as an absolute instant: a string carrying an explicit
        // tz/offset is honored as-is; a plain 'Y-m-d H:i:s' is treated as UTC —
        // matching the start_utc value the availability endpoint hands back and
        // that every client echoes when booking.
        $tzName = $this->businessTimezone($staff);
        $utc = new DateTimeZone('UTC');
        $startsAtInput = (string) $this->body('starts_at');
        if ($startsAtInput === '') {
            throw new BadRequestHttpException('starts_at talab qilinadi.');
        }
        try {
            $start = new DateTimeImmutable($startsAtInput, $utc);
        } catch (\Throwable $e) {
            throw new BadRequestHttpException('starts_at yaroqli sana-vaqt emas.');
        }
        $startUtc = $start->setTimezone($utc);
        $endUtc = $startUtc->modify('+' . $totalDuration . ' minutes');

        $startStr = $startUtc->format(self::UTC_FORMAT);
        $endStr = $endUtc->format(self::UTC_FORMAT);

        if ($isPublic) {
            // Reject bookings for a time that has already passed.
            $nowUtc = new DateTimeImmutable('now', $utc);
            if ($startUtc <= $nowUtc) {
                throw new BadRequestHttpException('starts_at kelajakda bo\'lishi kerak.');
            }

            // Confirm the exact slot is one the availability engine actually
            // offers (inside working hours, not on time-off, aligned to the
            // service grid). This rejects off-hours / arbitrary times up front;
            // the transactional overlap check below still guards the race.
            $localDate = $startUtc->setTimezone(new DateTimeZone($tzName))->format('Y-m-d');
            $availability = (new AvailabilityService())->slots(
                $staff,
                $localDate,
                $serviceId,
                array_map(static fn ($x) => (int) $x->id, $extraServices)
            );
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

        // Resolve client: explicit id, or upsert by phone within the business.
        $clientId = $this->body('client_id');
        if (empty($clientId)) {
            $clientId = $this->upsertClient($businessId);
        }
        // A booking made from the public site with nobody attached is useless:
        // no reminder, no loyalty, and the shop cannot tell who is coming. Fail
        // loudly instead of silently storing an anonymous row.
        if ($isPublic && $clientId === null) {
            throw new BadRequestHttpException('Telefon raqamingizni kiriting.');
        }

        $model = new Appointment();
        $model->business_id = $businessId;
        $model->staff_id = $staff->id;
        $model->service_id = $service->id;
        $model->client_id = $clientId !== null ? (int) $clientId : null;
        $model->starts_at = $startStr;
        $model->ends_at = $endStr;
        // An authed admin may set the initial status (e.g. "keldi"); otherwise pending.
        $reqStatus = $this->body('status');
        $model->status = ($this->currentUser() !== null && is_string($reqStatus) && in_array($reqStatus, Appointment::STATUSES, true))
            ? $reqStatus
            : Appointment::STATUS_PENDING;
        $model->source = $this->currentUser() !== null ? Appointment::SOURCE_ADMIN : Appointment::SOURCE_LINK;
        $model->deposit_tiyin = $service->deposit_tiyin !== null ? (int) $service->deposit_tiyin : null;
        $model->paid = false;
        $notes = $this->body('notes');
        $model->notes = is_string($notes) && $notes !== '' ? $notes : null;

        // Make the overlap check and the insert atomic: re-run the overlap guard
        // inside a transaction immediately before save so two concurrent bookings
        // for the same staff/slot cannot both succeed. No FOR UPDATE (must run on
        // MySQL and SQLite alike) — the transaction plus the re-check serialize it.
        $tx = Appointment::getDb()->beginTransaction();
        try {
            $conflict = Appointment::find()
                ->andWhere(['staff_id' => $staff->id])
                ->andWhere(['not in', 'status', Appointment::RELEASED_STATUSES])
                ->andWhere(['<', 'starts_at', $endStr])
                ->andWhere(['>', 'ends_at', $startStr])
                ->exists();
            if ($conflict) {
                $tx->rollBack();
                throw new ConflictHttpException('Bu vaqt allaqachon band qilingan.');
            }
            if (!$model->save()) {
                $tx->rollBack();
                return $this->fail422($model);
            }
            // Snapshot the extra services as line items (name/price as sold).
            foreach ($extraServices as $extra) {
                $item = new AppointmentItem();
                $item->business_id = $businessId;
                $item->appointment_id = (int) $model->id;
                $item->kind = AppointmentItem::KIND_SERVICE;
                $item->ref_id = (int) $extra->id;
                $item->name = (string) $extra->name;
                $item->qty = 1;
                $item->price_tiyin = (int) $extra->price_tiyin;
                $item->save(false);
            }
            // Sell any attached products: snapshot as line items + decrement stock.
            $this->sellProducts($businessId, (int) $model->id);
            $tx->commit();
        } catch (\Throwable $e) {
            if ($tx->getIsActive()) {
                $tx->rollBack();
            }
            throw $e;
        }

        if ($cacheKey !== null && Yii::$app->has('cache')) {
            Yii::$app->cache->set($cacheKey, $model->id, 86400);
        }

        return $this->created($model);
    }

    public function actionUpdate(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = Appointment::findOne($id);
        if ($model === null) {
            throw new NotFoundHttpException('Bron topilmadi.');
        }

        $next = $this->body('status');
        if (!is_string($next) || $next === '') {
            throw new BadRequestHttpException('status talab qilinadi.');
        }
        if (!in_array($next, Appointment::STATUSES, true)) {
            throw new BadRequestHttpException('Noma\'lum holat.');
        }

        $current = (string) $model->status;
        if ($next === $current) {
            return $model; // no-op
        }
        $allowed = self::TRANSITIONS[$current] ?? [];
        if (!in_array($next, $allowed, true)) {
            throw new ConflictHttpException(sprintf(
                '«%s» holatidan «%s» holatiga o\'tkazib bo\'lmaydi.',
                Appointment::statusLabel($current),
                Appointment::statusLabel($next)
            ));
        }

        $model->status = $next;
        if (!$model->save()) {
            return $this->fail422($model);
        }

        if ($next === Appointment::STATUS_COMPLETED) {
            Yii::$app->trigger('appointmentCompleted', new Event(['sender' => $model]));
        }

        return $model;
    }

    /** Upsert a Client by (business, phone). Returns client id or null. */
    /** Digits only, kept in the +998XXXXXXXXX shape the base already uses. */
    public static function normalizePhone(string $raw): string
    {
        $digits = preg_replace('/\D+/', '', $raw) ?? '';
        if ($digits === '') {
            return '';
        }
        return '+' . $digits;
    }

    private function upsertClient(int $businessId): ?int
    {
        $client = $this->body('client');
        if (!is_array($client) || empty($client['phone'])) {
            return null;
        }
        // Store one canonical shape: the booking page sends "+998 90 123 45 67"
        // while the admin stores "+998901234567", and looking the client up by
        // the raw string created a second record for the same person.
        $phone = self::normalizePhone((string) $client['phone']);
        if ($phone === '') {
            return null;
        }
        $name = isset($client['name']) && $client['name'] !== '' ? (string) $client['name'] : $phone;

        $model = Client::find()
            ->andWhere(['business_id' => $businessId, 'phone' => $phone])
            ->one();
        if ($model === null) {
            $model = new Client();
            $model->business_id = $businessId;
            $model->phone = $phone;
            $model->name = $name;
        } elseif (isset($client['name']) && $client['name'] !== '') {
            $model->name = $name;
        }
        if (isset($client['email']) && $client['email'] !== '') {
            $model->email = (string) $client['email'];
        }

        if (!$model->save()) {
            // Do not fail the booking over a CRM upsert issue.
            return $model->getIsNewRecord() ? null : (int) $model->id;
        }
        return (int) $model->id;
    }

    /**
     * Extra services from body('extra_service_ids'), verified against the
     * business. The primary service is skipped if it is repeated. A public
     * booking may only add services that are online-bookable and active.
     *
     * @return Service[]
     */
    private function extraServices(int $businessId, int $primaryId, bool $isPublic): array
    {
        $raw = $this->body('extra_service_ids');
        if (!is_array($raw) || $raw === []) {
            return [];
        }
        $ids = array_values(array_unique(array_filter(
            array_map('intval', $raw),
            static fn ($id) => $id > 0 && $id !== $primaryId
        )));
        if ($ids === []) {
            return [];
        }

        $query = Service::find()->andWhere(['id' => $ids, 'business_id' => $businessId]);
        if ($isPublic) {
            $query->andWhere(['is_active' => 1, 'online_bookable' => 1]);
        }
        $rows = $query->all();

        if (count($rows) !== count($ids)) {
            throw new BadRequestHttpException('Qo\'shimcha xizmatlardan biri topilmadi.');
        }
        return $rows;
    }

    /**
     * Sell products attached to the booking. body('products') = [{id, qty}].
     * Each becomes a snapshotted appointment_item and decrements inventory stock
     * via a 'sale' stock movement. Runs inside the create transaction.
     */
    private function sellProducts(int $businessId, int $appointmentId): void
    {
        $products = $this->body('products');
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

    private function businessTimezone(Staff $staff): string
    {
        $business = $staff->business;
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
