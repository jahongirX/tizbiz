<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * Outbound message log (reminders, confirmations) for a business.
 *
 * Tenant-scoped: every row belongs to a business. channel is tg/sms; status is
 * queued/sent/failed. `payload` carries template variables (e.g. appointment_id,
 * time, service name) as JSON.
 *
 * @property int $id
 * @property int $business_id
 * @property int|null $client_id
 * @property string $channel
 * @property string $template
 * @property array|null $payload
 * @property string $status
 * @property int|null $sent_at
 * @property int $created_at
 *
 * @property-read Business $business
 * @property-read Client|null $client
 */
class Notification extends ActiveRecord
{
    public const CHANNEL_TELEGRAM = 'tg';
    public const CHANNEL_SMS = 'sms';

    public const STATUS_QUEUED = 'queued';
    public const STATUS_SENT = 'sent';
    public const STATUS_FAILED = 'failed';

    public static function tableName(): string
    {
        return '{{%notifications}}';
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
                // Table has only created_at (no updated_at).
                'updatedAtAttribute' => false,
            ],
            [
                'class' => \common\behaviors\JsonAttributeBehavior::class,
                'attributes' => ['payload'],
            ],
        ];
    }

    public function rules(): array
    {
        return [
            [['business_id', 'channel', 'template'], 'required'],
            [['business_id', 'client_id', 'sent_at'], 'integer'],
            [['channel'], 'in', 'range' => [self::CHANNEL_TELEGRAM, self::CHANNEL_SMS]],
            [['status'], 'in', 'range' => [self::STATUS_QUEUED, self::STATUS_SENT, self::STATUS_FAILED]],
            [['status'], 'default', 'value' => self::STATUS_QUEUED],
            [['channel'], 'string', 'max' => 8],
            [['template'], 'string', 'max' => 48],
            [['payload'], 'safe'],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'client_id' => 'Mijoz',
            'channel' => 'Kanal',
            'template' => 'Shablon',
            'payload' => 'Ma\'lumot',
            'status' => 'Holat',
            'sent_at' => 'Yuborilgan vaqti',
            'created_at' => 'Yaratilgan sana',
        ];
    }

    public function getBusiness(): \yii\db\ActiveQuery
    {
        return $this->hasOne(Business::class, ['id' => 'business_id']);
    }

    public function getClient(): \yii\db\ActiveQuery
    {
        return $this->hasOne(Client::class, ['id' => 'client_id']);
    }
}
