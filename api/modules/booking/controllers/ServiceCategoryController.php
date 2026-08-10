<?php

namespace api\modules\booking\controllers;

use common\models\ServiceCategory;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * CRUD for service categories. Reads: any authed member. Writes: owner/admin.
 */
class ServiceCategoryController extends Controller
{
    public function actionIndex(): array
    {
        return ServiceCategory::find()->orderBy(['sort' => SORT_ASC, 'id' => SORT_ASC])->all();
    }

    public function actionView(int $id): ServiceCategory
    {
        return $this->findCategory($id);
    }

    public function actionCreate()
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = new ServiceCategory();
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

        $model = $this->findCategory($id);
        $this->assign($model);

        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $model;
    }

    public function actionDelete(int $id): array
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = $this->findCategory($id);
        $model->delete();
        return ['deleted' => true];
    }

    private function assign(ServiceCategory $model): void
    {
        if (($v = $this->body('name')) !== null) {
            $model->name = (string) $v;
        }
        if (($v = $this->body('sort')) !== null) {
            $model->sort = (int) $v;
        }
        if (array_key_exists('image', $this->body())) {
            $v = $this->body('image');
            $model->image = ($v === null || $v === '') ? null : (string) $v;
        }
    }

    private function findCategory(int $id): ServiceCategory
    {
        $model = ServiceCategory::findOne($id);
        if ($model === null) {
            throw new NotFoundHttpException('Xizmat kategoriyasi topilmadi.');
        }
        return $model;
    }
}
