<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * A manual subscription sale recorded by a superadmin (a lead/account bought a
 * tariff). Feeds the revenue reports. Amount is stored in so'm.
 *
 * @property int $id
 * @property int|null $lead_id
 * @property int|null $account_id
 * @property string|null $name
 * @property string|null $phone
 * @property string|null $tariff
 * @property int $amount
 * @property int $period_months
 * @property int|null $starts_at
 * @property int|null $ends_at
 * @property string|null $note
 * @property int|null $reminder_stage    last expiry-reminder threshold fired (30/15/5/1/0), NULL = none
 * @property int|null $last_reminded_at
 * @property int $created_at
 * @property int $updated_at
 */
class SmsSale extends ActiveRecord
{
    /** Days-before-expiry we warn at, plus 0 = "already expired". High → low. */
    public const REMINDER_DAYS = [30, 15, 5, 1, 0];

    public static function tableName(): string
    {
        return '{{%sms_sales}}';
    }

    public function behaviors(): array
    {
        return [TimestampBehavior::class];
    }

    public function rules(): array
    {
        return [
            [['amount'], 'required'],
            [['lead_id', 'account_id', 'amount', 'period_months', 'starts_at', 'ends_at', 'reminder_stage', 'last_reminded_at'], 'integer'],
            [['amount', 'period_months'], 'integer', 'min' => 0],
            [['name'], 'string', 'max' => 160],
            [['phone'], 'string', 'max' => 32],
            [['tariff'], 'string', 'max' => 20],
            [['note'], 'string', 'max' => 500],
            [['period_months'], 'default', 'value' => 12],
        ];
    }

    /** Whole days until the contract lapses (negative once expired); null if open-ended. */
    public function daysLeft(): ?int
    {
        if (!$this->ends_at) {
            return null;
        }
        return (int) ceil(($this->ends_at - time()) / 86400);
    }

    /**
     * The reminder threshold that is due to fire right now, or null if none is —
     * the smallest {@see REMINDER_DAYS} bucket the contract has crossed that has
     * not been reminded yet. Returns 0 for a just-expired contract.
     */
    public function pendingStage(): ?int
    {
        $days = $this->daysLeft();
        if ($days === null) {
            return null;
        }
        $fired = $this->reminder_stage; // null, or the last threshold already sent
        // Most-urgent first (0,1,5,15,30): if the cron missed days or the contract
        // was added late in its term, jump straight to the tightest bucket crossed.
        foreach (array_reverse(self::REMINDER_DAYS) as $t) {
            if ($days <= $t && ($fired === null || $fired > $t)) {
                return $t;
            }
        }
        return null;
    }
}
