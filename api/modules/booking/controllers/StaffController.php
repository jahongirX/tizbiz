<?php

namespace api\modules\booking\controllers;

use common\models\Business;
use common\models\Staff;
use common\rest\Controller;
use Yii;
use yii\web\ConflictHttpException;
use yii\web\ForbiddenHttpException;
use yii\web\NotFoundHttpException;

/**
 * CRUD for staff members. Reads and writes: owner/admin (staff use /v1/me/*).
 * DELETE is a soft delete (is_active = 0). `user_id` (login link) is owner-only.
 */
class StaffController extends Controller
{
    public function actionIndex(): array
    {
        $this->requireRole('business_owner', 'business_admin');
        Yii::$app->tenant->require();
        return Staff::find()->orderBy(['name' => SORT_ASC])->all();
    }

    public function actionView(int $id): Staff
    {
        $this->requireRole('business_owner', 'business_admin');
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
        if (array_key_exists('user_id', $this->body())) {
            $this->assignUserLink($model, $this->body('user_id'));
        }
        if (($v = $this->body('is_active')) !== null) {
            $model->is_active = (bool) $v;
        }
        if (($v = $this->body('commission_percent')) !== null) {
            $model->commission_percent = (int) $v;
        }
    }

    /**
     * Login link (user_id). Linking is owner-only, like /v1/team: an admin may
     * only echo the current value back. A row already linked to another account
     * is never re-pointed here (409, same as TeamController); unlink first
     * (user_id: null) or use PATCH /v1/team/{userId} {staff_id}.
     */
    private function assignUserLink(Staff $model, $raw): void
    {
        $new = ($raw === null || $raw === '') ? null : $raw;
        $current = $model->user_id !== null ? (int) $model->user_id : null;
        $same = ($new === null && $current === null)
            || ($new !== null && is_scalar($new) && $current !== null && (string) $new === (string) $current);
        if ($same) {
            return;
        }
        $user = $this->currentUser();
        if ($user === null || $user->activeRole !== Business::ROLE_OWNER) {
            throw new ForbiddenHttpException('Xodimni hisobga faqat biznes egasi bog\'lay oladi.');
        }
        if ($new !== null && $current !== null) {
            throw new ConflictHttpException('Bu xodim boshqa hisobga bog\'langan.');
        }
        $model->user_id = $new;
    }

    private function findStaff(int $id): Staff
    {
        Yii::$app->tenant->require();
        $model = Staff::findOne($id);
        if ($model === null) {
            throw new NotFoundHttpException('Xodim topilmadi.');
        }
        return $model;
    }
}
