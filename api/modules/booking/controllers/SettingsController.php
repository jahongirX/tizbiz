<?php

namespace api\modules\booking\controllers;

use common\models\Business;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * Online-booking settings for the active business.
 * Read: any authed member. Write: owner/admin.
 */
class SettingsController extends Controller
{
    public function actionView(): array
    {
        return $this->payload($this->business());
    }

    public function actionUpdate(): array
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = $this->business();

        if (($v = $this->body('online_booking_enabled')) !== null) {
            $model->online_booking_enabled = (bool) $v;
        }
        if (($v = $this->body('booking_lead_min')) !== null) {
            $model->booking_lead_min = (int) $v;
        }
        if (($v = $this->body('booking_horizon_days')) !== null) {
            $model->booking_horizon_days = (int) $v;
        }

        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $this->payload($model);
    }

    private function payload(Business $b): array
    {
        return [
            'online_booking_enabled' => (bool) $b->online_booking_enabled,
            'booking_lead_min' => (int) $b->booking_lead_min,
            'booking_horizon_days' => (int) $b->booking_horizon_days,
        ];
    }

    private function business(): Business
    {
        $model = Business::findOne(Yii::$app->tenant->require());
        if ($model === null) {
            throw new NotFoundHttpException('Biznes topilmadi.');
        }
        return $model;
    }
}
