<?php

namespace api\modules\site\controllers;

use common\models\Business;
use common\models\Service;
use common\models\Staff;
use common\rest\Controller;
use yii\web\NotFoundHttpException;

/**
 * Public business profile for the consumer booking page. No tenant JWT — the
 * business is resolved by its public slug and queries are filtered by its id.
 */
class SiteController extends Controller
{
    protected function authOptional(): array
    {
        return ['view'];
    }

    public function actionView(string $slug): array
    {
        $business = Business::find()
            ->where(['slug' => $slug, 'status' => Business::STATUS_ACTIVE])
            ->one();
        if ($business === null) {
            throw new NotFoundHttpException('Biznes topilmadi.');
        }

        // Refactor stage 5/6: the business's engine builds its own public
        // payload (so a new vertical = a new engine class, no change here).
        // Flag-gated (stage 7): when off, the original inline slot logic below
        // runs unchanged, keeping the flow fully reversible. Default on — the
        // slot engine mirrors the exact payload the inline path produced, plus
        // an `engine` key the public SPA uses to pick its layout.
        if ($business->hasFeature('engine_dispatch', true)) {
            return $business->engine()->publicData($business);
        }

        $bookingEnabled = (bool) $business->online_booking_enabled;

        $businessPayload = [
            'id' => (int) $business->id,
            'name' => $business->name,
            'slug' => $business->slug,
            'category' => $business->category,
            'phone' => $business->phone,
            'timezone' => $business->timezone,
            'online_booking_enabled' => $bookingEnabled,
        ];

        // Booking closed: return the business flagged closed with no services/staff.
        if (!$bookingEnabled) {
            return [
                'business' => $businessPayload,
                'services' => [],
                'staff' => [],
            ];
        }

        // Only online-bookable, active services are offered publicly.
        $services = Service::find()
            ->where(['business_id' => $business->id, 'is_active' => 1, 'online_bookable' => 1])
            ->all();
        $staff = Staff::find()
            ->where(['business_id' => $business->id, 'is_active' => 1])
            ->all();

        return [
            'business' => $businessPayload,
            'services' => $services,
            'staff' => $staff,
        ];
    }
}
