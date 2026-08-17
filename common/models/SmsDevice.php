<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * A registered Android phone ("server") that sends SMS via the SMS Gateway app.
 * Belongs to a dashboard account (user_id). `password` is the gateway credential
 * used to send and is never exposed in API responses.
 *
 * @property int $id
 * @property int $user_id
 * @property string $name
 * @property string|null $server
 * @property string|null $login
 * @property string|null $password
 * @property string|null $external_id
 * @property string $status
 * @property bool $is_active
 * @property int|null $last_seen_at
 * @property int $created_at
 * @property int $updated_at
 */
class SmsDevice extends ActiveRecord
{
    public const STATUS_ONLINE = 'online';
    public const STATUS_OFFLINE = 'offline';

    public static function tableName(): string
    {
        return '{{%sms_devices}}';
    }

    public function behaviors(): array
    {
        return [TimestampBehavior::class];
    }

    public function rules(): array
    {
        return [
            [['user_id', 'name'], 'required'],
            [['user_id', 'last_seen_at'], 'integer'],
            [['name'], 'string', 'max' => 120],
            [['server', 'external_id'], 'string', 'max' => 255],
            [['login', 'password'], 'string', 'max' => 255],
            [['status'], 'in', 'range' => [self::STATUS_ONLINE, self::STATUS_OFFLINE]],
            [['status'], 'default', 'value' => self::STATUS_OFFLINE],
            [['is_active'], 'boolean'],
            [['is_active'], 'default', 'value' => true],
        ];
    }

    /** Public shape: never expose the stored gateway password. */
    public function fields(): array
    {
        return [
            'id',
            'name',
            'server',
            'login',
            'status',
            'is_active' => fn () => (bool) $this->is_active,
            'has_password' => fn () => $this->password !== null && $this->password !== '',
            'last_seen_at',
            'created_at',
        ];
    }

    public function getMessages(): ActiveQuery
    {
        return $this->hasMany(SmsMessage::class, ['device_id' => 'id']);
    }
}
