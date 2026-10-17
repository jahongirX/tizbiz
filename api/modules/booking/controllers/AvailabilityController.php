<?php

namespace api\modules\booking\controllers;

use api\modules\booking\services\AvailabilityService;
use api\modules\booking\services\BookingService;
use common\models\Business;
use common\models\Service;
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
        $business = $staff !== null ? Business::findOne((int) $staff->business_id) : null;
        if ($staff === null || $business === null || (int) $business->status !== Business::STATUS_ACTIVE) {
            throw new NotFoundHttpException('Xodim topilmadi.');
        }

        // Booking closed, or the service is not publicly bookable: nothing to offer
        // (mirrors the rules POST /v1/appointments enforces for public/consumer
        // callers). The business's own owner/admin (admin "new booking" modal)
        // still sees the grid, as admin-mode creation skips those rules too.
        $user = $this->currentUser();
        $isOwnAdmin = $user !== null
            && $user->activeTenantId === (int) $staff->business_id
            && in_array($user->activeRole, [Business::ROLE_OWNER, Business::ROLE_ADMIN], true);
        $service = Service::find()
            ->andWhere(['id' => $serviceId, 'business_id' => (int) $staff->business_id])
            ->one();
        if (!$isOwnAdmin && (!$business->online_booking_enabled || $service === null
            || !($service->is_active && $service->online_bookable))) {
            return [
                'date' => $date,
                'timezone' => BookingService::businessTimezone($business),
                'slots' => [],
            ];
        }

        return (new AvailabilityService())->slots($staff, $date, $serviceId);
    }
}
