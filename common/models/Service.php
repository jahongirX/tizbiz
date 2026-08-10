<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Bookable service. Money stored in tiyin (1/100 so'm). Tenant-scoped.
 *
 * @property int $id
 * @property int $business_id
 * @property int|null $category_id
 * @property string $name
 * @property int $duration_min
 * @property int $price_tiyin
 * @property int|null $deposit_tiyin
 * @property bool $is_active
 * @property int $created_at
 * @property int $updated_at
 */
class Service extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%services}}';
    }

    public static function isTenantScoped(): bool
    {
        return true;
    }

    public function behaviors(): array
    {
        return [
            TimestampBehavior::class,
            // gallery is a JSON column (array of image URLs).
            [
                'class' => \common\behaviors\JsonAttributeBehavior::class,
                'attributes' => ['gallery'],
            ],
        ];
    }

    public function rules(): array
    {
        return [
            [['name'], 'required'],
            [['name'], 'string', 'max' => 128],
            [['business_id', 'category_id', 'duration_min', 'price_tiyin', 'deposit_tiyin'], 'integer'],
            [['duration_min'], 'integer', 'min' => 1],
            [['duration_min'], 'default', 'value' => 30],
            [['price_tiyin'], 'default', 'value' => 0],
            [['price_tiyin', 'deposit_tiyin'], 'integer', 'min' => 0],
            [['is_active'], 'boolean'],
            [['is_active'], 'default', 'value' => true],
            [['online_bookable'], 'boolean'],
            [['online_bookable'], 'default', 'value' => true],
            [['image'], 'string', 'max' => 500],
            [['description'], 'string'],
            [['gallery'], 'safe'],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'name' => 'Nomi',
            'category_id' => 'Kategoriya',
            'duration_min' => 'Davomiyligi (daq)',
            'price_tiyin' => 'Narxi',
            'deposit_tiyin' => 'Oldindan to\'lov',
            'is_active' => 'Faol',
            'online_bookable' => 'Onlayn bron',
            'created_at' => 'Yaratilgan sana',
            'updated_at' => 'Yangilangan sana',
        ];
    }

    public function getCategory(): ActiveQuery
    {
        return $this->hasOne(ServiceCategory::class, ['id' => 'category_id']);
    }
}
