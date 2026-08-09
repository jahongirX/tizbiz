<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * Subscription / pass type (Abonement turi). Money in tiyin.
 *
 * @property int $id
 * @property int $business_id
 * @property string $name
 * @property int $visits
 * @property int $price_tiyin
 * @property int $valid_days
 * @property bool $is_active
 * @property int $created_at
 * @property int $updated_at
 */
class SubscriptionType extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%subscription_types}}';
    }

    public static function isTenantScoped(): bool
    {
        return true;
    }

    public function behaviors(): array
    {
        return [TimestampBehavior::class];
    }

    public function rules(): array
    {
        return [
            [['name'], 'required'],
            [['name'], 'string', 'max' => 120],
            [['visits'], 'integer', 'min' => 1],
            [['visits'], 'default', 'value' => 1],
            [['price_tiyin'], 'integer', 'min' => 0],
            [['valid_days'], 'integer', 'min' => 1],
            [['valid_days'], 'default', 'value' => 30],
            [['is_active'], 'boolean'],
            [['is_active'], 'default', 'value' => true],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'name' => 'Nomi',
            'visits' => 'Tashriflar soni',
            'price_tiyin' => 'Narxi',
            'valid_days' => 'Amal muddati (kun)',
            'is_active' => 'Faol',
        ];
    }
}
