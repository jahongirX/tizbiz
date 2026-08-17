<?php

namespace api\modules\sms\controllers;

use common\models\SmsContact;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * Saved recipients (name + phone) for the account. CRUD + search by name/phone.
 */
class ContactController extends BaseController
{
    public function actionIndex(): array
    {
        $q = SmsContact::find()->where(['user_id' => $this->uid()]);

        if (($term = trim((string) Yii::$app->request->get('q', ''))) !== '') {
            $q->andWhere(['or', ['like', 'name', $term], ['like', 'phone', $term]]);
        }

        return $q->orderBy(['name' => SORT_ASC])->all();
    }

    public function actionCreate()
    {
        $model = new SmsContact();
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

    private function assign(SmsContact $model): void
    {
        if (($v = $this->body('name')) !== null) {
            $model->name = trim((string) $v);
        }
        if (($v = $this->body('phone')) !== null) {
            $model->phone = trim((string) $v);
        }
        if (array_key_exists('note', $this->body())) {
            $v = $this->body('note');
            $model->note = ($v === null || trim((string) $v) === '') ? null : trim((string) $v);
        }
    }

    private function find(int $id): SmsContact
    {
        $model = SmsContact::findOne(['id' => $id, 'user_id' => $this->uid()]);
        if ($model === null) {
            throw new NotFoundHttpException('Kontakt topilmadi.');
        }
        return $model;
    }
}
