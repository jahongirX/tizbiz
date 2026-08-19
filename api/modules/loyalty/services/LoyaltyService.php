<?php

namespace api\modules\loyalty\services;

use common\models\Appointment;
use common\models\LoyaltyAccount;
use common\models\LoyaltyRule;
use common\models\LoyaltyTransaction;
use common\models\Referral;
use Yii;
use yii\base\Event;
use yii\db\Exception as DbException;
use yii\web\ServerErrorHttpException;
use yii\web\UnprocessableEntityHttpException;

/**
 * Loyalty balance engine. Every balance mutation runs inside a DB transaction
 * and appends an immutable {@see LoyaltyTransaction} ledger row so the account
 * balance always equals the sum of its ledger deltas.
 *
 * Documented rules:
 *  - cashback earned = intdiv(amount_tiyin * earn_rate, 10000)  (earn_rate = basis points)
 *  - points earned   = cashback earned (1 point per tiyin of cashback)
 * All money is in tiyin (1/100 so'm), integers only.
 */
class LoyaltyService
{
    /** Fetch the (business, client) account, creating a zeroed one if absent. */
    public function getOrCreateAccount(int $businessId, int $clientId): LoyaltyAccount
    {
        $account = LoyaltyAccount::find()
            ->where(['business_id' => $businessId, 'client_id' => $clientId])
            ->one();
        if ($account !== null) {
            return $account;
        }

        $account = new LoyaltyAccount();
        $account->business_id = $businessId;
        $account->client_id = $clientId;
        $account->points = 0;
        $account->cashback_tiyin = 0;
        if ($account->save()) {
            return $account;
        }

        // Lost a race on the unique (business_id, client_id) index: re-fetch.
        $existing = LoyaltyAccount::find()
            ->where(['business_id' => $businessId, 'client_id' => $clientId])
            ->one();
        if ($existing !== null) {
            return $existing;
        }

        throw new ServerErrorHttpException('Loyallik hisobini yaratib bo\'lmadi.');
    }

    /** Fetch the (business, client) account without creating one. */
    public function findAccount(int $businessId, int $clientId): ?LoyaltyAccount
    {
        return LoyaltyAccount::find()
            ->where(['business_id' => $businessId, 'client_id' => $clientId])
            ->one();
    }

    /** Active loyalty rule for a business, if configured. */
    public function activeRule(int $businessId): ?LoyaltyRule
    {
        return LoyaltyRule::find()
            ->where(['business_id' => $businessId, 'active' => true])
            ->orderBy(['id' => SORT_DESC])
            ->one();
    }

    /**
     * Credit cashback/points earned on a paid amount. No-op (returns the account
     * unchanged) when there is no active rule, a zero rate, or a non-positive
     * amount produces no cashback.
     */
    public function earn(int $businessId, int $clientId, int $amountTiyin, ?string $ref = null): LoyaltyAccount
    {
        $account = $this->getOrCreateAccount($businessId, $clientId);

        if ($amountTiyin <= 0) {
            return $account;
        }
        $rule = $this->activeRule($businessId);
        if ($rule === null || (int) $rule->earn_rate <= 0) {
            return $account;
        }

        $cashback = intdiv($amountTiyin * (int) $rule->earn_rate, 10000);
        if ($cashback <= 0) {
            return $account;
        }
        $points = $cashback;

        return $this->applyDelta($account, $points, $cashback, LoyaltyTransaction::REASON_EARN, $ref);
    }

    /**
     * Redeem cashback. Fails with 422 when the balance is insufficient.
     */
    public function redeem(int $businessId, int $clientId, int $amountTiyin): LoyaltyAccount
    {
        if ($amountTiyin <= 0) {
            throw new UnprocessableEntityHttpException('Yechib olish summasi musbat bo\'lishi kerak.');
        }
        $account = $this->getOrCreateAccount($businessId, $clientId);

        $tx = Yii::$app->db->beginTransaction();
        try {
            // Atomic, non-negative decrement without row locks: the UPDATE only
            // touches the row when the balance still covers the amount. A zero
            // affected-row count means insufficient funds (or a concurrent
            // redeem won the race). Valid on both MySQL and SQLite.
            $affected = LoyaltyAccount::updateAllCounters(
                ['cashback_tiyin' => -$amountTiyin],
                ['and', ['id' => $account->id], ['>=', 'cashback_tiyin', $amountTiyin]]
            );
            if ($affected === 0) {
                throw new UnprocessableEntityHttpException('Cashback balansi yetarli emas.');
            }

            $this->insertLedger($account, 0, -$amountTiyin, LoyaltyTransaction::REASON_REDEEM, null);
            $tx->commit();
        } catch (\Throwable $e) {
            $tx->rollBack();
            throw $e;
        }

        // Re-load so the response reflects the persisted balance.
        return $this->findAccount($businessId, $clientId) ?? $account;
    }

    /**
     * Grant a referral bonus to the referrer exactly once. Idempotent: only a
     * referral in `pending` status is credited; anything else is returned as-is.
     * The bonus amount is read from the active rule's gift_config
     * (`referral_bonus_tiyin`, `referral_bonus_points`).
     */
    public function creditReferral(int $businessId, int $referralId): Referral
    {
        $tx = Yii::$app->db->beginTransaction();
        try {
            /** @var Referral|null $referral */
            $referral = Referral::find()
                ->where(['id' => $referralId, 'business_id' => $businessId])
                ->one();
            if ($referral === null) {
                throw new UnprocessableEntityHttpException('Taklif topilmadi.');
            }
            // Atomic claim without row locks: flip pending -> granted in one
            // conditional UPDATE. Exactly one caller can win this transition, so
            // the credit below runs at most once. Valid on MySQL and SQLite.
            $claimed = Referral::updateAll(
                ['bonus_status' => Referral::STATUS_GRANTED, 'updated_at' => time()],
                ['and', ['id' => $referral->id], ['bonus_status' => Referral::STATUS_PENDING]]
            );
            if ($claimed !== 1) {
                // Already granted/voided or lost the race — nothing to do.
                $tx->commit();
                return $this->findReferral($businessId, $referralId) ?? $referral;
            }

            [$bonusPoints, $bonusTiyin] = $this->referralBonus($businessId);

            $account = $this->getOrCreateAccount($businessId, (int) $referral->referrer_client_id);
            if ($bonusPoints !== 0 || $bonusTiyin !== 0) {
                $this->writeLedger(
                    $account,
                    $bonusPoints,
                    $bonusTiyin,
                    LoyaltyTransaction::REASON_REFERRAL,
                    'referral:' . $referral->id
                );
            }

            $tx->commit();
            return $this->findReferral($businessId, $referralId) ?? $referral;
        } catch (\Throwable $e) {
            $tx->rollBack();
            throw $e;
        }
    }

    /** Fetch a referral within the given business, if it exists. */
    private function findReferral(int $businessId, int $referralId): ?Referral
    {
        return Referral::find()
            ->where(['id' => $referralId, 'business_id' => $businessId])
            ->one();
    }

    /** Resolve the referral bonus [points, tiyin] from the active rule config. */
    private function referralBonus(int $businessId): array
    {
        $rule = $this->activeRule($businessId);
        $config = $rule !== null && is_array($rule->gift_config) ? $rule->gift_config : [];
        $tiyin = isset($config['referral_bonus_tiyin']) ? (int) $config['referral_bonus_tiyin'] : 0;
        $points = isset($config['referral_bonus_points']) ? (int) $config['referral_bonus_points'] : 0;
        return [$points, $tiyin];
    }

    /**
     * Apply a signed delta to an account atomically and append a ledger row,
     * all within a single DB transaction.
     */
    private function applyDelta(LoyaltyAccount $account, int $deltaPoints, int $deltaCashback, string $reason, ?string $ref): LoyaltyAccount
    {
        $tx = Yii::$app->db->beginTransaction();
        try {
            // Idempotency: when a ref pointer is supplied, a prior ledger row with
            // the same (account_id, reason, ref) means this event already applied.
            // Return the account unchanged — no double credit (e.g. a re-fired
            // appointment completion calling earn('appointment:ID')).
            if ($ref !== null) {
                $exists = LoyaltyTransaction::find()
                    ->where([
                        'account_id' => (int) $account->id,
                        'reason' => $reason,
                        'ref' => $ref,
                    ])
                    ->exists();
                if ($exists) {
                    $tx->commit();
                    return $account;
                }
            }

            $this->writeLedger($account, $deltaPoints, $deltaCashback, $reason, $ref);
            $tx->commit();
            return $account;
        } catch (\Throwable $e) {
            $tx->rollBack();
            throw $e;
        }
    }

    /**
     * Atomically bump the balance (UPDATE ... SET x = x + n) and record the
     * matching immutable ledger row. Must be called inside a transaction.
     */
    private function writeLedger(LoyaltyAccount $account, int $deltaPoints, int $deltaCashback, string $reason, ?string $ref): void
    {
        if ($deltaPoints !== 0 || $deltaCashback !== 0) {
            $account->updateCounters([
                'points' => $deltaPoints,
                'cashback_tiyin' => $deltaCashback,
            ]);
        }

        $this->insertLedger($account, $deltaPoints, $deltaCashback, $reason, $ref);
    }

    /**
     * Append an immutable ledger row without touching the account balance. Use
     * when the balance has already been mutated atomically (e.g. redeem's
     * conditional decrement). Must be called inside a transaction.
     */
    private function insertLedger(LoyaltyAccount $account, int $deltaPoints, int $deltaCashback, string $reason, ?string $ref): void
    {
        $ledger = new LoyaltyTransaction();
        $ledger->account_id = (int) $account->id;
        $ledger->delta_points = $deltaPoints;
        $ledger->delta_cashback_tiyin = $deltaCashback;
        $ledger->reason = $reason;
        $ledger->ref = $ref;
        if (!$ledger->save()) {
            throw new DbException('Unable to write loyalty ledger row: ' . json_encode($ledger->getFirstErrors()));
        }
    }

    /**
     * Event handler: earn loyalty when an appointment is completed. Attached by
     * the orchestrator to Appointment's completion event. Guarded so it can
     * never break the appointment flow.
     */
    public static function onAppointmentCompleted(Event $e): void
    {
        try {
            $appt = $e->sender;
            if (!$appt instanceof Appointment) {
                return;
            }
            $clientId = $appt->client_id !== null ? (int) $appt->client_id : 0;
            $businessId = $appt->business_id !== null ? (int) $appt->business_id : 0;
            if ($clientId <= 0 || $businessId <= 0) {
                return;
            }

            $service = $appt->service ?? null;
            $amount = $service !== null && $service->price_tiyin !== null ? (int) $service->price_tiyin : 0;
            // Extra services booked in the same visit are line items; count them
            // too, or a "soch + soqol" visit would earn cashback on the haircut
            // alone. Products keep their existing (excluded) behaviour.
            $amount += (int) \common\models\AppointmentItem::find()
                ->where([
                    'appointment_id' => (int) $appt->id,
                    'kind' => \common\models\AppointmentItem::KIND_SERVICE,
                ])
                ->sum('price_tiyin * qty');
            if ($amount <= 0) {
                return;
            }

            (new self())->earn($businessId, $clientId, $amount, 'appointment:' . $appt->id);
        } catch (\Throwable $ex) {
            Yii::error('Loyalty earn on appointment completion failed: ' . $ex->getMessage(), __METHOD__);
        }
    }
}
