<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Loyalty configuration for a business (tenant-scoped). Normally a single active
 * rule per business.
 *
 * earn_rate is expressed in basis points of the paid amount:
 *   cashback_tiyin = amount_tiyin * earn_rate / 10000
 * (e.g. earn_rate = 500 => 5% cashback).
 *
 * @property int $id
 * @property int $business_id
 * @property int $earn_rate  basis points (1/10000)
 * @property array|null $gift_config  JSON: thresholds, birthday bonus, etc.
 * @property bool $active
 * @property int $created_at
 * @property int $updated_at
 *
 * @property-read Business $business
 */
class LoyaltyRule extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%loyalty_rules}}';
    }

    public static function isTenantScoped(): bool
    {
        return true;
    }

    public function behaviors(): array
    {
        return [
            TimestampBehavior::class,
            [
                'class' => \common\behaviors\JsonAttributeBehavior::class,
                'attributes' => ['gift_config'],
            ],
        ];
    }

    public function rules(): array
    {
        return [
            [['earn_rate'], 'integer', 'min' => 0],
            [['earn_rate'], 'default', 'value' => 0],
            [['active'], 'boolean'],
            [['active'], 'default', 'value' => true],
            [['gift_config'], 'safe'],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'earn_rate' => 'Cashback foizi',
            'gift_config' => 'Sovg\'a sozlamalari',
            'active' => 'Faol',
            'created_at' => 'Yaratilgan sana',
            'updated_at' => 'Yangilangan sana',
        ];
    }

    public function getBusiness(): ActiveQuery
    {
        return $this->hasOne(Business::class, ['id' => 'business_id']);
    }
}
