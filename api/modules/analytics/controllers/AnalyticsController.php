<?php

namespace api\modules\analytics\controllers;

use common\models\Appointment;
use common\models\Client;
use common\models\Service;
use common\models\Staff;
use common\rest\Controller;
use DateInterval;
use DatePeriod;
use DateTimeImmutable;
use DateTimeZone;
use Yii;
use yii\db\Query;

/**
 * Business analytics overview.
 *
 * All figures are scoped to the active tenant and to a [from,to] date window
 * (default: last 30 days). Appointment/service metrics filter on the UTC
 * `starts_at` datetime; new-client counts filter on the integer `created_at`
 * unix timestamp. Revenue is the sum of the service price_tiyin over completed
 * appointments only.
 */
class AnalyticsController extends Controller
{
    private const DATE_FORMAT = 'Y-m-d';

    /**
     * GET /v1/analytics/overview?from=&to=
     * Any authenticated user of the tenant may read.
     */
    public function actionOverview(): array
    {
        $businessId = Yii::$app->tenant->require();

        [$from, $to] = $this->range();
        $fromDt = $from . ' 00:00:00';
        $toDt = $to . ' 23:59:59';

        $db = Yii::$app->db;
        $completedQ = $db->quoteValue(Appointment::STATUS_COMPLETED);
        // A visit can carry more than its primary service (soch + soqol); those
        // extras live in appointment_items and were missing from revenue, so
        // Analitika read lower than Moliya for the same days.
        $serviceKindQ = $db->quoteValue(\common\models\AppointmentItem::KIND_SERVICE);
        $itemsTable = \common\models\AppointmentItem::tableName();
        $extrasExpr = "(SELECT COALESCE(SUM(ai.price_tiyin * ai.qty), 0) FROM $itemsTable ai"
            . " WHERE ai.appointment_id = a.id AND ai.kind = $serviceKindQ)";
        $revenueExpr = "SUM(CASE WHEN a.status = $completedQ THEN s.price_tiyin + $extrasExpr ELSE 0 END)";

        // --- Aggregate row: totals, per-status counts, revenue ----------------
        $statuses = [
            Appointment::STATUS_PENDING,
            Appointment::STATUS_CONFIRMED,
            Appointment::STATUS_ARRIVED,
            Appointment::STATUS_COMPLETED,
            Appointment::STATUS_NO_SHOW,
            Appointment::STATUS_CANCELED,
        ];
        $select = ['total' => 'COUNT(*)', 'revenue_tiyin' => $revenueExpr];
        foreach ($statuses as $st) {
            $q = $db->quoteValue($st);
            $select['st_' . $st] = "SUM(CASE WHEN a.status = $q THEN 1 ELSE 0 END)";
        }
        $agg = $this->scopedQuery($businessId, $fromDt, $toDt)
            ->select($select)
            ->one($db);

        $total = (int) ($agg['total'] ?? 0);
        $noShow = (int) ($agg['st_' . Appointment::STATUS_NO_SHOW] ?? 0);

        $appointments = [
            'total' => $total,
            'completed' => (int) ($agg['st_' . Appointment::STATUS_COMPLETED] ?? 0),
            'no_show' => $noShow,
            'canceled' => (int) ($agg['st_' . Appointment::STATUS_CANCELED] ?? 0),
            'pending' => (int) ($agg['st_' . Appointment::STATUS_PENDING] ?? 0),
            'confirmed' => (int) ($agg['st_' . Appointment::STATUS_CONFIRMED] ?? 0),
            'arrived' => (int) ($agg['st_' . Appointment::STATUS_ARRIVED] ?? 0),
        ];
        $noShowRate = $total > 0 ? round($noShow / $total * 100, 2) : 0.0;

        // --- Clients: total (all-time for tenant) + new (created in range) ----
        $newFrom = $this->dayStartTs($from);
        $newTo = $this->dayEndTs($to);
        $clientsTotal = (int) Client::find()
            ->andWhere(['business_id' => $businessId])
            ->count();
        $clientsNew = (int) Client::find()
            ->andWhere(['business_id' => $businessId])
            ->andWhere(['>=', 'created_at', $newFrom])
            ->andWhere(['<=', 'created_at', $newTo])
            ->count();

        // --- Per-day series (zero-filled across every date in [from,to]) ------
        $seriesRows = $this->scopedQuery($businessId, $fromDt, $toDt)
            ->select([
                'd' => 'DATE(a.starts_at)',
                'appointments' => 'COUNT(*)',
                'revenue_tiyin' => $revenueExpr,
            ])
            ->groupBy(['d'])
            ->all($db);
        $byDay = [];
        foreach ($seriesRows as $row) {
            $byDay[(string) $row['d']] = [
                'revenue_tiyin' => (int) $row['revenue_tiyin'],
                'appointments' => (int) $row['appointments'],
            ];
        }
        $series = [];
        foreach ($this->eachDate($from, $to) as $date) {
            $hit = $byDay[$date] ?? null;
            $series[] = [
                'date' => $date,
                'revenue_tiyin' => $hit['revenue_tiyin'] ?? 0,
                'appointments' => $hit['appointments'] ?? 0,
            ];
        }

        // --- Top services -----------------------------------------------------
        $topServices = $this->scopedQuery($businessId, $fromDt, $toDt)
            ->select([
                'service_id' => 'a.service_id',
                'name' => 's.name',
                'count' => 'COUNT(*)',
                'revenue_tiyin' => $revenueExpr,
            ])
            ->groupBy(['a.service_id', 's.name'])
            ->orderBy(['count' => SORT_DESC, 'revenue_tiyin' => SORT_DESC])
            ->limit(10)
            ->all($db);
        $topServices = array_map(static function (array $r): array {
            return [
                'service_id' => (int) $r['service_id'],
                'name' => (string) ($r['name'] ?? ''),
                'count' => (int) $r['count'],
                'revenue_tiyin' => (int) $r['revenue_tiyin'],
            ];
        }, $topServices);

        // --- Staff load -------------------------------------------------------
        $staffLoad = $this->scopedQuery($businessId, $fromDt, $toDt)
            ->select([
                'staff_id' => 'a.staff_id',
                'name' => 'st.name',
                'count' => 'COUNT(*)',
                'revenue_tiyin' => $revenueExpr,
            ])
            ->leftJoin(['st' => Staff::tableName()], 'st.id = a.staff_id')
            ->groupBy(['a.staff_id', 'st.name'])
            ->orderBy(['count' => SORT_DESC, 'revenue_tiyin' => SORT_DESC])
            ->all($db);
        $staffLoad = array_map(static function (array $r): array {
            return [
                'staff_id' => (int) $r['staff_id'],
                'name' => (string) ($r['name'] ?? ''),
                'count' => (int) $r['count'],
                'revenue_tiyin' => (int) $r['revenue_tiyin'],
            ];
        }, $staffLoad);

        return [
            'revenue_tiyin' => (int) ($agg['revenue_tiyin'] ?? 0),
            'appointments' => $appointments,
            'no_show_rate' => (float) $noShowRate,
            'clients' => [
                'total' => $clientsTotal,
                'new' => $clientsNew,
            ],
            'series' => $series,
            'top_services' => $topServices,
            'staff_load' => $staffLoad,
        ];
    }

    /**
     * Base tenant-scoped, date-bounded appointment query joined to services.
     * Filters on the UTC `starts_at` datetime.
     */
    private function scopedQuery(int $businessId, string $fromDt, string $toDt): Query
    {
        return (new Query())
            ->from(['a' => Appointment::tableName()])
            ->leftJoin(['s' => Service::tableName()], 's.id = a.service_id')
            ->where(['a.business_id' => $businessId])
            ->andWhere(['>=', 'a.starts_at', $fromDt])
            ->andWhere(['<=', 'a.starts_at', $toDt]);
    }

    /** Resolve [from,to] from query params, defaulting to the last 30 days (UTC). */
    private function range(): array
    {
        $utc = new DateTimeZone('UTC');
        $to = $this->parseDate((string) Yii::$app->request->get('to', ''));
        $from = $this->parseDate((string) Yii::$app->request->get('from', ''));

        if ($to === null) {
            $to = (new DateTimeImmutable('now', $utc))->format(self::DATE_FORMAT);
        }
        if ($from === null) {
            $from = (new DateTimeImmutable($to . ' 00:00:00', $utc))
                ->sub(new DateInterval('P29D'))
                ->format(self::DATE_FORMAT);
        }
        // Guard against an inverted window.
        if ($from > $to) {
            $from = $to;
        }
        return [$from, $to];
    }

    /** Validate a 'YYYY-MM-DD' string; return the normalized date or null. */
    private function parseDate(string $value): ?string
    {
        if ($value === '') {
            return null;
        }
        $dt = DateTimeImmutable::createFromFormat('!' . self::DATE_FORMAT, $value, new DateTimeZone('UTC'));
        if ($dt === false || $dt->format(self::DATE_FORMAT) !== $value) {
            return null;
        }
        return $value;
    }

    /** Inclusive list of 'YYYY-MM-DD' dates from $from to $to. */
    private function eachDate(string $from, string $to): array
    {
        $utc = new DateTimeZone('UTC');
        $start = new DateTimeImmutable($from . ' 00:00:00', $utc);
        $end = new DateTimeImmutable($to . ' 00:00:00', $utc);
        $period = new DatePeriod($start, new DateInterval('P1D'), $end->modify('+1 day'));
        $out = [];
        foreach ($period as $d) {
            $out[] = $d->format(self::DATE_FORMAT);
        }
        return $out;
    }

    private function dayStartTs(string $date): int
    {
        return (new DateTimeImmutable($date . ' 00:00:00', new DateTimeZone('UTC')))->getTimestamp();
    }

    private function dayEndTs(string $date): int
    {
        return (new DateTimeImmutable($date . ' 23:59:59', new DateTimeZone('UTC')))->getTimestamp();
    }
}
