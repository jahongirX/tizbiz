<?php

namespace common\helpers;

/**
 * Verification of Telegram Mini App (Web App) `initData`.
 *
 * When the catalog SPA runs inside Telegram, the client hands us a signed
 * `initData` query string. We verify it against the business's bot token, which
 * proves the request really comes from that Telegram user — no separate login.
 *
 * Algorithm (per core.telegram.org/bots/webapps#validating-data):
 *   secret_key    = HMAC_SHA256(key="WebAppData", data=bot_token)
 *   data_check    = "<k>=<v>\n..." for every field except `hash`, keys sorted
 *   expected_hash = HMAC_SHA256(key=secret_key, data=data_check)  (hex)
 * Valid iff expected_hash === provided hash (constant-time).
 */
class TelegramWebApp
{
    /** Max age of initData we accept, in seconds (replay protection). */
    private const MAX_AGE = 86400; // 24h

    /**
     * Verify initData and return the decoded payload, or null if invalid/expired.
     *
     * @return array{user: array, auth_date: int, query_id: ?string}|null
     */
    public static function verify(string $initData, string $botToken, int $maxAge = self::MAX_AGE): ?array
    {
        if ($initData === '' || $botToken === '') {
            return null;
        }

        // Parse the query string preserving raw (decoded) values per key.
        $pairs = [];
        foreach (explode('&', $initData) as $chunk) {
            if ($chunk === '') {
                continue;
            }
            $eq = strpos($chunk, '=');
            if ($eq === false) {
                continue;
            }
            $key = urldecode(substr($chunk, 0, $eq));
            $val = urldecode(substr($chunk, $eq + 1));
            $pairs[$key] = $val;
        }

        $hash = $pairs['hash'] ?? '';
        if ($hash === '') {
            return null;
        }
        unset($pairs['hash']);
        ksort($pairs);

        $lines = [];
        foreach ($pairs as $k => $v) {
            $lines[] = $k . '=' . $v;
        }
        $dataCheck = implode("\n", $lines);

        $secretKey = hash_hmac('sha256', $botToken, 'WebAppData', true);
        $expected = hash_hmac('sha256', $dataCheck, $secretKey);
        if (!hash_equals($expected, $hash)) {
            return null;
        }

        $authDate = (int) ($pairs['auth_date'] ?? 0);
        if ($maxAge > 0 && ($authDate <= 0 || (time() - $authDate) > $maxAge)) {
            return null;
        }

        $user = [];
        if (isset($pairs['user'])) {
            $decoded = json_decode($pairs['user'], true);
            if (is_array($decoded)) {
                $user = $decoded;
            }
        }
        if (!isset($user['id'])) {
            return null;
        }

        return [
            'user' => $user,
            'auth_date' => $authDate,
            'query_id' => $pairs['query_id'] ?? null,
        ];
    }
}
