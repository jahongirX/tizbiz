<?php

namespace api\modules\finance\controllers;

use common\models\Appointment;
use common\models\Client;
use common\models\Service;
use common\models\Transaction;
use common\rest\Controller;
use Yii;
use yii\db\Query;

/**
 * Finance reporting: summary totals and the paginated transaction ledger.
 *
 * Both actions are tenant-scoped (transactions.business_id) and restricted to
 * business owners/admins. Money is in TIYIN. The date range filters on the
 * transaction's created_at, which is stored as a UTC unix timestamp; the
 * 'YYYY-MM-DD' from/to bounds are resolved to [from 00:00:00, to+1d 00:00:00)
 * in UTC. Default range is the last 30 days.
 */
class FinanceController extends Controller
{
    private const PAGE_SIZE = 20;

    /**
     * GET /v1/finance/summary?from=&to=
     *
     * income_tiyin  = SUM of paid deposit transactions
     * refunds_tiyin = SUM of refund transactions (status refunded)
     * net_tiyin     = income - refunds
     * count         = number of paid deposit transactions
     * by_provider   = paid deposits grouped by provider {provider,amount_tiyin,count}
     */
    public function actionSummary(): array
    {
        $this->requireRole('business_owner', 'business_admin');
        $businessId = Yii::$app->tenant->require();

        [$fromTs, $toTs, $from, $to] = $this->range();

        // Quote the enum literals rather than binding named params so the same
        // condition string can be reused across several independent queries
        // without dangling/duplicated bindings. Values are controlled constants.
        $deposit = Yii::$app->db->quoteValue(Transaction::TYPE_DEPOSIT);
        $refund = Yii::$app->db->quoteValue(Transaction::TYPE_REFUND);
        $paid = Yii::$app->db->quoteValue(Transaction::STATUS_PAID);
        $refunded = Yii::$app->db->quoteValue(Transaction::STATUS_REFUNDED);

        $paidDeposit = "t.type = $deposit AND t.status = $paid";

        $base = static fn (): Query => (new Query())
            ->from(['t' => Transaction::tableName()])
            ->where(['t.business_id' => $businessId])
            ->andWhere(['>=', 't.created_at', $fromTs])
            ->andWhere(['<', 't.created_at', $toTs]);

        $income = $base()
            ->andWhere($paidDeposit)
            ->select([
                'amount' => 'COALESCE(SUM(t.amount_tiyin), 0)',
                'cnt' => 'COUNT(*)',
            ])
            ->one();

        $refunds = $base()
            ->andWhere("t.type = $refund AND t.status = $refunded")
            ->select(['amount' => 'COALESCE(SUM(t.amount_tiyin), 0)'])
            ->scalar();

        $byProviderRows = $base()
            ->andWhere($paidDeposit)
            ->select([
                'provider' => 't.provider',
                'amount_tiyin' => 'COALESCE(SUM(t.amount_tiyin), 0)',
                'count' => 'COUNT(*)',
            ])
            ->groupBy('t.provider')
            ->orderBy(['amount_tiyin' => SORT_DESC])
            ->all();

        $incomeTiyin = (int) ($income['amount'] ?? 0);
        $refundsTiyin = (int) $refunds;

        $byProvider = array_map(static fn ($r) => [
            'provider' => $r['provider'],
            'amount_tiyin' => (int) $r['amount_tiyin'],
            'count' => (int) $r['count'],
        ], $byProviderRows);

        return [
            'from' => $from,
            'to' => $to,
            'income_tiyin' => $incomeTiyin,
            'refunds_tiyin' => $refundsTiyin,
            'net_tiyin' => $incomeTiyin - $refundsTiyin,
            'count' => (int) ($income['cnt'] ?? 0),
            'by_provider' => $byProvider,
        ];
    }

    /**
     * GET /v1/finance/transactions?from=&to=&provider=&type=&status=&page=&per_page=
     *
     * Paginated ledger. Each row joins the linked appointment -> client & service
     * for display names (LEFT JOINs; a transaction may have no appointment).
     */
    public function actionTransactions(): array
    {
        $this->requireRole('business_owner', 'business_admin');
        $businessId = Yii::$app->tenant->require();

        [$fromTs, $toTs] = $this->range();

        $provider = trim((string) Yii::$app->request->get('provider', ''));
        $type = trim((string) Yii::$app->request->get('type', ''));
        $status = trim((string) Yii::$app->request->get('status', ''));
        $page = max(1, (int) Yii::$app->request->get('page', 1));
        $perPage = min(100, max(1, (int) Yii::$app->request->get('per_page', self::PAGE_SIZE)));

        $base = (new Query())
            ->from(['t' => Transaction::tableName()])
            ->leftJoin(['a' => Appointment::tableName()], 'a.id = t.appointment_id')
            ->leftJoin(['c' => Client::tableName()], 'c.id = a.client_id')
            ->leftJoin(['s' => Service::tableName()], 's.id = a.service_id')
            ->where(['t.business_id' => $businessId])
            ->andWhere(['>=', 't.created_at', $fromTs])
            ->andWhere(['<', 't.created_at', $toTs]);

        if ($provider !== '') {
            $base->andWhere(['t.provider' => $provider]);
        }
        if ($type !== '') {
            $base->andWhere(['t.type' => $type]);
        }
        if ($status !== '') {
            $base->andWhere(['t.status' => $status]);
        }

        $total = (int) (clone $base)->count('t.id');

        $rows = (clone $base)
            ->select([
                'id' => 't.id',
                'provider' => 't.provider',
                'type' => 't.type',
                'status' => 't.status',
                'amount_tiyin' => 't.amount_tiyin',
                'created_at' => 't.created_at',
                'appointment_id' => 't.appointment_id',
                'client_name' => 'c.name',
                'service_name' => 's.name',
            ])
            ->orderBy(['t.created_at' => SORT_DESC, 't.id' => SORT_DESC])
            ->offset(($page - 1) * $perPage)
            ->limit($perPage)
            ->all();

        $data = array_map(static fn ($r) => [
            'id' => (int) $r['id'],
            'provider' => $r['provider'],
            'type' => $r['type'],
            'status' => $r['status'],
            'amount_tiyin' => (int) $r['amount_tiyin'],
            'created_at' => (int) $r['created_at'],
            'appointment_id' => $r['appointment_id'] !== null ? (int) $r['appointment_id'] : null,
            'client_name' => $r['client_name'],
            'service_name' => $r['service_name'],
        ], $rows);

        return [
            'data' => $data,
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'pages' => (int) ceil($total / max(1, $perPage)),
            ],
        ];
    }

    /**
     * Resolve the from/to query params into a [startTs, endTsExclusive, from, to]
     * UTC unix window. Defaults to the last 30 days. `to` is inclusive of the whole
     * day (bound is the start of the following day). Invalid input falls back to the
     * default bound.
     *
     * @return array{0:int,1:int,2:string,3:string}
     */
    private function range(): array
    {
        $toParam = (string) Yii::$app->request->get('to', '');
        $fromParam = (string) Yii::$app->request->get('from', '');

        $to = $this->parseDate($toParam) ?? gmdate('Y-m-d');
        $from = $this->parseDate($fromParam) ?? gmdate('Y-m-d', strtotime($to . ' UTC') - 29 * 86400);

        $fromTs = (int) strtotime($from . ' 00:00:00 UTC');
        // Inclusive `to`: bound at the start of the next day.
        $toTs = (int) strtotime($to . ' 00:00:00 UTC') + 86400;

        return [$fromTs, $toTs, $from, $to];
    }

    /** Validate a 'YYYY-MM-DD' string; return the normalized date or null. */
    private function parseDate(string $value): ?string
    {
        $value = trim($value);
        if ($value === '') {
            return null;
        }
        $dt = \DateTime::createFromFormat('!Y-m-d', $value, new \DateTimeZone('UTC'));
        if ($dt === false || $dt->format('Y-m-d') !== $value) {
            return null;
        }
        return $value;
    }
}
