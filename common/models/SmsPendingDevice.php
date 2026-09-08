<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * A phone that announced itself (TizBiz SMS app -> POST /v1/sms/devices/announce)
 * with its gateway-issued credentials. Unclaimed rows are offered in the
 * dashboard so an operator attaches the phone by selecting it. `password` is
 * never exposed in API responses.
 *
 * @property int $id
 * @property string $device_id
 * @property string|null $name
 * @property string|null $login
 * @property string|null $password
 * @property string|null $server
 * @property string|null $sim_number
 * @property string $status
 * @property int|null $claimed_by
 * @property int|null $sms_device_id
 * @property int $announced_at
 * @property int|null $claimed_at
 * @property int $created_at
 * @property int $updated_at
 */
class SmsPendingDevice extends ActiveRecord
{
    public const STATUS_AVAILABLE = 'available';
    public const STATUS_CLAIMED = 'claimed';

    public static function tableName(): string
    {
        return '{{%sms_pending_devices}}';
    }

    public function behaviors(): array
    {
        return [TimestampBehavior::class];
    }

    public function rules(): array
    {
        return [
            [['device_id'], 'required'],
            [['device_id'], 'string', 'max' => 190],
            [['name', 'login'], 'string', 'max' => 190],
            [['password', 'server'], 'string', 'max' => 255],
            [['sim_number'], 'string', 'max' => 32],
            [['status'], 'in', 'range' => [self::STATUS_AVAILABLE, self::STATUS_CLAIMED]],
            [['status'], 'default', 'value' => self::STATUS_AVAILABLE],
            [['claimed_by', 'sms_device_id', 'announced_at', 'claimed_at'], 'integer'],
        ];
    }

    /** Public shape: never expose the stored gateway password. */
    public function fields(): array
    {
        return [
            'id',
            'device_id',
            'name',
            'login',
            'sim_number',
            'status',
            'has_password' => fn () => $this->password !== null && $this->password !== '',
            'announced_at',
        ];
    }
}
