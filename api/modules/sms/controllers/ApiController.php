<?php

namespace api\modules\sms\controllers;

use api\modules\sms\services\SmsDispatcher;
use common\models\SmsAccount;
use common\models\SmsDevice;
use common\models\SmsMessage;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * Public SMS API for third-party integrations (API-key auth via
 * {@see ApiBaseController}). Endpoints:
 *
 *   POST v1/sms/api/send             send to one or many recipients
 *   GET  v1/sms/api/balance          remaining monthly quota / usage
 *   GET  v1/sms/api/messages         outbound log (filter by status/phone)
 *   GET  v1/sms/api/messages/<id>    status of a single message
 *   GET  v1/sms/api/devices          the account's sending devices
 */
class ApiController extends ApiBaseController
{
    /**
     * POST v1/sms/api/send
     * Body: { to: "+998.."|["+998..",..], text: "...", device_id? }
     * Aliases accepted: `phone`/`phones`/`number`/`numbers` for recipients,
     * `message` for text — friendlier for existing integrations.
     */
    public function actionSend(): array
    {
        $to = $this->body('to');
        foreach (['phones', 'numbers', 'phone', 'number'] as $alias) {
            if ($to === null && ($v = $this->body($alias)) !== null) {
                $to = $v;
            }
        }
        $phones = is_array($to) ? $to : ($to === null ? [] : [$to]);

        $text = (string) ($this->body('text') ?? $this->body('message', ''));
        $deviceId = (int) $this->body('device_id', 0) ?: null;

        $r = SmsDispatcher::send($this->uid(), $phones, $text, $deviceId);

        return [
            'sent' => $r['sent'],
            'failed' => $r['failed'],
            'blocked' => $r['blocked'],
            'quota_blocked' => $r['quota_blocked'],
            'device_id' => $r['device_id'],
            'messages' => array_map([$this, 'messageFields'], $r['messages']),
        ];
    }

    /** GET v1/sms/api/balance — quota view for the account. */
    public function actionBalance(): array
    {
        $account = SmsAccount::forUser($this->uid());
        $quota = $account ? (int) $account->quota_monthly : 0;
        $usage = $account ? $account->usageThisMonth() : 0;
        $remaining = $account ? $account->remaining() : null; // null = unlimited

        return [
            'quota_monthly' => $quota,          // 0 = unlimited
            'used_this_month' => $usage,
            'remaining' => $remaining,          // null = unlimited
            'unlimited' => $remaining === null,
        ];
    }

    /**
     * GET v1/sms/api/messages?status=&phone=&limit=&offset=
     * Newest first. Mirrors the dashboard log, key-scoped.
     */
    public function actionMessages(): array
    {
        $req = Yii::$app->request;
        $q = SmsMessage::find()->where(['user_id' => $this->uid()]);

        $status = (string) $req->get('status', '');
        if ($status !== '' && in_array($status, SmsMessage::STATUSES, true)) {
            $q->andWhere(['status' => $status]);
        }
        if (($phone = trim((string) $req->get('phone', ''))) !== '') {
            $q->andWhere(['like', 'phone', $phone]);
        }

        $limit = min(200, max(1, (int) $req->get('limit', 50)));
        $offset = max(0, (int) $req->get('offset', 0));
        $total = (int) $q->count();
        $items = $q->orderBy(['id' => SORT_DESC])->limit($limit)->offset($offset)->all();

        return [
            'items' => array_map([$this, 'messageFields'], $items),
            'total' => $total,
            'limit' => $limit,
            'offset' => $offset,
        ];
    }

    /** GET v1/sms/api/messages/<id> — one message's current status. */
    public function actionMessage(int $id): array
    {
        $msg = SmsMessage::findOne(['id' => $id, 'user_id' => $this->uid()]);
        if ($msg === null) {
            throw new NotFoundHttpException('Xabar topilmadi.');
        }
        return $this->messageFields($msg);
    }

    /** GET v1/sms/api/devices — sending devices available to this account. */
    public function actionDevices(): array
    {
        $devices = SmsDevice::find()
            ->where(['user_id' => $this->uid()])
            ->orderBy(['id' => SORT_ASC])
            ->all();

        return ['items' => array_map(static fn (SmsDevice $d) => [
            'id' => (int) $d->id,
            'name' => $d->name,
            'status' => $d->status,
            'is_active' => (bool) $d->is_active,
        ], $devices)];
    }

    /** Stable public shape for a message (no internal columns leaked). */
    private function messageFields(SmsMessage $m): array
    {
        return [
            'id' => (int) $m->id,
            'phone' => $m->phone,
            'text' => $m->text,
            'status' => $m->status,
            'device_id' => $m->device_id !== null ? (int) $m->device_id : null,
            'external_id' => $m->external_id,
            'error' => $m->error,
            'sent_at' => $m->sent_at !== null ? (int) $m->sent_at : null,
            'created_at' => (int) $m->created_at,
        ];
    }
}
