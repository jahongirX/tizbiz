<?php

namespace api\modules\notify\services;

use Yii;

/**
 * Thin Telegram Bot API client used for the per-business bots.
 *
 * Unlike {@see TelegramSender} (which used a single global token), every call
 * here takes the specific business's bot token, so each tenant's bot sends and
 * receives on its own credentials. Also owns the webhook wiring (setWebhook /
 * deleteWebhook) and the derivation of the per-business webhook URL + secret.
 */
class TelegramBotService
{
    private const API_BASE = 'https://api.telegram.org';

    // --- webhook identity ---------------------------------------------------

    /** Public HTTPS URL Telegram should POST updates to for this business. */
    public static function webhookUrl(int $businessId): string
    {
        return self::apiBase() . '/v1/webhooks/telegram/' . $businessId;
    }

    /**
     * Secret token Telegram echoes back in the X-Telegram-Bot-Api-Secret-Token
     * header, so the webhook can trust the caller. Derived (no storage needed).
     */
    public static function webhookSecret(int $businessId): string
    {
        $key = (string) (Yii::$app->params['jwt.secret'] ?? '');
        return substr(hash_hmac('sha256', 'tg-webhook:' . $businessId, $key), 0, 40);
    }

    /** Absolute API base (promotes a protocol-relative //host to https). */
    public static function apiBase(): string
    {
        $base = (string) (Yii::$app->params['api.base'] ?? '');
        if (str_starts_with($base, '//')) {
            $base = 'https:' . $base;
        }
        return rtrim($base, '/');
    }

    /** Public storefront URL for a business slug (mirrors the SPA helper). */
    public static function publicUrl(string $slug): string
    {
        $base = (string) (Yii::$app->params['public.base'] ?? '');
        if ($base !== '') {
            $url = str_contains($base, '{slug}')
                ? str_replace('{slug}', $slug, $base)
                : rtrim($base, '/') . '/' . $slug;
        } else {
            $root = (string) (Yii::$app->params['root.domain'] ?? 'tizbiz.uz');
            $url = 'https://' . $slug . '.' . $root;
        }
        if (str_starts_with($url, '//')) {
            $url = 'https:' . $url;
        }
        return $url;
    }

    // --- Bot API calls ------------------------------------------------------

    /**
     * Validate a token and read the bot's identity.
     * @return array{ok: bool, username: ?string, error: ?string}
     */
    public static function getMe(string $token): array
    {
        [$ok, $code, $body, $err] = self::call($token, 'getMe', null, 'GET');
        if (!$ok) {
            return ['ok' => false, 'username' => null, 'error' => $err ?: "HTTP $code"];
        }
        $data = json_decode((string) $body, true);
        if (!is_array($data) || empty($data['ok'])) {
            return ['ok' => false, 'username' => null, 'error' => self::describe($data, $code)];
        }
        return ['ok' => true, 'username' => $data['result']['username'] ?? null, 'error' => null];
    }

    /**
     * Register the webhook for this business's bot.
     * @return array{ok: bool, error: ?string}
     */
    public static function setWebhook(string $token, int $businessId): array
    {
        [$ok, $code, $body] = self::call($token, 'setWebhook', [
            'url' => self::webhookUrl($businessId),
            'secret_token' => self::webhookSecret($businessId),
            'allowed_updates' => ['message'],
            'drop_pending_updates' => true,
        ]);
        $data = json_decode((string) $body, true);
        if (!$ok || !is_array($data) || empty($data['ok'])) {
            return ['ok' => false, 'error' => self::describe($data, $code)];
        }
        return ['ok' => true, 'error' => null];
    }

    /** Remove the webhook (used on disconnect). Best-effort. */
    public static function deleteWebhook(string $token): bool
    {
        [$ok, , $body] = self::call($token, 'deleteWebhook', ['drop_pending_updates' => false]);
        $data = json_decode((string) $body, true);
        return $ok && is_array($data) && !empty($data['ok']);
    }

    /** Send a text message, optionally with an inline keyboard. */
    public static function sendMessage(string $token, int $chatId, string $text, ?array $replyMarkup = null): bool
    {
        $params = [
            'chat_id' => $chatId,
            'text' => $text,
            'parse_mode' => 'HTML',
            'disable_web_page_preview' => true,
        ];
        if ($replyMarkup !== null) {
            $params['reply_markup'] = $replyMarkup;
        }
        [$ok, $code, $body] = self::call($token, 'sendMessage', $params);
        $data = json_decode((string) $body, true);
        if (!$ok || !is_array($data) || empty($data['ok'])) {
            Yii::warning('Telegram sendMessage failed: ' . self::describe($data, $code), 'notify');
            return false;
        }
        return true;
    }

    // --- transport ----------------------------------------------------------

    /**
     * @return array{0: bool, 1: int, 2: string|false, 3: string} [ok, httpCode, body, error]
     */
    private static function call(string $token, string $method, ?array $params, string $verb = 'POST'): array
    {
        if ($token === '') {
            return [false, 0, false, 'empty bot token'];
        }
        if (!function_exists('curl_init')) {
            return [false, 0, false, 'php-curl extension not available'];
        }
        $url = self::API_BASE . '/bot' . $token . '/' . $method;
        $ch = curl_init($url);
        $opts = [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 12,
            CURLOPT_CONNECTTIMEOUT => 6,
        ];
        if ($verb === 'POST' && $params !== null) {
            $opts[CURLOPT_POST] = true;
            $opts[CURLOPT_POSTFIELDS] = json_encode($params, JSON_UNESCAPED_UNICODE);
            $opts[CURLOPT_HTTPHEADER] = ['Content-Type: application/json'];
        }
        curl_setopt_array($ch, $opts);
        $response = curl_exec($ch);
        $error = $response === false ? curl_error($ch) : '';
        $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        return [$response !== false, $httpCode, $response, $error];
    }

    /** Human-readable error out of a Telegram error envelope. */
    private static function describe(mixed $data, int $code): string
    {
        if (is_array($data) && isset($data['description'])) {
            return (string) $data['description'];
        }
        return "Telegram HTTP $code";
    }
}
