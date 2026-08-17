<?php

namespace api\modules\notify\services;

use Yii;

/**
 * Sends SMS through an Uzbek gateway (Eskiz / Playmobile style). Configuration is
 * read from the environment:
 *
 *   SMS_ENDPOINT   full URL of the send endpoint (e.g. https://notify.eskiz.uz/api/message/sms/send)
 *   SMS_TOKEN      bearer token / api key (Eskiz style)
 *   SMS_FROM       sender / nickname (optional, e.g. "4546")
 *
 * The actual HTTP call is stubbed with curl and posts a JSON body; adapt the
 * field names to the chosen gateway when credentials are provisioned. Missing
 * configuration logs a warning and returns false (no hard failure).
 */
class SmsSender
{
    /** Send `text` to a phone number in international format. Returns true on success. */
    public static function send(string $phone, string $text): bool
    {
        // Driver selector: 'android' routes through the Android SMS Gateway
        // (a phone as modem); anything else uses the Eskiz-style HTTP gateway.
        $driver = getenv('SMS_DRIVER') ?: (string) (Yii::$app->params['sms.driver'] ?? '');
        if ($driver === 'android') {
            return AndroidSmsSender::send($phone, $text);
        }

        $endpoint = getenv('SMS_ENDPOINT') ?: '';
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

        // Gateway-specific payload. Eskiz expects mobile_phone/message/from.
        $body = json_encode(array_filter([
            'mobile_phone' => $phone,
            'message' => $text,
            'from' => $from !== '' ? $from : null,
        ], static fn ($v) => $v !== null), JSON_UNESCAPED_UNICODE);

        [$ok, $httpCode, $response, $error] = self::post($endpoint, $body, $token);

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

    /**
     * @return array{0: bool, 1: int, 2: string|false, 3: string} [ok, httpCode, body, error]
     */
    private static function post(string $url, string $jsonBody, string $token): array
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
                'Authorization: Bearer ' . $token,
            ],
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
