<?php

namespace common\models;

use yii\behaviors\TimestampBehavior;
use yii\db\ActiveRecord;

/**
 * One-time login code for a consumer phone. Only an HMAC of "phone|code" is
 * stored. Rows are also the rate-limit log (per phone / per IP). Not tenant-scoped.
 *
 * @property int $id
 * @property string $phone
 * @property string $code_hash
 * @property int $attempts
 * @property int $expires_at
 * @property int|null $consumed_at
 * @property string|null $ip
 * @property int $created_at
 */
class ConsumerOtpCode extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%consumer_otp_codes}}';
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
            [['phone', 'code_hash', 'expires_at'], 'required'],
            [['phone'], 'string', 'max' => 32],
            [['code_hash'], 'string', 'length' => 64],
            [['attempts', 'expires_at', 'consumed_at'], 'integer'],
            [['attempts'], 'default', 'value' => 0],
            [['ip'], 'string', 'max' => 45],
        ];
    }
}
