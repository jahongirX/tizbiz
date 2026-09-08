<?php

namespace api\modules\sms\controllers;

use common\models\SmsDevice;
use common\models\SmsPendingDevice;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * Android phones ("servers") registered by the account. The stored gateway
 * password is write-only (never returned; see SmsDevice::fields()).
 */
class DeviceController extends BaseController
{
    /** The phone announces itself with a shared token, not a user JWT. */
    protected function authOptional(): array
    {
        return ['announce'];
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
        $token = (string) Yii::$app->request->headers->get('X-Announce-Token', '');
        $expected = (string) (Yii::$app->params['sms.announce.token'] ?? '');
        if ($expected === '' || !hash_equals($expected, $token)) {
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

    /** Phones that announced themselves and are not yet attached to any account. */
    public function actionAvailable(): array
    {
        return SmsPendingDevice::find()
            ->where(['status' => SmsPendingDevice::STATUS_AVAILABLE])
            ->orderBy(['announced_at' => SORT_DESC])
            ->all();
    }

    /** Attach an announced phone to the current account (no typing of credentials). */
    public function actionClaim()
    {
        $deviceId = trim((string) $this->body('device_id'));
        $p = SmsPendingDevice::findOne([
            'device_id' => $deviceId,
            'status' => SmsPendingDevice::STATUS_AVAILABLE,
        ]);
        if ($p === null) {
            throw new NotFoundHttpException('Telefon topilmadi yoki band.');
        }

        $dev = new SmsDevice();
        $dev->user_id = $this->uid();
        $dev->name = $p->name ?: ('Telefon ' . substr($p->device_id, 0, 6));
        $dev->server = $p->server ?: (string) (Yii::$app->params['sms.gateway.base'] ?? '');
        $dev->login = $p->login;
        $dev->password = $p->password;
        $dev->is_active = true;
        if (!$dev->save()) {
            return $this->fail422($dev);
        }

        $p->status = SmsPendingDevice::STATUS_CLAIMED;
        $p->claimed_by = $this->uid();
        $p->sms_device_id = $dev->id;
        $p->claimed_at = time();
        $p->save(false);

        return $this->created($dev);
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
