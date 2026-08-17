<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * A catalog order — a cart of menu items placed from the public site or the
 * Telegram bot. Tenant scoped by business_id.
 *
 * @property int $id
 * @property int $business_id
 * @property int|null $client_id
 * @property string|null $customer_name
 * @property string|null $customer_phone
 * @property string $status
 * @property int $total_tiyin
 * @property string|null $note
 * @property string $source
 * @property int $created_at
 * @property int $updated_at
 * @property-read OrderItem[] $items
 */
class Order extends ActiveRecord
{
    public const STATUS_NEW = 'new';
    public const STATUS_CONFIRMED = 'confirmed';
    public const STATUS_PREPARING = 'preparing';
    public const STATUS_READY = 'ready';
    public const STATUS_DELIVERED = 'delivered';
    public const STATUS_CANCELLED = 'cancelled';
    public const STATUSES = [
        self::STATUS_NEW, self::STATUS_CONFIRMED, self::STATUS_PREPARING,
        self::STATUS_READY, self::STATUS_DELIVERED, self::STATUS_CANCELLED,
    ];
    public const SOURCES = ['site', 'bot', 'admin'];

    public static function tableName(): string
    {
        return '{{%orders}}';
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
            [['customer_name'], 'string', 'max' => 128],
            [['customer_phone'], 'string', 'max' => 32],
            [['status'], 'in', 'range' => self::STATUSES],
            [['status'], 'default', 'value' => self::STATUS_NEW],
            [['total_tiyin'], 'integer', 'min' => 0],
            [['note'], 'string', 'max' => 500],
            [['source'], 'in', 'range' => self::SOURCES],
            [['source'], 'default', 'value' => 'site'],
            [['client_id', 'tg_user_id'], 'integer'],
        ];
    }

    public function getItems(): ActiveQuery
    {
        return $this->hasMany(OrderItem::class, ['order_id' => 'id']);
    }

    public function getClient(): ActiveQuery
    {
        return $this->hasOne(Client::class, ['id' => 'client_id']);
    }

    public function fields(): array
    {
        return [
            'id',
            'status',
            'total_tiyin',
            'customer_name',
            'customer_phone',
            'note',
            'source',
            'created_at',
            'items' => fn () => $this->items,
            'items_count' => fn () => (int) count($this->items),
        ];
    }
}
