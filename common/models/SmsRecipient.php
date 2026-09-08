<?php

namespace common\models;

use common\db\ActiveRecord;
use Throwable;
use yii\db\Expression;

/**
 * Every phone number the platform's SMS accounts send to, collected centrally
 * (deduped by normalized digits). Populated by the send dispatcher.
 *
 * @property int $id
 * @property string $phone         normalized digits
 * @property int $send_count
 * @property int|null $last_user_id
 * @property int $first_seen_at
 * @property int $last_seen_at
 */
class SmsRecipient extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%sms_recipients}}';
    }

    /** Record one outbound recipient. Never throws (best-effort collection). */
    public static function record(int $userId, string $rawPhone): void
    {
        $digits = preg_replace('/\D+/', '', $rawPhone);
        if ($digits === null || strlen($digits) < 7) {
            return;
        }
        $now = time();
        try {
            static::getDb()->createCommand()->upsert(
                static::tableName(),
                [
                    'phone' => $digits,
                    'send_count' => 1,
                    'last_user_id' => $userId,
                    'first_seen_at' => $now,
                    'last_seen_at' => $now,
                ],
                [
                    'send_count' => new Expression('[[send_count]] + 1'),
                    'last_user_id' => $userId,
                    'last_seen_at' => $now,
                ],
            )->execute();
        } catch (Throwable $e) {
            // best-effort; never break sending
        }
    }
}
