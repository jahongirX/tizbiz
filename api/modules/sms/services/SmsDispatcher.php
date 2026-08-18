<?php

namespace api\modules\sms\services;

use api\modules\notify\services\AndroidSmsSender;
use common\models\SmsAccount;
use common\models\SmsBlacklist;
use common\models\SmsDevice;
use common\models\SmsMessage;
use yii\web\BadRequestHttpException;
use yii\web\UnprocessableEntityHttpException;

/**
 * The single send path for one account (user_id), shared by the dashboard
 * "Send" screen and the public REST API. Handles the whole pipeline:
 *   normalize recipients -> drop blacklisted -> enforce account status/quota
 *   -> resolve a device -> send + log one {@see SmsMessage} per recipient.
 *
 * Keeping this in one place means the API and the UI can never drift on the
 * rules (a blocked account, an exhausted quota, a blacklisted number behave
 * identically no matter how the send was triggered).
 */
class SmsDispatcher
{
    /**
     * @param int      $userId    the SMS account (owner of devices/quota/blacklist)
     * @param string[] $phones    raw recipient numbers (deduped/cleaned here)
     * @param string   $text      message body
     * @param int|null $deviceId  explicit device, or null for the first active one
     *
     * @return array{sent:int,failed:int,blocked:int,quota_blocked:int,device_id:int|null,messages:SmsMessage[]}
     *
     * @throws BadRequestHttpException          empty text / no recipients
     * @throws UnprocessableEntityHttpException blocked account, exhausted quota, no usable device
     */
    public static function send(int $userId, array $phones, string $text, ?int $deviceId = null): array
    {
        $text = trim($text);
        if ($text === '') {
            throw new BadRequestHttpException('Xabar matni bo\'sh.');
        }

        $phones = array_values(array_unique(array_filter(array_map(
            static fn ($p) => trim((string) $p),
            $phones
        ), static fn ($p) => $p !== '')));
        if ($phones === []) {
            throw new BadRequestHttpException('Raqam kiritilmagan.');
        }

        // 1) Drop blacklisted recipients before doing any work.
        $blocked = 0;
        $blocklist = SmsBlacklist::digitSetFor($userId);
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
            return ['sent' => 0, 'failed' => 0, 'blocked' => $blocked, 'quota_blocked' => 0, 'device_id' => null, 'messages' => []];
        }

        // 2) Account status + monthly quota. No account = unrestricted (local/demo).
        $quotaBlocked = 0;
        $account = SmsAccount::forUser($userId);
        if ($account !== null) {
            if (!$account->is_active) {
                throw new UnprocessableEntityHttpException('SMS akkaunt bloklangan.');
            }
            $remaining = $account->remaining(); // null = unlimited
            if ($remaining !== null) {
                if ($remaining <= 0) {
                    throw new UnprocessableEntityHttpException('Oylik SMS limiti tugagan.');
                }
                if (count($phones) > $remaining) {
                    $quotaBlocked = count($phones) - $remaining;
                    $phones = array_slice($phones, 0, $remaining);
                }
            }
        }

        // 3) Resolve the sending device and dispatch one message at a time.
        $device = self::resolveDevice($userId, $deviceId);
        $override = [
            'server' => $device->server,
            'login' => $device->login,
            'password' => $device->password,
        ];

        $messages = [];
        $sent = 0;
        $failed = 0;
        foreach ($phones as $phone) {
            $msg = new SmsMessage([
                'user_id' => $userId,
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
            $messages[] = $msg;
        }

        return [
            'sent' => $sent,
            'failed' => $failed,
            'blocked' => $blocked,
            'quota_blocked' => $quotaBlocked,
            'device_id' => (int) $device->id,
            'messages' => $messages,
        ];
    }

    /** Resolve the device to send through: explicit id, else the first active one. */
    private static function resolveDevice(int $userId, ?int $deviceId): SmsDevice
    {
        if ($deviceId !== null && $deviceId > 0) {
            $device = SmsDevice::findOne(['id' => $deviceId, 'user_id' => $userId]);
        } else {
            $device = SmsDevice::find()
                ->where(['user_id' => $userId, 'is_active' => true])
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
