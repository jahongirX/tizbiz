<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * Binds a Telegram chat to a client and/or platform user so reminders and the
 * bot can reach the right person. NOT tenant-scoped (a Telegram identity is
 * global; a client already carries its own business). `verified_at` is set once
 * ownership is confirmed via the /start <token> deep link.
 *
 * @property int $id
 * @property int|null $client_id
 * @property int|null $user_id
 * @property int $tg_chat_id
 * @property int|null $verified_at
 * @property int $created_at
 *
 * @property-read Client|null $client
 * @property-read User|null $user
 */
class TelegramLink extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%telegram_links}}';
    }

    public function behaviors(): array
    {
        return [
            [
                'class' => TimestampBehavior::class,
                // Table has only created_at (no updated_at).
                'updatedAtAttribute' => false,
            ],
        ];
    }

    public function rules(): array
    {
        return [
            [['tg_chat_id'], 'required'],
            [['client_id', 'user_id', 'tg_chat_id', 'verified_at'], 'integer'],
        ];
    }

    public function getClient(): \yii\db\ActiveQuery
    {
        return $this->hasOne(Client::class, ['id' => 'client_id']);
    }

    public function getUser(): \yii\db\ActiveQuery
    {
        return $this->hasOne(User::class, ['id' => 'user_id']);
    }

    // --- /start deep-link token scheme -------------------------------------
    //
    // The bot is opened with `https://t.me/<bot>?start=<token>`. The token is a
    // self-contained, HMAC-signed reference to the entity to link so the webhook
    // can verify ownership without a server-side lookup table:
    //
    //   token = "<kind><id>.<sig>"
    //     kind : 'c' (client) or 'u' (user)
    //     id   : the entity id
    //     sig  : first 16 hex chars of HMAC-SHA256("<kind><id>", jwt.secret)
    //
    // Example: "c42.9f3a1c8b7d6e5f04".

    private static function tokenSecret(): string
    {
        return (string) \Yii::$app->params['jwt.secret'];
    }

    private static function sign(string $body): string
    {
        return substr(hash_hmac('sha256', $body, self::tokenSecret()), 0, 16);
    }

    /** Build a signed /start token for a client or a user. */
    public static function makeStartToken(?int $clientId = null, ?int $userId = null): string
    {
        if ($clientId !== null) {
            $body = 'c' . $clientId;
        } elseif ($userId !== null) {
            $body = 'u' . $userId;
        } else {
            throw new \InvalidArgumentException('makeStartToken requires a client or user id.');
        }
        return $body . '.' . self::sign($body);
    }

    /**
     * Verify a /start token. Returns ['client_id' => int|null, 'user_id' => int|null]
     * on success, or null if malformed or the signature does not match.
     */
    public static function parseStartToken(string $token): ?array
    {
        $token = trim($token);
        if (!preg_match('/^([cu])(\d+)\.([0-9a-f]{16})$/', $token, $m)) {
            return null;
        }
        [$full, $kind, $id, $sig] = $m;
        $body = $kind . $id;
        if (!hash_equals(self::sign($body), $sig)) {
            return null;
        }
        return [
            'client_id' => $kind === 'c' ? (int) $id : null,
            'user_id' => $kind === 'u' ? (int) $id : null,
        ];
    }
}
