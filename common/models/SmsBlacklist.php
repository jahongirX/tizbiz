<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * A number that must never receive messages from a dashboard account (user_id).
 * The send pipeline drops any recipient whose digits match a blacklist entry.
 *
 * @property int $id
 * @property int $user_id
 * @property string $phone
 * @property string|null $reason
 * @property int $created_at
 */
class SmsBlacklist extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%sms_blacklist}}';
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
            [['user_id', 'phone'], 'required'],
            [['user_id'], 'integer'],
            [['phone'], 'string', 'max' => 32],
            [['reason'], 'string', 'max' => 255],
            [['phone'], 'unique', 'targetAttribute' => ['user_id', 'phone'], 'message' => 'Bu raqam allaqachon qora ro\'yxatda.'],
        ];
    }

    public function fields(): array
    {
        return ['id', 'phone', 'reason', 'created_at'];
    }

    /** Digits-only form of a phone, for tolerant matching against recipients. */
    public static function digits(string $phone): string
    {
        return preg_replace('/\D+/', '', $phone) ?? '';
    }

    /** Digit-set of all blacklisted numbers for an account. */
    public static function digitSetFor(int $userId): array
    {
        $set = [];
        foreach (self::find()->select('phone')->where(['user_id' => $userId])->column() as $p) {
            $d = self::digits((string) $p);
            if ($d !== '') {
                $set[$d] = true;
            }
        }
        return $set;
    }
}
