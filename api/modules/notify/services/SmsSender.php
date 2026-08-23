<?php

namespace api\modules\notify\services;

use Yii;

/**
 * Sends SMS through a gateway. Configuration comes from the environment, so no
 * key is ever committed:
 *
 *   SMS_PROVIDER   tizbiz | eskiz   (default: eskiz — the previous behaviour)
 *   SMS_ENDPOINT   full URL of the send endpoint; each provider has a default
 *   SMS_TOKEN      API key / bearer token
 *   SMS_FROM       sender name, where the gateway supports one (eskiz)
 *
 * tizbiz: our own gateway at sms.tizbiz.uz — POST {to, text} with an X-Api-Key
 * header, answering {"data": …} or {"errors": [ … ]}.
 * eskiz: POST {mobile_phone, message, from} with a bearer token.
 *
 * Missing configuration logs a warning and returns false, so a shop without SMS
 * set up still books appointments.
 */
class SmsSender
{
    public const PROVIDER_TIZBIZ = 'tizbiz';
    public const PROVIDER_ESKIZ = 'eskiz';

    private const DEFAULT_ENDPOINT = [
        self::PROVIDER_TIZBIZ => 'https://api.tizbiz.uz/v1/sms/api/send',
        self::PROVIDER_ESKIZ => '',
    ];

    public static function provider(): string
    {
        $p = strtolower(trim((string) getenv('SMS_PROVIDER')));
        return $p === self::PROVIDER_TIZBIZ ? self::PROVIDER_TIZBIZ : self::PROVIDER_ESKIZ;
    }

    public static function endpoint(): string
    {
        $endpoint = trim((string) getenv('SMS_ENDPOINT'));
        return $endpoint !== '' ? $endpoint : (self::DEFAULT_ENDPOINT[self::provider()] ?? '');
    }

    /** Send `text` to a phone number in international format. Returns true on success. */
    public static function send(string $phone, string $text): bool
    {
        $provider = self::provider();
        $endpoint = self::endpoint();
        $token = getenv('SMS_TOKEN') ?: '';
        $from = getenv('SMS_FROM') ?: '';

        if ($endpoint === '' || $token === '') {
            Yii::warning('SMS_ENDPOINT / SMS_TOKEN not set; skipping SMS send.', 'notify');
            return false;
        }

        $phone = self::normalizePhone($phone);
        if ($phone === '') {
            Yii::warning('SMS send skipped: empty/invalid phone.', 'notify');
            return false;
        }

        if ($provider === self::PROVIDER_TIZBIZ) {
            // Our gateway takes the number in international form, with the plus.
            $body = json_encode(['to' => '+' . $phone, 'text' => $text], JSON_UNESCAPED_UNICODE);
        } else {
            $body = json_encode(array_filter([
                'mobile_phone' => $phone,
                'message' => $text,
                'from' => $from !== '' ? $from : null,
            ], static fn ($v) => $v !== null), JSON_UNESCAPED_UNICODE);
        }

        [$ok, $httpCode, $response, $error] = self::post($endpoint, $body, $token, $provider);

        if (!$ok) {
            Yii::warning("SMS send failed ($phone): $error", 'notify');
            return false;
        }
        if ($httpCode < 200 || $httpCode >= 300) {
            Yii::warning("SMS send HTTP $httpCode ($phone): $response", 'notify');
            return false;
        }
        return true;
    }

    /** Keep digits only (gateways expect e.g. 998901234567). */
    private static function normalizePhone(string $phone): string
    {
        return preg_replace('/\D+/', '', $phone) ?? '';
    }

    /** Auth header for the configured gateway. */
    private static function authHeader(string $token, string $provider): string
    {
        return $provider === self::PROVIDER_TIZBIZ
            ? 'X-Api-Key: ' . $token
            : 'Authorization: Bearer ' . $token;
    }

    /**
     * GET a gateway endpoint with the configured key — used by the console check
     * so credentials can be verified without sending anyone a message.
     *
     * @return array{0: bool, 1: int, 2: string|false, 3: string} [ok, httpCode, body, error]
     */
    public static function get(string $url): array
    {
        if (!function_exists('curl_init')) {
            return [false, 0, false, 'php-curl extension not available'];
        }
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_HTTPHEADER => [
                'Accept: application/json',
                self::authHeader((string) getenv('SMS_TOKEN'), self::provider()),
            ],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 10,
            CURLOPT_CONNECTTIMEOUT => 5,
        ]);
        $response = curl_exec($ch);
        $error = $response === false ? curl_error($ch) : '';
        $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);

        return [$response !== false, $httpCode, $response, $error];
    }

    /**
     * @return array{0: bool, 1: int, 2: string|false, 3: string} [ok, httpCode, body, error]
     */
    private static function post(string $url, string $jsonBody, string $token, string $provider): array
    {
        if (!function_exists('curl_init')) {
            return [false, 0, false, 'php-curl extension not available'];
        }
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $jsonBody,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'Accept: application/json',
                self::authHeader($token, $provider),
            ],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 10,
            CURLOPT_CONNECTTIMEOUT => 5,
        ]);
        $response = curl_exec($ch);
        $error = $response === false ? curl_error($ch) : '';
        $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);

        return [$response !== false, $httpCode, $response, $error];
    }
}
