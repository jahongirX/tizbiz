<?php

namespace api\modules\finance\services;

use common\models\Appointment;
use common\models\AppointmentItem;
use common\models\Transaction;
use Yii;
use yii\base\Event;

/**
 * Records what a finished visit actually earned.
 *
 * Most of a barbershop's money never touches Payme or Click: the client pays in
 * the chair. Without this, Moliya only ever showed online deposits and reported
 * an income of zero for a shop that worked all day. On completion we write one
 * `sale` transaction for the visit, minus whatever was already collected as an
 * online deposit, so the two never double-count.
 *
 * Wired to the `appointmentCompleted` event in both the API and console apps,
 * so an appointment closed by hand and one closed by auto-complete are recorded
 * the same way. The idempotency key makes a repeat completion a no-op.
 */
class SaleService
{
    public static function onAppointmentCompleted(Event $e): void
    {
        try {
            $appt = $e->sender;
            if (!$appt instanceof Appointment) {
                return;
            }
            self::record($appt);
        } catch (\Throwable $ex) {
            // Never let bookkeeping break closing an appointment.
            Yii::error('Sale record on appointment completion failed: ' . $ex->getMessage(), __METHOD__);
        }
    }

    public static function record(Appointment $appt): ?Transaction
    {
        $businessId = (int) $appt->business_id;
        $apptId = (int) $appt->id;
        if ($businessId <= 0 || $apptId <= 0) {
            return null;
        }

        $key = 'sale:appointment:' . $apptId;
        $existing = Transaction::find()->where(['idempotency_key' => $key])->one();
        if ($existing !== null) {
            return $existing;
        }

        $total = self::visitTotal($appt);
        // Money already collected online for this visit is its own transaction.
        $prepaid = (int) Transaction::find()
            ->where([
                'appointment_id' => $apptId,
                'type' => Transaction::TYPE_DEPOSIT,
                'status' => Transaction::STATUS_PAID,
            ])
            ->sum('amount_tiyin');

        $due = $total - $prepaid;
        if ($due <= 0) {
            return null; // fully prepaid — nothing changes hands in the shop
        }

        $tx = new Transaction();
        $tx->business_id = $businessId;
        $tx->appointment_id = $apptId;
        $tx->provider = Transaction::PROVIDER_CASH;
        $tx->type = Transaction::TYPE_SALE;
        $tx->status = Transaction::STATUS_PAID;
        $tx->amount_tiyin = $due;
        $tx->idempotency_key = $key;
        if (!$tx->save()) {
            Yii::error('Sale transaction rejected: ' . json_encode($tx->getErrors(), JSON_UNESCAPED_UNICODE), __METHOD__);
            return null;
        }
        return $tx;
    }

    /** Primary service plus every line item sold on the visit. */
    public static function visitTotal(Appointment $appt): int
    {
        $service = $appt->service ?? null;
        $total = $service !== null ? (int) $service->price_tiyin : 0;
        $total += (int) AppointmentItem::find()
            ->where(['appointment_id' => (int) $appt->id])
            ->sum('price_tiyin * qty');
        return $total;
    }
}
