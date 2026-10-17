<?php

namespace api\modules\consumer\components;

use common\models\Appointment;
use common\models\Business;
use common\models\Order;
use common\models\Review;
use common\presenters\BusinessPresenter;
use Yii;
use yii\db\Query;

/**
 * Consumer-facing item shapes for appointments and orders (Bizcat "My bookings"
 * / "My orders"). Lists should eager-load `business`, `staff`, `service`
 * (appointments) or `business`, `items` (orders) and pass a review map from
 * {@see reviewMap()} to avoid N+1 queries.
 */
final class ConsumerItems
{
    private const LIVE_UPCOMING = [
        Appointment::STATUS_PENDING,
        Appointment::STATUS_CONFIRMED,
        Appointment::STATUS_ARRIVED,
    ];

    /** Statuses a consumer may cancel from (subset of AppointmentController::TRANSITIONS to canceled). */
    public const CANCELABLE = [Appointment::STATUS_PENDING, Appointment::STATUS_CONFIRMED];

    /** @return string[] */
    public static function upcomingStatuses(): array
    {
        return self::LIVE_UPCOMING;
    }

    /**
     * review id per appointment_id or order_id.
     *
     * @param int[] $ids
     * @return array<int,int>
     */
    public static function reviewMap(string $column, array $ids): array
    {
        $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));
        if ($ids === [] || !in_array($column, ['appointment_id', 'order_id'], true)) {
            return [];
        }
        $rows = (new Query())
            ->select(['id', $column])
            ->from(Review::tableName())
            ->where([$column => $ids])
            ->all(Yii::$app->db);
        $out = [];
        foreach ($rows as $r) {
            $out[(int) $r[$column]] = (int) $r['id'];
        }
        return $out;
    }

    /** Sources whose notes the client typed (app, booking link, Telegram). */
    private const CLIENT_NOTE_SOURCES = [Appointment::SOURCE_APP, Appointment::SOURCE_LINK, Appointment::SOURCE_TELEGRAM];

    /**
     * Notes are shown only on client-made bookings. Admin-made bookings that were
     * back-linked by phone carry staff-internal remarks, which stay hidden (null).
     */
    public static function clientNotes(Appointment $a): ?string
    {
        return in_array((string) $a->source, self::CLIENT_NOTE_SOURCES, true) ? $a->notes : null;
    }

    public static function canCancelAppointment(Appointment $a): bool
    {
        return in_array((string) $a->status, self::CANCELABLE, true)
            && self::startsInFuture($a)
            && !$a->paid;
    }

    public static function startsInFuture(Appointment $a): bool
    {
        return (string) $a->starts_at > gmdate('Y-m-d H:i:s');
    }

    public static function appointment(Appointment $a, ?int $reviewId = null, bool $reviewKnown = false): array
    {
        if (!$reviewKnown) {
            $reviewId = self::reviewMap('appointment_id', [(int) $a->id])[(int) $a->id] ?? null;
        }
        $business = $a->business;
        $staff = $a->staff;
        $service = $a->service;

        return [
            'id' => (int) $a->id,
            'status' => (string) $a->status,
            'starts_at' => (string) $a->starts_at,
            'ends_at' => (string) $a->ends_at,
            'guests' => $a->guests !== null ? (int) $a->guests : null,
            'deposit_tiyin' => $a->deposit_tiyin !== null ? (int) $a->deposit_tiyin : null,
            'paid' => (bool) $a->paid,
            'notes' => self::clientNotes($a),
            'source' => (string) $a->source,
            'created_at' => (int) $a->created_at,
            'business' => $business instanceof Business ? BusinessPresenter::consumerSubset($business) : null,
            'staff' => $staff !== null ? ['id' => (int) $staff->id, 'name' => (string) $staff->name] : null,
            'service' => $service !== null ? [
                'id' => (int) $service->id,
                'name' => (string) $service->name,
                'duration_min' => (int) $service->duration_min,
                'price_tiyin' => (int) $service->price_tiyin,
            ] : null,
            'can_cancel' => self::canCancelAppointment($a),
            'can_review' => (string) $a->status === Appointment::STATUS_COMPLETED && $reviewId === null,
            'review_id' => $reviewId,
        ];
    }

    /**
     * @param Appointment[] $models
     */
    public static function appointments(array $models): array
    {
        $map = self::reviewMap('appointment_id', array_map(static fn (Appointment $a) => (int) $a->id, $models));
        return array_map(
            static fn (Appointment $a) => self::appointment($a, $map[(int) $a->id] ?? null, true),
            $models
        );
    }

    public static function order(Order $o, ?int $reviewId = null, bool $reviewKnown = false): array
    {
        if (!$reviewKnown) {
            $reviewId = self::reviewMap('order_id', [(int) $o->id])[(int) $o->id] ?? null;
        }
        $business = $o->business;
        $items = $o->items;

        return [
            'id' => (int) $o->id,
            'status' => (string) $o->status,
            'total_tiyin' => (int) $o->total_tiyin,
            'customer_name' => $o->customer_name,
            'customer_phone' => $o->customer_phone,
            'note' => $o->note,
            'source' => (string) $o->source,
            'created_at' => (int) $o->created_at,
            'items' => array_map(static fn ($it) => [
                'id' => (int) $it->id,
                'service_id' => $it->service_id !== null ? (int) $it->service_id : null,
                'name' => (string) $it->name,
                'price_tiyin' => (int) $it->price_tiyin,
                'qty' => (int) $it->qty,
            ], $items),
            'items_count' => count($items),
            'business' => $business instanceof Business ? BusinessPresenter::consumerSubset($business) : null,
            'can_cancel' => (string) $o->status === Order::STATUS_NEW,
            'can_review' => (string) $o->status === Order::STATUS_DELIVERED && $reviewId === null,
            'review_id' => $reviewId,
        ];
    }

    /**
     * @param Order[] $models
     */
    public static function orders(array $models): array
    {
        $map = self::reviewMap('order_id', array_map(static fn (Order $o) => (int) $o->id, $models));
        return array_map(
            static fn (Order $o) => self::order($o, $map[(int) $o->id] ?? null, true),
            $models
        );
    }
}
