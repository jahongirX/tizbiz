<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Client-brings-a-friend tracking (tenant-scoped).
 * bonus_status: pending -> granted (bonus credited once) | void.
 *
 * @property int $id
 * @property int $business_id
 * @property int $referrer_client_id
 * @property int|null $referred_client_id
 * @property string $bonus_status  pending|granted|void
 * @property int $created_at
 * @property int $updated_at
 *
 * @property-read Business $business
 * @property-read Client $referrer
 * @property-read Client $referred
 */
class Referral extends ActiveRecord
{
    public const STATUS_PENDING = 'pending';
    public const STATUS_GRANTED = 'granted';
    public const STATUS_VOID = 'void';

    public const STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_GRANTED,
        self::STATUS_VOID,
    ];

    public static function tableName(): string
    {
        return '{{%referrals}}';
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
            [['referrer_client_id'], 'required'],
            [['business_id', 'referrer_client_id', 'referred_client_id'], 'integer'],
            [['bonus_status'], 'in', 'range' => self::STATUSES],
            [['bonus_status'], 'default', 'value' => self::STATUS_PENDING],
            [['referrer_client_id'], 'exist', 'targetClass' => Client::class, 'targetAttribute' => 'id'],
            [['referred_client_id'], 'exist', 'targetClass' => Client::class, 'targetAttribute' => 'id', 'skipOnEmpty' => true],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'referrer_client_id' => 'Taklif qilgan mijoz',
            'referred_client_id' => 'Taklif qilingan mijoz',
            'bonus_status' => 'Bonus holati',
            'created_at' => 'Yaratilgan sana',
            'updated_at' => 'Yangilangan sana',
        ];
    }

    public function getBusiness(): ActiveQuery
    {
        return $this->hasOne(Business::class, ['id' => 'business_id']);
    }

    public function getReferrer(): ActiveQuery
    {
        return $this->hasOne(Client::class, ['id' => 'referrer_client_id']);
    }

    public function getReferred(): ActiveQuery
    {
        return $this->hasOne(Client::class, ['id' => 'referred_client_id']);
    }
}
