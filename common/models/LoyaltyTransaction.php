<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Immutable ledger of loyalty balance changes. Rows are append-only: they are
 * created together with the matching balance mutation inside a DB transaction
 * and are never updated or deleted.
 *
 * NOT tenant-scoped: rows carry no business_id and are keyed by account_id
 * (the owning {@see LoyaltyAccount} carries the tenant).
 *
 * @property int $id
 * @property int $account_id
 * @property int $delta_points
 * @property int $delta_cashback_tiyin  signed change in tiyin
 * @property string $reason  earn|redeem|gift|referral|adjust
 * @property string|null $ref  free-form pointer, e.g. "appointment:123"
 * @property int $created_at
 *
 * @property-read LoyaltyAccount $account
 */
class LoyaltyTransaction extends ActiveRecord
{
    public const REASON_EARN = 'earn';
    public const REASON_REDEEM = 'redeem';
    public const REASON_GIFT = 'gift';
    public const REASON_REFERRAL = 'referral';
    public const REASON_ADJUST = 'adjust';

    public const REASONS = [
        self::REASON_EARN,
        self::REASON_REDEEM,
        self::REASON_GIFT,
        self::REASON_REFERRAL,
        self::REASON_ADJUST,
    ];

    public static function tableName(): string
    {
        return '{{%loyalty_transactions}}';
    }

    public function behaviors(): array
    {
        return [
            [
                'class' => TimestampBehavior::class,
                'updatedAtAttribute' => false,
            ],
        ];
    }

    public function rules(): array
    {
        return [
            [['account_id', 'reason'], 'required'],
            [['account_id', 'delta_points', 'delta_cashback_tiyin'], 'integer'],
            [['delta_points', 'delta_cashback_tiyin'], 'default', 'value' => 0],
            [['reason'], 'in', 'range' => self::REASONS],
            [['ref'], 'string', 'max' => 64],
            [['account_id'], 'exist', 'targetClass' => LoyaltyAccount::class, 'targetAttribute' => 'id'],
        ];
    }

    /** Ledger rows are immutable; block any update once persisted. */
    public function beforeSave($insert): bool
    {
        if (!$insert) {
            return false;
        }
        return parent::beforeSave($insert);
    }

    public function getAccount(): ActiveQuery
    {
        return $this->hasOne(LoyaltyAccount::class, ['id' => 'account_id']);
    }
}
