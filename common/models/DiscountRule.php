<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * Tiered discount rule: when a client reaches `threshold` on `metric`, they get
 * `percent` off. threshold is tiyin for sold/paid, a visit count for visits.
 *
 * @property int $id
 * @property int $business_id
 * @property string $metric   sold|paid|visits
 * @property int $threshold
 * @property int $percent
 * @property bool $active
 * @property int $created_at
 * @property int $updated_at
 */
class DiscountRule extends ActiveRecord
{
    public const METRIC_SOLD = 'sold';
    public const METRIC_PAID = 'paid';
    public const METRIC_VISITS = 'visits';

    public static function tableName(): string
    {
        return '{{%discount_rules}}';
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
            [['metric', 'threshold', 'percent'], 'required'],
            [['metric'], 'in', 'range' => [self::METRIC_SOLD, self::METRIC_PAID, self::METRIC_VISITS]],
            [['threshold'], 'integer', 'min' => 0],
            [['percent'], 'integer', 'min' => 0, 'max' => 100],
            [['active'], 'boolean'],
            [['active'], 'default', 'value' => true],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'metric' => 'Mezon',
            'threshold' => 'Chegara',
            'percent' => 'Chegirma (%)',
            'active' => 'Faol',
        ];
    }
}
