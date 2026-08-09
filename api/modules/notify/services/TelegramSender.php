<?php

namespace api\modules\notify\services;

use Yii;

/**
 * Sends messages through the Telegram Bot API (sendMessage) using php-curl.
 *
 * The bot token comes from the TELEGRAM_BOT_TOKEN environment variable. If it is
 * missing we log a warning and return false rather than throwing, so a queued
 * notification is simply marked failed instead of breaking the whole batch.
 */
class TelegramSender
{
    private const API_BASE = 'https://api.telegram.org';

    /** Send `text` to the given Telegram chat id. Returns true on success. */
    public static function send(int $chatId, string $text): bool
    {
        $token = getenv('TELEGRAM_BOT_TOKEN') ?: '';
        if ($token === '') {
            Yii::warning('TELEGRAM_BOT_TOKEN is not set; skipping Telegram send.', 'notify');
            return false;
        }

        $url = self::API_BASE . '/bot' . $token . '/sendMessage';
        $body = json_encode([
            'chat_id' => $chatId,
            'text' => $text,
            'disable_web_page_preview' => true,
        ], JSON_UNESCAPED_UNICODE);

        [$ok, $httpCode, $response, $error] = self::post($url, $body);

        if (!$ok) {
            Yii::warning("Telegram send failed (chat $chatId): $error", 'notify');
            return false;
        }
        if ($httpCode < 200 || $httpCode >= 300) {
            Yii::warning("Telegram send HTTP $httpCode (chat $chatId): $response", 'notify');
            return false;
        }
        $decoded = json_decode((string) $response, true);
        return is_array($decoded) && !empty($decoded['ok']);
    }

    /**
     * @return array{0: bool, 1: int, 2: string|false, 3: string} [ok, httpCode, body, error]
     */
    private static function post(string $url, string $jsonBody): array
    {
        if (!function_exists('curl_init')) {
            return [false, 0, false, 'php-curl extension not available'];
        }
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $jsonBody,
            CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 10,
            CURLOPT_CONNECTTIMEOUT => 5,
        ]);
        $response = curl_exec($ch);
        $error = $response === false ? curl_error($ch) : '';
        $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        return [$response !== false, $httpCode, $response, $error];
    }
}
