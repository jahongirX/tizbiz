<?php

namespace api\modules\sms\controllers;

use api\modules\notify\services\AndroidSmsSender;
use common\models\SmsBlacklist;
use common\models\SmsDevice;
use common\models\SmsMessage;
use Yii;
use yii\web\BadRequestHttpException;
use yii\web\UnprocessableEntityHttpException;

/**
 * POST v1/sms/send
 * { device_id?, phones: ["+998..", ..] | phone: "+998..", text: "..." }
 *
 * Dispatches through the given device (or the account's first active device),
 * logs one SmsMessage per recipient, and updates each with the gateway result.
 */
class SendController extends BaseController
{
    public function actionSend()
    {
        $text = trim((string) $this->body('text', ''));
        if ($text === '') {
            throw new BadRequestHttpException('Xabar matni bo\'sh.');
        }

        // Recipients: accept `phones` (array) or a single `phone`.
        $phones = $this->body('phones');
        if (!is_array($phones)) {
            $single = trim((string) $this->body('phone', ''));
            $phones = $single !== '' ? [$single] : [];
        }
        $phones = array_values(array_unique(array_filter(array_map(
            static fn ($p) => trim((string) $p),
            $phones
        ), static fn ($p) => $p !== '')));
        if ($phones === []) {
            throw new BadRequestHttpException('Raqam kiritilmagan.');
        }

        // Drop blacklisted recipients before doing any work.
        $blocklist = SmsBlacklist::digitSetFor($this->uid());
        $blocked = 0;
        if ($blocklist !== []) {
            $allowed = [];
            foreach ($phones as $phone) {
                if (isset($blocklist[SmsBlacklist::digits($phone)])) {
                    $blocked++;
                    continue;
                }
                $allowed[] = $phone;
            }
            $phones = $allowed;
        }
        if ($phones === []) {
            return ['sent' => 0, 'failed' => 0, 'blocked' => $blocked, 'messages' => []];
        }

        $device = $this->resolveDevice();
        $override = [
            'server' => $device->server,
            'login' => $device->login,
            'password' => $device->password,
        ];

        $results = [];
        $sent = 0;
        $failed = 0;
        foreach ($phones as $phone) {
            $msg = new SmsMessage([
                'user_id' => $this->uid(),
                'device_id' => (int) $device->id,
                'phone' => $phone,
                'text' => $text,
                'status' => SmsMessage::STATUS_PENDING,
            ]);
            $msg->save(false);

            $r = AndroidSmsSender::sendVerbose($phone, $text, $override);
            if ($r['ok']) {
                $msg->status = SmsMessage::STATUS_SENT;
                $msg->sent_at = time();
                $msg->external_id = self::extractId($r['response']);
                $sent++;
            } else {
                $msg->status = SmsMessage::STATUS_FAILED;
                $msg->error = mb_substr(($r['error'] ?: $r['response']) ?: ('HTTP ' . $r['code']), 0, 500);
                $failed++;
            }
            $msg->save(false);
            $results[] = $msg;
        }

        return ['sent' => $sent, 'failed' => $failed, 'blocked' => $blocked, 'device_id' => (int) $device->id, 'messages' => $results];
    }

    /** Resolve the device to send through: explicit device_id, else first active. */
    private function resolveDevice(): SmsDevice
    {
        $id = (int) $this->body('device_id', 0);
        if ($id > 0) {
            $device = SmsDevice::findOne(['id' => $id, 'user_id' => $this->uid()]);
        } else {
            $device = SmsDevice::find()
                ->where(['user_id' => $this->uid(), 'is_active' => true])
                ->orderBy(['id' => SORT_ASC])
                ->one();
        }
        if ($device === null) {
            throw new UnprocessableEntityHttpException('Faol server (telefon) topilmadi. Avval server qo\'shing.');
        }
        if (($device->login ?? '') === '' || ($device->password ?? '') === '') {
            throw new UnprocessableEntityHttpException('Serverda login/parol sozlanmagan.');
        }
        return $device;
    }

    /** Pull the message id from the gateway JSON response, if present. */
    private static function extractId(string $response): ?string
    {
        $data = json_decode($response, true);
        return is_array($data) && isset($data['id']) ? (string) $data['id'] : null;
    }
}
