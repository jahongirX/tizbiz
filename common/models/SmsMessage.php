<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * Outbound SMS log entry (one per recipient). Scoped to a dashboard account
 * (user_id). Status flows pending -> sent | failed.
 *
 * @property int $id
 * @property int $user_id
 * @property int|null $device_id
 * @property string $phone
 * @property string $text
 * @property string $status
 * @property string|null $external_id
 * @property string|null $error
 * @property int|null $sent_at
 * @property int $created_at
 */
class SmsMessage extends ActiveRecord
{
    public const STATUS_PENDING = 'pending';
    public const STATUS_SENT = 'sent';
    public const STATUS_FAILED = 'failed';

    public const STATUSES = [self::STATUS_PENDING, self::STATUS_SENT, self::STATUS_FAILED];

    public static function tableName(): string
    {
        return '{{%sms_messages}}';
    }

    public function behaviors(): array
    {
        return [
            [
                'class' => TimestampBehavior::class,
                'updatedAtAttribute' => false, // no updated_at column
            ],
        ];
    }

    public function rules(): array
    {
        return [
            [['user_id', 'phone', 'text'], 'required'],
            [['user_id', 'device_id', 'sent_at'], 'integer'],
            [['text'], 'string'],
            [['phone'], 'string', 'max' => 32],
            [['external_id'], 'string', 'max' => 190],
            [['error'], 'string', 'max' => 500],
            [['status'], 'in', 'range' => self::STATUSES],
            [['status'], 'default', 'value' => self::STATUS_PENDING],
        ];
    }
}
