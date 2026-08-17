<?php

namespace api\modules\sms\controllers;

use common\models\SmsTemplate;
use yii\web\NotFoundHttpException;

/**
 * Reusable message texts for the account. CRUD; picked when composing a message.
 */
class TemplateController extends BaseController
{
    public function actionIndex(): array
    {
        return SmsTemplate::find()
            ->where(['user_id' => $this->uid()])
            ->orderBy(['id' => SORT_DESC])
            ->all();
    }

    public function actionCreate()
    {
        $model = new SmsTemplate();
        $model->user_id = $this->uid();
        $this->assign($model);
        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $this->created($model);
    }

    public function actionUpdate(int $id)
    {
        $model = $this->find($id);
        $this->assign($model);
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

    private function assign(SmsTemplate $model): void
    {
        if (($v = $this->body('name')) !== null) {
            $model->name = trim((string) $v);
        }
        if (($v = $this->body('text')) !== null) {
            $model->text = (string) $v;
        }
    }

    private function find(int $id): SmsTemplate
    {
        $model = SmsTemplate::findOne(['id' => $id, 'user_id' => $this->uid()]);
        if ($model === null) {
            throw new NotFoundHttpException('Shablon topilmadi.');
        }
        return $model;
    }
}
