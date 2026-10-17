<?php

namespace api\modules\me\controllers;

use common\models\Appointment;
use common\models\Service;
use common\models\TimeOff;
use common\models\WorkingHours;
use DateTimeImmutable;
use DateTimeZone;
use yii\db\Query;

/**
 * Staff self-service: own profile, own stats, own schedule.
 *
 *   GET v1/me/staff
 *   GET v1/me/stats?from=YYYY-MM-DD&to=YYYY-MM-DD      (business-local days, max 366)
 *   GET v1/me/schedule?from=YYYY-MM-DD&to=YYYY-MM-DD   (time-off filter, max 366)
 *
 * Revenue = SUM(services.price_tiyin) over completed appointments (same as
 * payroll); earnings = intval(revenue * commission_percent / 100).
 */
class MeController extends BaseMeController
{
    private const STATS_MAX_DAYS = 366;
    private const SCHEDULE_MAX_DAYS = 366;
    private const SCHEDULE_DEFAULT_DAYS = 60;

    /** Statuses that still lead to a visit (used for today.next_at). */
    private const UPCOMING_STATUSES = [
        Appointment::STATUS_PENDING,
        Appointment::STATUS_CONFIRMED,
        Appointment::STATUS_ARRIVED,
    ];

    /** GET v1/me/staff */
    public function actionStaff(): array
    {
        $staff = $this->staff();
        $business = $this->business();

        return [
            'id' => (int) $staff->id,
            'business_id' => (int) $staff->business_id,
            'name' => (string) $staff->name,
            'specialization' => $staff->specialization,
            'commission_percent' => (int) $staff->commission_percent,
            'is_active' => (bool) $staff->is_active,
            'business' => [
                'id' => (int) $business->id,
                'name' => (string) $business->name,
                'slug' => (string) $business->slug,
                'engine' => $business->engine ?: 'slot',
                'timezone' => $this->tz()->getName(),
                'logo' => $business->logo,
            ],
        ];
    }

    /** GET v1/me/stats */
    public function actionStats(): array
    {
        $staff = $this->staff();
        $today = $this->todayLocal();
        [$from, $to] = $this->localRange(substr($today, 0, 8) . '01', $today, self::STATS_MAX_DAYS);
        [$fromUtc, $toUtc] = $this->utcBounds($from, $to);
        $commission = (int) $staff->commission_percent;

        $rows = $this->appointmentRows((int) $staff->id, $fromUtc, $toUtc);

        $byStatus = array_fill_keys(Appointment::STATUSES, 0);
        $series = [];
        for ($d = $from; $d <= $to; $d = $this->addDays($d, 1)) {
            $series[$d] = ['date' => $d, 'count' => 0, 'completed' => 0, 'revenue_tiyin' => 0, 'earnings_tiyin' => 0];
        }
        $revenue = 0;
        $clients = [];

        foreach ($rows as $r) {
            $status = (string) $r['status'];
            if (array_key_exists($status, $byStatus)) {
                $byStatus[$status]++;
            }
            $day = $this->localDateOf((string) $r['starts_at']);
            if (isset($series[$day])) {
                $series[$day]['count']++;
            }
            if ($status === Appointment::STATUS_COMPLETED) {
                $price = (int) $r['price_tiyin'];
                $revenue += $price;
                if (isset($series[$day])) {
                    $series[$day]['completed']++;
                    $series[$day]['revenue_tiyin'] += $price;
                }
                if ($r['client_id'] !== null) {
                    $clients[(int) $r['client_id']] = true;
                }
            }
        }
        foreach ($series as &$entry) {
            $entry['earnings_tiyin'] = intval($entry['revenue_tiyin'] * $commission / 100);
        }
        unset($entry);

        return [
            'range' => ['from' => $from, 'to' => $to, 'timezone' => $this->tz()->getName()],
            'staff' => [
                'id' => (int) $staff->id,
                'name' => (string) $staff->name,
                'commission_percent' => $commission,
            ],
            'appointments' => ['total' => count($rows)] + $byStatus,
            'revenue_tiyin' => $revenue,
            'earnings_tiyin' => intval($revenue * $commission / 100),
            'clients_served' => count($clients),
            'series' => array_values($series),
            'today' => $this->todayBlock((int) $staff->id, $today),
        ];
    }

    /** GET v1/me/schedule */
    public function actionSchedule(): array
    {
        $staff = $this->staff();
        $today = $this->todayLocal();
        [$from, $to] = $this->localRange($today, $this->addDays($today, self::SCHEDULE_DEFAULT_DAYS), self::SCHEDULE_MAX_DAYS);

        $hours = WorkingHours::find()
            ->andWhere(['staff_id' => (int) $staff->id])
            ->orderBy(['weekday' => SORT_ASC, 'start_time' => SORT_ASC])
            ->all();

        $timeOff = TimeOff::find()
            ->andWhere(['staff_id' => (int) $staff->id])
            ->andWhere(['>=', 'date', $from])
            ->andWhere(['<=', 'date', $to])
            ->orderBy(['date' => SORT_ASC, 'start_time' => SORT_ASC])
            ->all();

        return [
            'working_hours' => array_map(static fn (WorkingHours $h): array => [
                'id' => (int) $h->id,
                'weekday' => (int) $h->weekday,
                'start_time' => (string) $h->start_time,
                'end_time' => (string) $h->end_time,
            ], $hours),
            'time_off' => array_map(static fn (TimeOff $t): array => [
                'id' => (int) $t->id,
                'date' => (string) $t->date,
                'start_time' => $t->start_time,
                'end_time' => $t->end_time,
                'reason' => $t->reason,
            ], $timeOff),
        ];
    }

    /**
     * Lightweight rows of the staff member's appointments in [fromUtc, toUtc]
     * with the service price (tenant-scoped explicitly by business_id).
     *
     * @return array<int, array{id:mixed,status:string,starts_at:string,client_id:mixed,price_tiyin:mixed}>
     */
    private function appointmentRows(int $staffId, string $fromUtc, string $toUtc): array
    {
        return (new Query())
            ->select([
                'id' => 'a.id',
                'status' => 'a.status',
                'starts_at' => 'a.starts_at',
                'client_id' => 'a.client_id',
                'price_tiyin' => 'COALESCE(s.price_tiyin, 0)',
            ])
            ->from(['a' => Appointment::tableName()])
            ->leftJoin(['s' => Service::tableName()], 's.id = a.service_id')
            ->where(['a.business_id' => (int) $this->business()->id, 'a.staff_id' => $staffId])
            ->andWhere(['>=', 'a.starts_at', $fromUtc])
            ->andWhere(['<=', 'a.starts_at', $toUtc])
            ->orderBy(['a.starts_at' => SORT_ASC])
            ->all();
    }

    /** {total, completed, next_at} for today (local); next_at = earliest upcoming visit from now. */
    private function todayBlock(int $staffId, string $today): array
    {
        [$fromUtc, $toUtc] = $this->utcBounds($today, $today);
        $businessId = (int) $this->business()->id;

        $counts = (new Query())
            ->select([
                'total' => 'COUNT(*)',
                'completed' => 'COALESCE(SUM(CASE WHEN status = :completed THEN 1 ELSE 0 END), 0)',
            ])
            ->from(Appointment::tableName())
            ->where(['business_id' => $businessId, 'staff_id' => $staffId])
            ->andWhere(['>=', 'starts_at', $fromUtc])
            ->andWhere(['<=', 'starts_at', $toUtc])
            ->addParams([':completed' => Appointment::STATUS_COMPLETED])
            ->one();

        $nowUtc = (new DateTimeImmutable('now', new DateTimeZone('UTC')))->format(self::UTC_FORMAT);
        $next = (new Query())
            ->select(['MIN(starts_at)'])
            ->from(Appointment::tableName())
            ->where(['business_id' => $businessId, 'staff_id' => $staffId, 'status' => self::UPCOMING_STATUSES])
            ->andWhere(['>=', 'starts_at', $nowUtc])
            ->scalar();

        return [
            'total' => (int) ($counts['total'] ?? 0),
            'completed' => (int) ($counts['completed'] ?? 0),
            'next_at' => is_string($next) && $next !== '' ? $next : null,
        ];
    }
}
