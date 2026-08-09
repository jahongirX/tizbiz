<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * A single change to a product's stock (immutable ledger row).
 *
 * @property int $id
 * @property int $business_id
 * @property int $product_id
 * @property int $delta_qty
 * @property string $type
 * @property string|null $reason
 * @property int $created_at
 */
class StockMovement extends ActiveRecord
{
    public const TYPE_IN = 'in';
    public const TYPE_OUT = 'out';
    public const TYPE_WRITEOFF = 'writeoff';
    public const TYPE_ADJUST = 'adjust';
    public const TYPE_SALE = 'sale';

    public static function tableName(): string
    {
        return '{{%stock_movements}}';
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
            [['product_id', 'delta_qty', 'type'], 'required'],
            [['product_id', 'delta_qty'], 'integer'],
            [['type'], 'in', 'range' => [
                self::TYPE_IN, self::TYPE_OUT, self::TYPE_WRITEOFF, self::TYPE_ADJUST, self::TYPE_SALE,
            ]],
            [['reason'], 'string', 'max' => 160],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'product_id' => 'Mahsulot',
            'delta_qty' => 'Miqdor o\'zgarishi',
            'type' => 'Turi',
            'reason' => 'Sabab',
        ];
    }

    public function getProduct(): ActiveQuery
    {
        return $this->hasOne(Product::class, ['id' => 'product_id']);
    }
}
