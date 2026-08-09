<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * A single change to a client's account deposit balance (immutable ledger).
 * Balance = SUM(delta_tiyin) for the client. Money in tiyin.
 *
 * @property int $id
 * @property int $business_id
 * @property int $client_id
 * @property int $delta_tiyin
 * @property string $type
 * @property string|null $reason
 * @property int $created_at
 */
class DepositTransaction extends ActiveRecord
{
    public const TYPE_TOPUP = 'topup';
    public const TYPE_SPEND = 'spend';
    public const TYPE_REFUND = 'refund';

    public static function tableName(): string
    {
        return '{{%deposit_transactions}}';
    }

    public static function isTenantScoped(): bool
    {
        return true;
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
            [['client_id', 'delta_tiyin', 'type'], 'required'],
            [['client_id', 'delta_tiyin'], 'integer'],
            [['type'], 'in', 'range' => [self::TYPE_TOPUP, self::TYPE_SPEND, self::TYPE_REFUND]],
            [['reason'], 'string', 'max' => 160],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'client_id' => 'Mijoz',
            'delta_tiyin' => 'Summa',
            'type' => 'Turi',
            'reason' => 'Izoh',
        ];
    }

    public function getClient(): ActiveQuery
    {
        return $this->hasOne(Client::class, ['id' => 'client_id']);
    }
}
