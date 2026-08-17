<?php

namespace api\modules\notify\services;

use Yii;

/**
 * Sends SMS through the Android SMS Gateway (sms-gate.app) 3rd-party API — an
 * Android phone running the "SMS Gateway" app acts as the modem and sends from
 * its own SIM. Raw curl (no SDK), HTTP Basic auth, so it needs no extra
 * Composer packages and runs on shared hosting as-is.
 *
 * Config (env vars, or Yii params 'sms.android.*'):
 *   ASMS_SERVER    base URL. Cloud (default): https://api.sms-gate.app/3rdparty/v1
 *                  Local mode: the URL the app shows, e.g. http://192.168.0.5:8080
 *   ASMS_LOGIN     username  (from the app -> Cloud/Local server credentials)
 *   ASMS_PASSWORD  password
 *   ASMS_SIM       optional SIM slot (1 or 2)
 *   ASMS_PATH      optional send path (default /message)
 *
 * Modes:
 *   - Cloud: messages relay through api.sms-gate.app to your online phone.
 *   - Local/Private: post directly to the phone's local server (same network).
 */
class AndroidSmsSender
{
    public const CLOUD = 'https://api.sms-gate.app/3rdparty/v1';

    /** Send `text` to a phone. Returns true on success. */
    public static function send(string $phone, string $text, array $override = []): bool
    {
        return self::sendVerbose($phone, $text, $override)['ok'];
    }

    /**
     * Like send() but returns the full outcome for diagnostics / the test CLI.
     *
     * @return array{ok:bool,code:int,response:string,error:string,request:string,url:string}
     */
    public static function sendVerbose(string $phone, string $text, array $override = []): array
    {
        $server = rtrim((string) self::cfg($override, 'server', 'ASMS_SERVER', 'sms.android.server', self::CLOUD), '/');
        $login = (string) self::cfg($override, 'login', 'ASMS_LOGIN', 'sms.android.login', '');
        $pass = (string) self::cfg($override, 'password', 'ASMS_PASSWORD', 'sms.android.password', '');
        $sim = self::cfg($override, 'sim', 'ASMS_SIM', 'sms.android.sim', null);
        $path = (string) self::cfg($override, 'path', 'ASMS_PATH', 'sms.android.path', '/message');

        $phone = self::normalizePhone($phone);
        $url = $server . '/' . ltrim($path, '/');

        if ($login === '' || $pass === '') {
            Yii::warning('ASMS_LOGIN / ASMS_PASSWORD not set; skipping Android SMS.', 'notify');
            return ['ok' => false, 'code' => 0, 'response' => '', 'error' => 'no credentials', 'request' => '', 'url' => $url];
        }
        if ($phone === '') {
            return ['ok' => false, 'code' => 0, 'response' => '', 'error' => 'invalid phone', 'request' => '', 'url' => $url];
        }

        $body = json_encode(array_filter([
            'message' => $text,
            'phoneNumbers' => [$phone],
            'simNumber' => ($sim !== null && $sim !== '') ? (int) $sim : null,
        ], static fn ($v) => $v !== null), JSON_UNESCAPED_UNICODE);

        [$ok, $code, $resp, $err] = self::post($url, $body, $login, $pass);
        $success = $ok && $code >= 200 && $code < 300;
        if (!$success) {
            Yii::warning("Android SMS failed ($phone) HTTP $code: " . ($err ?: $resp), 'notify');
        }
        return ['ok' => $success, 'code' => $code, 'response' => (string) $resp, 'error' => $err, 'request' => $body, 'url' => $url];
    }

    /** override[key] -> env(ENV) -> params[param] -> default. */
    private static function cfg(array $override, string $key, string $env, string $param, $default)
    {
        if (array_key_exists($key, $override) && $override[$key] !== null && $override[$key] !== '') {
            return $override[$key];
        }
        $e = getenv($env);
        if ($e !== false && $e !== '') {
            return $e;
        }
        return Yii::$app->params[$param] ?? $default;
    }

    /** Android gateway expects E.164 with '+', e.g. +998901234567. */
    private static function normalizePhone(string $phone): string
    {
        $digits = preg_replace('/\D+/', '', $phone) ?? '';
        return $digits === '' ? '' : '+' . $digits;
    }

    /** @return array{0:bool,1:int,2:string|false,3:string} [ok, httpCode, body, error] */
    private static function post(string $url, string $body, string $login, string $pass): array
    {
        if (!function_exists('curl_init')) {
            return [false, 0, false, 'php-curl extension not available'];
        }
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $body,
            CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'Accept: application/json'],
            CURLOPT_USERPWD => $login . ':' . $pass,
            CURLOPT_HTTPAUTH => CURLAUTH_BASIC,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 15,
            CURLOPT_CONNECTTIMEOUT => 8,
        ]);
        $response = curl_exec($ch);
        $error = $response === false ? curl_error($ch) : '';
        $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        return [$response !== false, $httpCode, $response, $error];
    }
}
