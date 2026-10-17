<?php

namespace api\modules\site\controllers;

use common\models\Appointment;
use common\models\Business;
use common\models\Service;
use common\models\Staff;
use common\presenters\StaffPresenter;
use common\rest\Controller;
use DateTimeImmutable;
use DateTimeZone;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * Public business profile for the consumer booking page. No tenant JWT — the
 * business is resolved by its public slug and queries are filtered by its id.
 */
class SiteController extends Controller
{
    protected function authOptional(): array
    {
        return ['view', 'booked-days'];
    }

    /**
     * Booked (unavailable) dates for the rental / wedding-hall calendar. Returns
     * the business-local ISO days that already carry a live appointment, so the
     * public month calendar can grey them out. Range defaults to
     * today..today+booking_horizon_days; `min_date`/`max_date`/`lead_min` carry
     * the bookable window (BookingService rental rules).
     */
    public function actionBookedDays(string $slug): array
    {
        $business = Business::find()
            ->where(['slug' => $slug, 'status' => Business::STATUS_ACTIVE])
            ->one();
        if ($business === null) {
            throw new NotFoundHttpException('Biznes topilmadi.');
        }

        $tzName = (string) ($business->timezone ?: 'Asia/Tashkent');
        try {
            $tz = new DateTimeZone($tzName);
        } catch (\Throwable $e) {
            $tz = new DateTimeZone('Asia/Tashkent');
        }
        $utc = new DateTimeZone('UTC');

        $fromLocal = Yii::$app->request->get('from', '');
        $toLocal = Yii::$app->request->get('to', '');
        $fromLocal = is_string($fromLocal) ? $fromLocal : '';
        $toLocal = is_string($toLocal) ? $toLocal : '';
        $now = new DateTimeImmutable('now', $tz);
        $today = $now->setTime(0, 0);
        // The same window BookingService enforces for public rental bookings:
        // earliest day = the day of now + booking_lead_min, last day = today +
        // booking_horizon_days. The calendar disables everything outside it.
        $leadMin = max(0, (int) $business->booking_lead_min);
        $minDate = $now->modify('+' . $leadMin . ' minutes')->setTime(0, 0);
        $horizonDays = max(0, (int) $business->booking_horizon_days);
        $maxDate = $today->modify('+' . $horizonDays . ' days');
        $start = $fromLocal !== '' ? \DateTimeImmutable::createFromFormat('Y-m-d', $fromLocal, $tz) : false;
        $end = $toLocal !== '' ? \DateTimeImmutable::createFromFormat('Y-m-d', $toLocal, $tz) : false;
        if (!$start) {
            $start = $today;
        }
        if (!$end) {
            $end = $maxDate;
        }
        $start = $start->setTime(0, 0);
        $end = $end->setTime(23, 59, 59);

        $rows = Appointment::find()
            ->select(['starts_at', 'ends_at'])
            ->where(['business_id' => $business->id])
            ->andWhere(['not in', 'status', Appointment::RELEASED_STATUSES])
            ->andWhere(['>=', 'starts_at', $start->setTimezone($utc)->format('Y-m-d H:i:s')])
            ->andWhere(['<=', 'starts_at', $end->setTimezone($utc)->format('Y-m-d H:i:s')])
            ->asArray()
            ->all();

        // Map each booked date to the taken sessions. A wedding hall can host a
        // morning and an evening event on the same day, so the public calendar
        // greys out a date only for the session that is actually taken. Session
        // is derived from the local start hour (< 17 → morning, else evening);
        // a booking whose local span crosses 17:00 (e.g. the 10:00–23:00
        // whole-day default) takes both sessions.
        $days = [];
        foreach ($rows as $r) {
            try {
                $d = new DateTimeImmutable((string) $r['starts_at'], $utc);
            } catch (\Throwable $e) {
                continue;
            }
            $local = $d->setTimezone($tz);
            $iso = $local->format('Y-m-d');
            if (!isset($days[$iso])) {
                $days[$iso] = [];
            }
            $startsMorning = (int) $local->format('G') < 17;
            $endsAfterCut = false;
            if ($startsMorning && !empty($r['ends_at'])) {
                try {
                    $localEnd = (new DateTimeImmutable((string) $r['ends_at'], $utc))->setTimezone($tz);
                    $cut = $local->setTime(17, 0);
                    $endsAfterCut = $localEnd > $cut;
                } catch (\Throwable $e) {
                    $endsAfterCut = false;
                }
            }
            if ($startsMorning) {
                $days[$iso]['morning'] = true;
                if ($endsAfterCut) {
                    $days[$iso]['evening'] = true;
                }
            } else {
                $days[$iso]['evening'] = true;
            }
        }
        ksort($days);
        $out = [];
        foreach ($days as $iso => $sessions) {
            $out[$iso] = array_keys($sessions);
        }

        // Return an object; empty must serialize as {} not [] for the client map.
        return [
            'booked' => (object) $out,
            'min_date' => $minDate->format('Y-m-d'),
            'max_date' => $maxDate->format('Y-m-d'),
            'lead_min' => $leadMin,
        ];
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
        // Public staff view only (no user_id / commission_percent).
        $staff = array_map(
            [StaffPresenter::class, 'public'],
            Staff::find()->where(['business_id' => $business->id, 'is_active' => 1])->all()
        );

        return [
            'business' => $businessPayload,
            'services' => $services,
            'staff' => $staff,
        ];
    }
}
