<?php

namespace api\modules\booking\controllers;

use common\models\Service;
use common\models\ServiceCategory;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * CRUD for services. Reads: any authed member. Writes: owner/admin.
 * Money fields (price_tiyin, deposit_tiyin) are in tiyin.
 */
class ServiceController extends Controller
{
    public function actionIndex(): array
    {
        return Service::find()->orderBy(['name' => SORT_ASC])->all();
    }

    public function actionView(int $id): Service
    {
        return $this->findService($id);
    }

    public function actionCreate()
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = new Service();
        $model->business_id = Yii::$app->tenant->require();
        $this->assign($model);

        if (!$this->validateCategory($model)) {
            return $this->fail422($model);
        }
        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $this->created($model);
    }

    public function actionUpdate(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = $this->findService($id);
        $this->assign($model);

        if (!$this->validateCategory($model)) {
            return $this->fail422($model);
        }
        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $model;
    }

    public function actionDelete(int $id): array
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = $this->findService($id);
        $model->is_active = false;
        $model->save(false, ['is_active', 'updated_at']);
        return ['deleted' => true];
    }

    private function assign(Service $model): void
    {
        if (($v = $this->body('name')) !== null) {
            $model->name = (string) $v;
        }
        if (array_key_exists('category_id', $this->body())) {
            $model->category_id = $this->body('category_id');
        }
        if (($v = $this->body('duration_min')) !== null) {
            $model->duration_min = (int) $v;
        }
        if (($v = $this->body('price_tiyin')) !== null) {
            $model->price_tiyin = (int) $v;
        }
        if (array_key_exists('deposit_tiyin', $this->body())) {
            $v = $this->body('deposit_tiyin');
            $model->deposit_tiyin = $v === null ? null : (int) $v;
        }
        if (($v = $this->body('is_active')) !== null) {
            $model->is_active = (bool) $v;
        }
        if (($v = $this->body('online_bookable')) !== null) {
            $model->online_bookable = (bool) $v;
        }
        if (array_key_exists('image', $this->body())) {
            $v = $this->body('image');
            $model->image = ($v === null || $v === '') ? null : (string) $v;
        }
        if (array_key_exists('description', $this->body())) {
            $v = $this->body('description');
            $model->description = ($v === null || $v === '') ? null : (string) $v;
        }
        if (array_key_exists('gallery', $this->body())) {
            $v = $this->body('gallery');
            // Keep only non-empty string URLs.
            $model->gallery = is_array($v)
                ? array_values(array_filter(array_map('strval', $v), static fn ($u) => trim($u) !== ''))
                : null;
        }
    }

    /** Ensure category_id (if set) belongs to the same business. */
    private function validateCategory(Service $model): bool
    {
        if (empty($model->category_id)) {
            return true;
        }
        $exists = ServiceCategory::find()
            ->andWhere(['id' => $model->category_id, 'business_id' => $model->business_id])
            ->exists();
        if (!$exists) {
            $model->addError('category_id', 'Kategoriya bu biznesga tegishli emas.');
            return false;
        }
        return true;
    }

    private function findService(int $id): Service
    {
        $model = Service::findOne($id);
        if ($model === null) {
            throw new NotFoundHttpException('Xizmat topilmadi.');
        }
        return $model;
    }
}
