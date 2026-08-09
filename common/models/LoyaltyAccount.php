<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Per-client loyalty balance within a business (tenant-scoped).
 * Balances are mutated only through {@see \api\modules\loyalty\services\LoyaltyService},
 * which writes an immutable {@see LoyaltyTransaction} ledger row for every change.
 *
 * @property int $id
 * @property int $business_id
 * @property int $client_id
 * @property int $points
 * @property int $cashback_tiyin  balance in tiyin (1/100 so'm)
 * @property int $created_at
 * @property int $updated_at
 *
 * @property-read Business $business
 * @property-read Client $client
 * @property-read LoyaltyTransaction[] $transactions
 */
class LoyaltyAccount extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%loyalty_accounts}}';
    }

    public static function isTenantScoped(): bool
    {
        return true;
    }

    public function behaviors(): array
    {
        return [
            TimestampBehavior::class,
        ];
    }

    public function rules(): array
    {
        return [
            [['business_id', 'client_id'], 'required'],
            [['business_id', 'client_id', 'points', 'cashback_tiyin'], 'integer'],
            [['points', 'cashback_tiyin'], 'default', 'value' => 0],
            [['client_id'], 'unique', 'targetAttribute' => ['business_id', 'client_id']],
            [['client_id'], 'exist', 'targetClass' => Client::class, 'targetAttribute' => 'id'],
        ];
    }

    public function getBusiness(): ActiveQuery
    {
        return $this->hasOne(Business::class, ['id' => 'business_id']);
    }

    public function getClient(): ActiveQuery
    {
        return $this->hasOne(Client::class, ['id' => 'client_id']);
    }

    public function getTransactions(): ActiveQuery
    {
        return $this->hasMany(LoyaltyTransaction::class, ['account_id' => 'id']);
    }
}
