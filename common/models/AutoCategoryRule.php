<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Auto-assign clients to a category by threshold: when a client meets `threshold`
 * on `metric`, `action` (add/remove) the client to/from `category_id`.
 * threshold is tiyin for sold/paid, a count for visits, and days for inactive_days.
 *
 * @property int $id
 * @property int $business_id
 * @property int $category_id
 * @property string $metric   sold|paid|visits|inactive_days
 * @property int $threshold
 * @property string $action   add|remove
 * @property bool $active
 * @property int $created_at
 * @property int $updated_at
 */
class AutoCategoryRule extends ActiveRecord
{
    public const METRIC_SOLD = 'sold';
    public const METRIC_PAID = 'paid';
    public const METRIC_VISITS = 'visits';
    public const METRIC_INACTIVE = 'inactive_days';

    public const ACTION_ADD = 'add';
    public const ACTION_REMOVE = 'remove';

    public static function tableName(): string
    {
        return '{{%auto_category_rules}}';
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
            [['category_id', 'metric', 'threshold'], 'required'],
            [['category_id', 'threshold'], 'integer'],
            [['metric'], 'in', 'range' => [self::METRIC_SOLD, self::METRIC_PAID, self::METRIC_VISITS, self::METRIC_INACTIVE]],
            [['action'], 'in', 'range' => [self::ACTION_ADD, self::ACTION_REMOVE]],
            [['action'], 'default', 'value' => self::ACTION_ADD],
            [['active'], 'boolean'],
            [['active'], 'default', 'value' => true],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'category_id' => 'Kategoriya',
            'metric' => 'Mezon',
            'threshold' => 'Chegara',
            'action' => 'Amal',
            'active' => 'Faol',
        ];
    }

    public function getCategory(): ActiveQuery
    {
        return $this->hasOne(ClientCategory::class, ['id' => 'category_id']);
    }
}
