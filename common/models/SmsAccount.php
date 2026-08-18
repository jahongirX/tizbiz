<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * An SMS-service client account: links a platform {@see User} to a monthly SMS
 * quota and an active/blocked flag. Created and managed by a superadmin; the
 * user logs into the SMS dashboard (sms.tizbiz.uz) and sees only their own data
 * (everything there is scoped by user_id).
 *
 * @property int $id
 * @property int $user_id
 * @property int $quota_monthly   0 = unlimited
 * @property bool $is_active
 * @property string|null $note
 * @property int $created_at
 * @property int $updated_at
 *
 * @property-read User|null $user
 */
class SmsAccount extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%sms_accounts}}';
    }

    public function behaviors(): array
    {
        return [TimestampBehavior::class];
    }

    public function rules(): array
    {
        return [
            [['user_id'], 'required'],
            [['user_id', 'quota_monthly'], 'integer'],
            [['quota_monthly'], 'integer', 'min' => 0],
            [['quota_monthly'], 'default', 'value' => 0],
            [['is_active'], 'boolean'],
            [['is_active'], 'default', 'value' => true],
            [['note'], 'string', 'max' => 255],
        ];
    }

    public function getUser(): ActiveQuery
    {
        return $this->hasOne(User::class, ['id' => 'user_id']);
    }

    /** Messages this account has sent in the current calendar month. */
    public function usageThisMonth(): int
    {
        return (int) SmsMessage::find()
            ->where(['user_id' => $this->user_id])
            ->andWhere(['>=', 'created_at', strtotime('first day of this month midnight')])
            ->count();
    }

    /** Remaining quota this month, or null when unlimited. */
    public function remaining(): ?int
    {
        if ((int) $this->quota_monthly <= 0) {
            return null; // unlimited
        }
        return max(0, (int) $this->quota_monthly - $this->usageThisMonth());
    }

    /** The active account for a user (used to gate the dashboard / sending). */
    public static function forUser(int $userId): ?self
    {
        return self::findOne(['user_id' => $userId]);
    }
}
