<?php

namespace api\modules\booking\controllers;

use api\modules\booking\services\AvailabilityService;
use common\models\Staff;
use common\rest\Controller;
use Yii;
use yii\web\BadRequestHttpException;
use yii\web\NotFoundHttpException;

/**
 * Public availability lookup for the consumer booking page.
 * GET /v1/staff/<id>/availability?date=YYYY-MM-DD&service_id=...
 *
 * No tenant context is assumed (endpoint is anonymous): staff is loaded by id
 * directly and the service is verified against the staff's business.
 */
class AvailabilityController extends Controller
{
    protected function authOptional(): array
    {
        return ['index'];
    }

    public function actionIndex(int $id): array
    {
        $date = (string) Yii::$app->request->get('date', '');
        $serviceId = (int) Yii::$app->request->get('service_id', 0);

        if ($date === '' || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
            throw new BadRequestHttpException('Yaroqli sana (YYYY-MM-DD) talab qilinadi.');
        }
        if ($serviceId <= 0) {
            throw new BadRequestHttpException('service_id talab qilinadi.');
        }

        $staff = Staff::findOne($id);
        if ($staff === null) {
            throw new NotFoundHttpException('Xodim topilmadi.');
        }

        return (new AvailabilityService())->slots($staff, $date, $serviceId);
    }
}
