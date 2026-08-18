<?php

namespace api\modules\sms\controllers;

use api\modules\sms\services\SmsDispatcher;

/**
 * POST v1/sms/send  (dashboard, Bearer-auth)
 * { device_id?, phones: ["+998..", ..] | phone: "+998..", text: "..." }
 *
 * Thin wrapper over {@see SmsDispatcher}: the same send pipeline the public
 * API uses, scoped to the logged-in account.
 */
class SendController extends BaseController
{
    public function actionSend(): array
    {
        // Recipients: accept `phones` (array) or a single `phone`.
        $phones = $this->body('phones');
        if (!is_array($phones)) {
            $single = trim((string) $this->body('phone', ''));
            $phones = $single !== '' ? [$single] : [];
        }

        $deviceId = (int) $this->body('device_id', 0) ?: null;
        $result = SmsDispatcher::send($this->uid(), $phones, (string) $this->body('text', ''), $deviceId);

        return [
            'sent' => $result['sent'],
            'failed' => $result['failed'],
            'blocked' => $result['blocked'],
            'quota_blocked' => $result['quota_blocked'],
            'device_id' => $result['device_id'],
            'messages' => $result['messages'],
        ];
    }
}
