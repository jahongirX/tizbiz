<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * A single line of an {@see Order}. name + price are snapshotted at order time
 * so history is stable if the menu changes later. Tenant scoped by business_id.
 *
 * @property int $id
 * @property int $order_id
 * @property int $business_id
 * @property int|null $service_id
 * @property string $name
 * @property int $price_tiyin
 * @property int $qty
 * @property int $created_at
 */
class OrderItem extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%order_items}}';
    }

    public static function isTenantScoped(): bool
    {
        return true;
    }

    public function behaviors(): array
    {
        return [
            ['class' => TimestampBehavior::class, 'updatedAtAttribute' => false],
        ];
    }

    public function rules(): array
    {
        return [
            [['name'], 'required'],
            [['name'], 'string', 'max' => 160],
            [['order_id', 'service_id', 'price_tiyin', 'qty'], 'integer'],
            [['qty'], 'default', 'value' => 1],
        ];
    }

    public function fields(): array
    {
        return ['id', 'service_id', 'name', 'price_tiyin', 'qty'];
    }
}
