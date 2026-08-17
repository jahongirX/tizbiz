<?php

namespace api\modules\sms\controllers;

use common\models\SmsBlacklist;
use yii\web\NotFoundHttpException;

/**
 * Numbers that must never receive messages from the account. The send pipeline
 * drops any recipient matching an entry here (see SendController).
 */
class BlacklistController extends BaseController
{
    public function actionIndex(): array
    {
        return SmsBlacklist::find()
            ->where(['user_id' => $this->uid()])
            ->orderBy(['id' => SORT_DESC])
            ->all();
    }

    public function actionCreate()
    {
        $model = new SmsBlacklist();
        $model->user_id = $this->uid();
        if (($v = $this->body('phone')) !== null) {
            $model->phone = trim((string) $v);
        }
        if (($v = $this->body('reason')) !== null && trim((string) $v) !== '') {
            $model->reason = trim((string) $v);
        }
        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $this->created($model);
    }

    public function actionDelete(int $id): array
    {
        $model = SmsBlacklist::findOne(['id' => $id, 'user_id' => $this->uid()]);
        if ($model === null) {
            throw new NotFoundHttpException('Yozuv topilmadi.');
        }
        $model->delete();
        return ['deleted' => true];
    }
}
