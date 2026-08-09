<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Inventory product. Money in tiyin; stock_qty is an integer count.
 *
 * @property int $id
 * @property int $business_id
 * @property string $name
 * @property string $unit
 * @property int $price_tiyin
 * @property int $cost_tiyin
 * @property int $stock_qty
 * @property int $low_stock
 * @property bool $is_active
 * @property int $created_at
 * @property int $updated_at
 */
class Product extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%products}}';
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
            [['name'], 'string', 'max' => 160],
            [['unit'], 'string', 'max' => 24],
            [['unit'], 'default', 'value' => 'dona'],
            [['price_tiyin', 'cost_tiyin', 'stock_qty', 'low_stock'], 'integer'],
            [['price_tiyin', 'cost_tiyin', 'stock_qty', 'low_stock'], 'default', 'value' => 0],
            [['is_active'], 'boolean'],
            [['is_active'], 'default', 'value' => true],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'name' => 'Nomi',
            'unit' => 'Birlik',
            'price_tiyin' => 'Sotish narxi',
            'cost_tiyin' => 'Tannarx',
            'stock_qty' => 'Zaxira',
            'low_stock' => 'Kam qolgan chegara',
            'is_active' => 'Faol',
        ];
    }

    public function getMovements(): ActiveQuery
    {
        return $this->hasMany(StockMovement::class, ['product_id' => 'id']);
    }
}
