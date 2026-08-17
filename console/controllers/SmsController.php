<?php

namespace console\controllers;

use api\modules\notify\services\AndroidSmsSender;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\helpers\Console;

/**
 * Manual SMS testing for the Android SMS Gateway driver.
 *
 * Credentials come from --login/--password (or env ASMS_LOGIN/ASMS_PASSWORD,
 * or params 'sms.android.*'). --server switches Cloud vs Local mode.
 *
 *   # Cloud mode (phone online, app in Cloud server mode):
 *   php yii sms/test +998901234567 "Salom TizBiz" --login=USER --password=PASS
 *
 *   # Local mode (phone + computer on same Wi-Fi, app Local server mode):
 *   php yii sms/test +998901234567 "Salom" --server=http://192.168.0.5:8080 \
 *       --login=USER --password=PASS
 */
class SmsController extends Controller
{
    public ?string $login = null;
    public ?string $password = null;
    public ?string $server = null;
    public ?string $sim = null;
    public ?string $path = null;

    public function options($actionID): array
    {
        return ['login', 'password', 'server', 'sim', 'path'];
    }

    public function optionAliases(): array
    {
        return ['l' => 'login', 'p' => 'password', 's' => 'server'];
    }

    /**
     * Send one test SMS and print the full request/response.
     *
     * @param string $phone recipient in international format (+998...)
     * @param string $text  message body
     */
    public function actionTest(string $phone, string $text = 'TizBiz test SMS ✅'): int
    {
        $override = array_filter([
            'login' => $this->login,
            'password' => $this->password,
            'server' => $this->server,
            'sim' => $this->sim,
            'path' => $this->path,
        ], static fn ($v) => $v !== null);

        $r = AndroidSmsSender::sendVerbose($phone, $text, $override);

        $this->stdout("→ URL     : {$r['url']}\n");
        $this->stdout("→ Request : {$r['request']}\n");
        $this->stdout("← HTTP    : {$r['code']}\n");
        $this->stdout("← Response: {$r['response']}\n");
        if ($r['error'] !== '') {
            $this->stdout("← Error   : {$r['error']}\n", Console::FG_RED);
        }
        if ($r['ok']) {
            $this->stdout("✓ Qabul qilindi (telefon SMS yuboradi)\n", Console::FG_GREEN);
            return ExitCode::OK;
        }
        $this->stdout("✗ Yuborilmadi — yuqoridagi javobni tekshiring\n", Console::FG_RED);
        return ExitCode::UNSPECIFIED_ERROR;
    }
}
