<?php

namespace api\modules\sms\controllers;

use common\models\SmsDevice;
use yii\web\NotFoundHttpException;

/**
 * Android phones ("servers") registered by the account. The stored gateway
 * password is write-only (never returned; see SmsDevice::fields()).
 */
class DeviceController extends BaseController
{
    public function actionIndex(): array
    {
        return SmsDevice::find()
            ->where(['user_id' => $this->uid()])
            ->orderBy(['id' => SORT_DESC])
            ->all();
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
