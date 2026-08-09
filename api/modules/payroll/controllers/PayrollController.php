<?php

namespace api\modules\payroll\controllers;

use common\models\Appointment;
use common\models\Service;
use common\models\Staff;
use common\rest\Controller;
use Yii;
use yii\db\Query;

/**
 * Payroll: per active staff member, earnings computed from completed
 * appointments in a date range. Readable by any authed member of the tenant.
 *
 * earnings_tiyin = intval(revenue_tiyin * commission_percent / 100), where
 * revenue_tiyin is the SUM of the appointments' service price_tiyin.
 */
class PayrollController extends Controller
{
    public function actionIndex(): array
    {
        $business = Yii::$app->tenant->require();
        [$from, $to] = $this->range();

        $completed = Yii::$app->db->quoteValue(Appointment::STATUS_COMPLETED);

        $rows = (new Query())
            ->select([
                'staff_id' => 'st.id',
                'name' => 'st.name',
                'commission_percent' => 'st.commission_percent',
                'appointments' => 'COUNT(a.id)',
                'revenue_tiyin' => 'COALESCE(SUM(s.price_tiyin), 0)',
            ])
            ->from(['st' => Staff::tableName()])
            ->leftJoin(
                ['a' => Appointment::tableName()],
                "a.staff_id = st.id AND a.business_id = :biz"
                . " AND a.status = $completed"
                . " AND a.starts_at >= :from AND a.starts_at <= :to"
            )
            ->leftJoin(['s' => Service::tableName()], 's.id = a.service_id')
            ->where(['st.business_id' => $business, 'st.is_active' => 1])
            ->groupBy(['st.id', 'st.name', 'st.commission_percent'])
            ->orderBy(['st.name' => SORT_ASC])
            ->params([':biz' => $business, ':from' => $from, ':to' => $to])
            ->all();

        $staff = [];
        $totalRevenue = 0;
        $totalEarnings = 0;

        foreach ($rows as $row) {
            $commission = (int) $row['commission_percent'];
            $revenue = (int) $row['revenue_tiyin'];
            $earnings = intval($revenue * $commission / 100);

            $totalRevenue += $revenue;
            $totalEarnings += $earnings;

            $staff[] = [
                'staff_id' => (int) $row['staff_id'],
                'name' => $row['name'],
                'commission_percent' => $commission,
                'appointments' => (int) $row['appointments'],
                'revenue_tiyin' => $revenue,
                'earnings_tiyin' => $earnings,
            ];
        }

        return [
            'staff' => $staff,
            'totals' => [
                'revenue_tiyin' => $totalRevenue,
                'earnings_tiyin' => $totalEarnings,
            ],
        ];
    }

    /**
     * Resolve the ['from', 'to'] UTC datetime bounds from the query string.
     * Both params are 'YYYY-MM-DD'; defaults to the last 30 days.
     *
     * @return array{0:string,1:string}
     */
    private function range(): array
    {
        $req = Yii::$app->request;
        $fromDate = $this->asDate($req->get('from'));
        $toDate = $this->asDate($req->get('to'));

        if ($toDate === null) {
            $toDate = gmdate('Y-m-d');
        }
        if ($fromDate === null) {
            $fromDate = gmdate('Y-m-d', strtotime("$toDate -29 days"));
        }

        return [$fromDate . ' 00:00:00', $toDate . ' 23:59:59'];
    }

    /** Return the value only if it is a valid 'YYYY-MM-DD' date, else null. */
    private function asDate($value): ?string
    {
        if (is_string($value) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $value)) {
            return $value;
        }
        return null;
    }
}
