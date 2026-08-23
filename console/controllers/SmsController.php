<?php

namespace console\controllers;

use api\modules\notify\services\SmsSender;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\helpers\Console;

/**
 * SMS gateway checks. Credentials come from the environment (SMS_PROVIDER,
 * SMS_ENDPOINT, SMS_TOKEN) and are never printed in full.
 *
 *   php yii sms/status                    read-only: provider + monthly balance
 *   php yii sms/send +998901234567 "..."  sends a real message, so it asks first
 */
class SmsController extends Controller
{
    public function actionStatus(): int
    {
        $provider = SmsSender::provider();
        $token = (string) getenv('SMS_TOKEN');
        $endpoint = SmsSender::endpoint();

        $this->stdout("provider: {$provider}\n");
        $this->stdout("endpoint: " . ($endpoint ?: '(not set)') . "\n");
        $this->stdout('token:    ' . ($token === '' ? '(not set)' : $this->mask($token)) . "\n");

        if ($token === '' || $endpoint === '') {
            $this->stderr("Set SMS_PROVIDER, SMS_ENDPOINT and SMS_TOKEN first.\n", Console::FG_YELLOW);
            return ExitCode::CONFIG;
        }

        // Balance sits next to the send endpoint on our gateway.
        $balanceUrl = str_replace('/send', '/balance', $endpoint);
        [$ok, $code, $body, $error] = SmsSender::get($balanceUrl);

        if (!$ok) {
            $this->stderr("balance request failed: {$error}\n", Console::FG_RED);
            return ExitCode::UNAVAILABLE;
        }
        $this->stdout("balance:  HTTP {$code} {$body}\n", $code >= 200 && $code < 300 ? Console::FG_GREEN : Console::FG_RED);

        return $code >= 200 && $code < 300 ? ExitCode::OK : ExitCode::UNAVAILABLE;
    }

    /**
     * @param string $phone recipient in international form
     * @param string $text  message body
     */
    public function actionSend(string $phone, string $text = 'TizBiz test'): int
    {
        if (!$this->confirm("Send a real SMS to {$phone}?")) {
            $this->stdout("Cancelled.\n");
            return ExitCode::OK;
        }
        $ok = SmsSender::send($phone, $text);
        $this->stdout($ok ? "sent\n" : "not sent — see the app log\n", $ok ? Console::FG_GREEN : Console::FG_RED);
        return $ok ? ExitCode::OK : ExitCode::UNAVAILABLE;
    }

    /** Show only the shape of a key, never the key. */
    private function mask(string $token): string
    {
        $len = strlen($token);
        return $len <= 10 ? str_repeat('*', $len) : substr($token, 0, 4) . str_repeat('*', $len - 8) . substr($token, -4);
    }
}
