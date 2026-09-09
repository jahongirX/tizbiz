<?php

namespace console\controllers;

use api\modules\notify\services\AndroidSmsSender;
use common\models\SmsDevice;
use common\models\SmsMessage;
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

    /**
     * Reconcile the real delivery state of recently-sent messages — run from cron:
     *   php yii sms/sync-status
     *
     * We optimistically mark a message "sent" the moment the gateway accepts it,
     * but the phone can still fail to hand it to the operator (the red "!" in the
     * Messages app — the carrier throttled/rejected it). This asks the gateway for
     * each such message's true state and flips it to delivered/failed, so the
     * dashboard stops over-reporting success.
     *
     * @param int $hours how far back to reconcile (default 48h)
     * @param int $limit max messages per run
     */
    public function actionSyncStatus(int $hours = 48, int $limit = 1000): int
    {
        $since = time() - $hours * 3600;
        $settleGrace = time() - 60; // give the phone a moment before judging

        $messages = SmsMessage::find()
            ->where(['status' => SmsMessage::STATUS_SENT])
            ->andWhere(['not', ['external_id' => null]])
            ->andWhere(['>=', 'created_at', $since])
            ->andWhere(['<=', 'created_at', $settleGrace])
            ->orderBy(['id' => SORT_ASC])
            ->limit($limit)
            ->all();

        if ($messages === []) {
            $this->stdout("Tekshiriladigan xabar yo'q.\n", Console::FG_GREEN);
            return ExitCode::OK;
        }

        $devices = [];      // id => SmsDevice
        $delivered = 0;
        $failed = 0;
        $pending = 0;
        $skipped = 0;

        foreach ($messages as $msg) {
            $deviceId = (int) $msg->device_id;
            if (!array_key_exists($deviceId, $devices)) {
                $devices[$deviceId] = SmsDevice::findOne($deviceId);
            }
            $device = $devices[$deviceId];
            if ($device === null || ($device->login ?? '') === '' || ($device->password ?? '') === '') {
                $skipped++;
                continue;
            }

            $state = AndroidSmsSender::fetchState([
                'server' => $device->server,
                'login' => $device->login,
                'password' => $device->password,
            ], (string) $msg->external_id);

            if ($state === null) {
                $skipped++;
                continue;
            }

            switch ($state['state']) {
                case 'Failed':
                    $msg->status = SmsMessage::STATUS_FAILED;
                    $msg->error = mb_substr($state['error'] ?: 'Operator qabul qilmadi (throttle/limit)', 0, 500);
                    $msg->save(false, ['status', 'error']);
                    $failed++;
                    break;
                case 'Delivered':
                    $msg->status = SmsMessage::STATUS_DELIVERED;
                    $msg->save(false, ['status']);
                    $delivered++;
                    break;
                default: // Pending / Processed / Sent — not final yet, leave as is
                    $pending++;
            }
        }

        $this->stdout(sprintf(
            "Sinxronlandi: %d tekshirildi — %d yetkazildi, %d xato, %d kutilmoqda, %d o'tkazib yuborildi.\n",
            count($messages),
            $delivered,
            $failed,
            $pending,
            $skipped
        ), Console::FG_GREEN);
        return ExitCode::OK;
    }
}
