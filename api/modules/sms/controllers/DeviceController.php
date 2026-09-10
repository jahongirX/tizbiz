<?php

namespace api\modules\sms\controllers;

use common\helpers\Phone;
use common\models\SmsDevice;
use common\models\SmsPendingDevice;
use common\models\User;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * Android phones ("servers") registered by the account. The stored gateway
 * password is write-only (never returned; see SmsDevice::fields()).
 */
class DeviceController extends BaseController
{
    /** These use the shared announce token (X-Announce-Token), not a user JWT. */
    protected function authOptional(): array
    {
        return ['announce', 'claim-request', 'confirm-claim'];
    }

    /** True if the request carries the valid shared announce token. */
    private function announceAuthorized(): bool
    {
        $token = (string) Yii::$app->request->headers->get('X-Announce-Token', '');
        $expected = (string) (Yii::$app->params['sms.announce.token'] ?? '');
        return $expected !== '' && hash_equals($expected, $token);
    }

    public function actionIndex(): array
    {
        return SmsDevice::find()
            ->where(['user_id' => $this->uid()])
            ->orderBy(['id' => SORT_DESC])
            ->all();
    }

    /**
     * The TizBiz SMS app POSTs here after registering on the gateway, sending its
     * issued credentials so the phone can be attached from the dashboard without
     * typing. Auth: shared token in the X-Announce-Token header. Re-announcing a
     * claimed device refreshes the linked device's credentials.
     */
    public function actionAnnounce(): array
    {
        if (!$this->announceAuthorized()) {
            Yii::$app->response->statusCode = 401;
            return ['ok' => false, 'error' => 'unauthorized'];
        }
        $deviceId = trim((string) $this->body('device_id'));
        if ($deviceId === '') {
            Yii::$app->response->statusCode = 422;
            return ['ok' => false, 'error' => 'device_id required'];
        }
        $login = trim((string) $this->body('login'));
        $password = (string) $this->body('password');
        $name = trim((string) $this->body('name'));
        $sim = trim((string) $this->body('sim_number'));
        $server = trim((string) $this->body('server'));

        $p = SmsPendingDevice::findOne(['device_id' => $deviceId]) ?? new SmsPendingDevice();
        if ($p->isNewRecord) {
            $p->device_id = $deviceId;
            $p->status = SmsPendingDevice::STATUS_AVAILABLE;
        }
        if ($login !== '') {
            $p->login = mb_substr($login, 0, 190);
        }
        if ($password !== '') {
            $p->password = mb_substr($password, 0, 255);
        }
        if ($name !== '') {
            $p->name = mb_substr($name, 0, 120);
        }
        if ($sim !== '') {
            $p->sim_number = mb_substr($sim, 0, 32);
        }
        if ($server !== '') {
            $p->server = mb_substr($server, 0, 255);
        }
        $p->announced_at = time();
        $p->save(false);

        // Keep an already-attached device's credentials in sync on re-registration.
        if ($p->status === SmsPendingDevice::STATUS_CLAIMED && $p->sms_device_id) {
            $dev = SmsDevice::findOne($p->sms_device_id);
            if ($dev) {
                if ($login !== '') {
                    $dev->login = $login;
                }
                if ($password !== '') {
                    $dev->password = $password;
                }
                if ($server !== '') {
                    $dev->server = $server;
                }
                $dev->save(false);
            }
        }
        return ['ok' => true, 'status' => $p->status];
    }

    /**
     * Phones that announced themselves and are not yet attached to any account —
     * scoped to THIS account: only phones whose SIM number matches the account's
     * own phone number are shown. A phone with an unreadable/blank SIM (or one
     * belonging to a different number) is invisible here, so one account never
     * sees another's phones. The number is captured in the app (SIM auto-read, or
     * typed by the user under "This phone's number").
     */
    public function actionAvailable(): array
    {
        $mine = Phone::normalize($this->currentUser()?->phone);
        if ($mine === null) {
            return [];
        }
        $pending = SmsPendingDevice::find()
            ->where(['status' => SmsPendingDevice::STATUS_AVAILABLE])
            ->orderBy(['announced_at' => SORT_DESC])
            ->all();
        return array_values(array_filter(
            $pending,
            static fn (SmsPendingDevice $p): bool => Phone::normalize($p->sim_number) === $mine
        ));
    }

    /**
     * Step 1 of pairing (dashboard): the operator asks to attach a phone by its
     * NUMBER (or by a device_id from the available list). This does NOT bind yet —
     * it records the request; the phone must confirm from the app before the two
     * are linked ({@see actionConfirmClaim}).
     */
    public function actionClaim(): array
    {
        $deviceId = trim((string) $this->body('device_id'));
        $phone = Phone::normalize((string) $this->body('phone'));

        $base = SmsPendingDevice::find()->where(['status' => SmsPendingDevice::STATUS_AVAILABLE]);
        if ($deviceId !== '') {
            $p = $base->andWhere(['device_id' => $deviceId])->one();
        } elseif ($phone !== null) {
            // Match by the phone's own SIM / entered number, newest announce first.
            $p = null;
            foreach ($base->orderBy(['announced_at' => SORT_DESC])->all() as $cand) {
                if (Phone::normalize($cand->sim_number) === $phone) {
                    $p = $cand;
                    break;
                }
            }
        } else {
            Yii::$app->response->statusCode = 422;
            return ['ok' => false, 'error' => 'Telefon raqamini kiriting.'];
        }

        if ($p === null) {
            throw new NotFoundHttpException('Bu raqamli telefon topilmadi. Ilovani o‘rnatib, raqamni kiriting.');
        }

        $p->claim_requested_by = $this->uid();
        $p->claim_requested_at = time();
        $p->save(false);

        return [
            'ok' => true,
            'waiting' => true,
            'device_id' => $p->device_id,
            'name' => $p->name,
            'phone' => $p->sim_number,
        ];
    }

    /**
     * The phone polls this (shared token) to learn whether an operator is waiting
     * to attach it, so it can prompt the user to confirm.
     */
    public function actionClaimRequest(): array
    {
        if (!$this->announceAuthorized()) {
            Yii::$app->response->statusCode = 401;
            return ['ok' => false, 'error' => 'unauthorized'];
        }
        $deviceId = trim((string) Yii::$app->request->get('device_id'));
        $p = SmsPendingDevice::findOne(['device_id' => $deviceId]);
        if ($p === null || $p->status !== SmsPendingDevice::STATUS_AVAILABLE || !$p->claim_requested_by) {
            return ['pending' => false];
        }
        $acc = User::findOne($p->claim_requested_by);
        return [
            'pending' => true,
            'requested_at' => (int) $p->claim_requested_at,
            'account' => $acc ? ($acc->name ?: $acc->phone) : null,
        ];
    }

    /**
     * Step 2 of pairing: the phone approves/rejects from the app (shared token).
     * On approve we finally create the {@see SmsDevice} for the requesting account.
     */
    public function actionConfirmClaim(): array
    {
        if (!$this->announceAuthorized()) {
            Yii::$app->response->statusCode = 401;
            return ['ok' => false, 'error' => 'unauthorized'];
        }
        $deviceId = trim((string) $this->body('device_id'));
        $approve = filter_var($this->body('approve'), FILTER_VALIDATE_BOOLEAN);

        $p = SmsPendingDevice::findOne([
            'device_id' => $deviceId,
            'status' => SmsPendingDevice::STATUS_AVAILABLE,
        ]);
        if ($p === null || !$p->claim_requested_by) {
            Yii::$app->response->statusCode = 404;
            return ['ok' => false, 'error' => 'no request'];
        }

        if (!$approve) {
            $p->claim_requested_by = null;
            $p->claim_requested_at = null;
            $p->save(false);
            return ['ok' => true, 'status' => 'rejected'];
        }

        $dev = new SmsDevice();
        $dev->user_id = (int) $p->claim_requested_by;
        $dev->name = $p->name ?: ('Telefon ' . substr($p->device_id, 0, 6));
        $dev->server = $p->server ?: (string) (Yii::$app->params['sms.gateway.base'] ?? '');
        $dev->login = $p->login;
        $dev->password = $p->password;
        $dev->is_active = true;
        if (!$dev->save()) {
            Yii::$app->response->statusCode = 422;
            return ['ok' => false, 'error' => 'device save failed'];
        }

        $p->status = SmsPendingDevice::STATUS_CLAIMED;
        $p->claimed_by = (int) $p->claim_requested_by;
        $p->sms_device_id = (int) $dev->id;
        $p->claimed_at = time();
        $p->claim_requested_by = null;
        $p->claim_requested_at = null;
        $p->save(false);

        return ['ok' => true, 'status' => 'claimed'];
    }

    public function actionCreate()
    {
        $model = new SmsDevice();
        $model->user_id = $this->uid();
        $this->assign($model, true);
        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $this->created($model);
    }

    public function actionUpdate(int $id)
    {
        $model = $this->find($id);
        $this->assign($model, false);
        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $model;
    }

    public function actionDelete(int $id): array
    {
        $this->find($id)->delete();
        return ['deleted' => true];
    }

    private function assign(SmsDevice $model, bool $isNew): void
    {
        if (($v = $this->body('name')) !== null) {
            $model->name = (string) $v;
        }
        foreach (['server', 'login'] as $attr) {
            if (array_key_exists($attr, $this->body())) {
                $v = $this->body($attr);
                $model->$attr = ($v === null || trim((string) $v) === '') ? null : trim((string) $v);
            }
        }
        // Password: only overwrite when a non-empty value is supplied, so editing
        // a device without re-typing the password keeps the stored one.
        $pw = $this->body('password');
        if ($pw !== null && trim((string) $pw) !== '') {
            $model->password = (string) $pw;
        }
        if (($v = $this->body('is_active')) !== null) {
            $model->is_active = (bool) $v;
        }
    }

    private function find(int $id): SmsDevice
    {
        $model = SmsDevice::findOne(['id' => $id, 'user_id' => $this->uid()]);
        if ($model === null) {
            throw new NotFoundHttpException('Server topilmadi.');
        }
        return $model;
    }
}
