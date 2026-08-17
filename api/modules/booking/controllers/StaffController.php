<?php

namespace api\modules\booking\controllers;

use common\models\Staff;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * CRUD for staff members. Reads: any authed member. Writes: owner/admin.
 * DELETE is a soft delete (is_active = 0).
 */
class StaffController extends Controller
{
    public function actionIndex(): array
    {
        return Staff::find()->orderBy(['name' => SORT_ASC])->all();
    }

    public function actionView(int $id): Staff
    {
        return $this->findStaff($id);
    }

    public function actionCreate()
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = new Staff();
        $model->business_id = Yii::$app->tenant->require();
        $this->assign($model);

        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $this->created($model);
    }

    public function actionUpdate(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = $this->findStaff($id);
        $this->assign($model);

        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $model;
    }

    public function actionDelete(int $id): Staff
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = $this->findStaff($id);
        $model->is_active = false;
        $model->save(false, ['is_active', 'updated_at']);
        return $model;
    }

    private function assign(Staff $model): void
    {
        if (($v = $this->body('name')) !== null) {
            $model->name = (string) $v;
        }
        if (array_key_exists('specialization', $this->body())) {
            $model->specialization = $this->body('specialization');
        }
        // Empty string clears the photo, mirroring the branding fields.
        if (array_key_exists('avatar', $this->body())) {
            $v = $this->body('avatar');
            $model->avatar = ($v === null || trim((string) $v) === '') ? null : trim((string) $v);
        }
        if (array_key_exists('user_id', $this->body())) {
            $model->user_id = $this->body('user_id');
        }
        if (($v = $this->body('is_active')) !== null) {
            $model->is_active = (bool) $v;
        }
        if (($v = $this->body('commission_percent')) !== null) {
            $model->commission_percent = (int) $v;
        }
    }

    private function findStaff(int $id): Staff
    {
        $model = Staff::findOne($id);
        if ($model === null) {
            throw new NotFoundHttpException('Xodim topilmadi.');
        }
        return $model;
    }
}
