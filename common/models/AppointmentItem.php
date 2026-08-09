<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * A line item sold on an appointment: an extra service or a product.
 * name/price are snapshots taken at sale time. Money in tiyin.
 *
 * @property int $id
 * @property int $business_id
 * @property int $appointment_id
 * @property string $kind  service|product
 * @property int $ref_id
 * @property string $name
 * @property int $qty
 * @property int $price_tiyin
 * @property int $created_at
 */
class AppointmentItem extends ActiveRecord
{
    public const KIND_SERVICE = 'service';
    public const KIND_PRODUCT = 'product';

    public static function tableName(): string
    {
        return '{{%appointment_items}}';
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
            [['appointment_id', 'kind', 'ref_id', 'name'], 'required'],
            [['appointment_id', 'ref_id', 'qty', 'price_tiyin'], 'integer'],
            [['kind'], 'in', 'range' => [self::KIND_SERVICE, self::KIND_PRODUCT]],
            [['name'], 'string', 'max' => 160],
            [['qty'], 'default', 'value' => 1],
            [['price_tiyin'], 'default', 'value' => 0],
        ];
    }
}
