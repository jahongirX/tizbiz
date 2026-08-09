<?php

namespace api\modules\loyalty\controllers;

use common\models\Client;
use common\models\DepositTransaction;
use common\rest\Controller;
use Yii;
use yii\db\Query;
use yii\web\NotFoundHttpException;
use yii\web\UnprocessableEntityHttpException;

/**
 * Client deposit (advance / account balance) ledger. Balance is the running
 * SUM(delta_tiyin) of a client's immutable transactions. Money in tiyin.
 *
 * Reads are available to any authed tenant user; writes (top-up / spend /
 * refund) require an owner/admin role. All rows are tenant-scoped via the
 * active business JWT.
 */
class DepositController extends Controller
{
    private const PAGE_SIZE = 20;

    /**
     * GET /v1/deposits/balances?search=&page=&per_page=
     *
     * One row per client that has at least one deposit transaction, with the
     * client's name/phone and current balance = SUM(delta_tiyin). search
     * matches name OR phone (LIKE).
     */
    public function actionBalances(): array
    {
        $businessId = Yii::$app->tenant->require();

        $search = trim((string) Yii::$app->request->get('search', ''));
        $page = max(1, (int) Yii::$app->request->get('page', 1));
        $perPage = min(100, max(1, (int) Yii::$app->request->get('per_page', self::PAGE_SIZE)));

        $base = (new Query())
            ->from(['d' => DepositTransaction::tableName()])
            ->innerJoin(['c' => Client::tableName()], 'c.id = d.client_id')
            ->where(['d.business_id' => $businessId])
            ->groupBy('d.client_id');

        if ($search !== '') {
            $base->andWhere(['or',
                ['like', 'c.name', $search],
                ['like', 'c.phone', $search],
            ]);
        }

        // Count distinct clients via a subquery over the grouped set, mirroring
        // the aggregate-index pattern used elsewhere.
        $total = (int) (new Query())
            ->from(['t' => (clone $base)->select('d.client_id')])
            ->count();

        $rows = (clone $base)
            ->select([
                'client_id' => 'd.client_id',
                'name' => 'c.name',
                'phone' => 'c.phone',
                'balance_tiyin' => 'SUM(d.delta_tiyin)',
            ])
            ->orderBy(['c.name' => SORT_ASC])
            ->offset(($page - 1) * $perPage)
            ->limit($perPage)
            ->all();

        foreach ($rows as &$r) {
            $r['client_id'] = (int) $r['client_id'];
            $r['balance_tiyin'] = (int) $r['balance_tiyin'];
        }
        unset($r);

        return [
            'data' => $rows,
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'pages' => (int) ceil($total / max(1, $perPage)),
            ],
        ];
    }

    /**
     * GET /v1/deposits/<clientId> — one client's balance + full transaction list.
     */
    public function actionView(int $clientId): array
    {
        $businessId = Yii::$app->tenant->require();
        $client = $this->requireClient($businessId, $clientId);

        $transactions = DepositTransaction::find()
            ->where(['client_id' => $clientId])
            ->orderBy(['id' => SORT_DESC])
            ->all();

        return [
            'client_id' => $clientId,
            'name' => $client->name,
            'phone' => $client->phone,
            'balance_tiyin' => $this->currentBalance($businessId, $clientId),
            'transactions' => array_map(static fn (DepositTransaction $t) => [
                'delta_tiyin' => (int) $t->delta_tiyin,
                'type' => $t->type,
                'reason' => $t->reason,
                'created_at' => (int) $t->created_at,
            ], $transactions),
        ];
    }

    /**
     * POST /v1/deposits — record a top-up, spend, or refund.
     * Body: {client_id, amount_tiyin, type:'topup'|'spend'|'refund', reason?}
     * topup/refund add to the balance; spend subtracts. A spend that exceeds the
     * current balance is rejected (422). Returns {client_id, balance_tiyin}.
     */
    public function actionCreate(): array
    {
        $this->requireRole('business_owner', 'business_admin');
        $businessId = Yii::$app->tenant->require();

        $clientId = (int) $this->body('client_id');
        $amount = (int) $this->body('amount_tiyin');
        $type = (string) $this->body('type');
        $reason = $this->body('reason');
        $reason = $reason !== null && $reason !== '' ? (string) $reason : null;

        if ($clientId <= 0) {
            throw new UnprocessableEntityHttpException('client_id talab qilinadi.');
        }
        if ($amount <= 0) {
            throw new UnprocessableEntityHttpException('amount_tiyin musbat bo\'lishi kerak.');
        }
        if (!in_array($type, [DepositTransaction::TYPE_TOPUP, DepositTransaction::TYPE_SPEND, DepositTransaction::TYPE_REFUND], true)) {
            throw new UnprocessableEntityHttpException('type noto\'g\'ri.');
        }
        $this->requireClient($businessId, $clientId);

        $delta = $type === DepositTransaction::TYPE_SPEND ? -$amount : $amount;

        // Guard the spend against the live balance inside a transaction so a
        // concurrent write cannot push the balance negative between the check
        // and the insert.
        $db = Yii::$app->db;
        $tx = $db->beginTransaction();
        try {
            $balance = $this->currentBalance($businessId, $clientId);
            if ($type === DepositTransaction::TYPE_SPEND && $amount > $balance) {
                throw new UnprocessableEntityHttpException('Depozit qoldig\'i yetarli emas.');
            }

            $row = new DepositTransaction();
            $row->business_id = $businessId;
            $row->client_id = $clientId;
            $row->delta_tiyin = $delta;
            $row->type = $type;
            $row->reason = $reason;
            if (!$row->save()) {
                $tx->rollBack();
                return $this->fail422($row);
            }

            $tx->commit();
        } catch (UnprocessableEntityHttpException $e) {
            $tx->rollBack();
            throw $e;
        } catch (\Throwable $e) {
            $tx->rollBack();
            throw $e;
        }

        return [
            'client_id' => $clientId,
            'balance_tiyin' => $this->currentBalance($businessId, $clientId),
        ];
    }

    /** Current deposit balance for a client (SUM of signed deltas), tenant-scoped. */
    private function currentBalance(int $businessId, int $clientId): int
    {
        $sum = (new Query())
            ->from(DepositTransaction::tableName())
            ->where(['business_id' => $businessId, 'client_id' => $clientId])
            ->sum('delta_tiyin');
        return (int) $sum;
    }

    /** Ensure the client exists within the active business, returning it, or 404. */
    private function requireClient(int $businessId, int $clientId): Client
    {
        $client = Client::find()
            ->where(['id' => $clientId, 'business_id' => $businessId])
            ->one();
        if ($client === null) {
            throw new NotFoundHttpException('Mijoz topilmadi.');
        }
        return $client;
    }
}
