<?php

namespace api\modules\crm\controllers;

use common\models\Appointment;
use common\models\Client;
use common\models\ClientCategory;
use common\models\ClientCategoryAssignment;
use common\models\LoyaltyAccount;
use common\models\Service;
use common\rest\Controller;
use Yii;
use yii\db\Expression;
use yii\db\Query;
use yii\web\NotFoundHttpException;

/**
 * CRM client CRUD.
 *
 * Reads (index/view) are available to any authenticated tenant user; writes
 * (create/update/delete) require business_owner or business_admin. All rows are
 * tenant-scoped automatically by {@see Client} via the active business JWT.
 */
class ClientController extends Controller
{
    private const PAGE_SIZE = 20;

    /**
     * GET /v1/clients?search=&segment=&page=&per_page=
     *
     * Tenant-scoped client base with per-client aggregates (visits, total spent,
     * last visit) and segment filters — like the YClients client base.
     *   segment: new (<=1 visit) | repeat (>=2 visits) | lost (no visit in 60 days)
     *   category: only clients carrying that client-category id
     * search matches name OR phone OR email (LIKE).
     */
    public function actionIndex(): array
    {
        $businessId = Yii::$app->tenant->require();

        $search = trim((string) Yii::$app->request->get('search', ''));
        $segment = (string) Yii::$app->request->get('segment', '');
        $categoryId = (int) Yii::$app->request->get('category', 0);
        $page = max(1, (int) Yii::$app->request->get('page', 1));
        $perPage = min(100, max(1, (int) Yii::$app->request->get('per_page', self::PAGE_SIZE)));

        // Quote the status literal instead of a named param so the COUNT subquery
        // (which references none of the aggregate expressions) carries no dangling
        // bound variable. The value is a controlled enum constant, not user input.
        $done = Yii::$app->db->quoteValue(Appointment::STATUS_COMPLETED);
        $lostCutoff = gmdate('Y-m-d H:i:s', time() - 60 * 86400);

        $noShow = Yii::$app->db->quoteValue(Appointment::STATUS_NO_SHOW);

        $visitsExpr = "COUNT(DISTINCT CASE WHEN a.status = $done THEN a.id END)";
        // Repeat no-shows are what a master wants to see before giving a slot away.
        $noShowExpr = "COUNT(DISTINCT CASE WHEN a.status = $noShow THEN a.id END)";
        $spentExpr = "COALESCE(SUM(CASE WHEN a.status = $done THEN s.price_tiyin ELSE 0 END), 0)";
        $lastExpr = "MAX(CASE WHEN a.status = $done THEN a.starts_at END)";

        $base = (new Query())
            ->from(['c' => Client::tableName()])
            ->leftJoin(['a' => Appointment::tableName()], 'a.client_id = c.id')
            ->leftJoin(['s' => Service::tableName()], 's.id = a.service_id')
            ->where(['c.business_id' => $businessId])
            ->groupBy('c.id');

        if ($categoryId > 0) {
            $base->innerJoin(
                ['cca' => \common\models\ClientCategoryAssignment::tableName()],
                'cca.client_id = c.id AND cca.category_id = :cat',
                [':cat' => $categoryId]
            );
        }

        if ($search !== '') {
            $base->andWhere(['or',
                ['like', 'c.name', $search],
                ['like', 'c.phone', $search],
                ['like', 'c.email', $search],
            ]);
        }

        if ($segment === 'new') {
            $base->having($visitsExpr . ' <= 1');
        } elseif ($segment === 'repeat') {
            $base->having($visitsExpr . ' >= 2');
        } elseif ($segment === 'lost') {
            $base->having($lastExpr . ' IS NOT NULL AND ' . $lastExpr . ' < :cutoff')
                ->addParams([':cutoff' => $lostCutoff]);
        }

        $total = (int) (new Query())->from(['t' => (clone $base)->select('c.id')])->count();

        $rows = (clone $base)
            ->select([
                'id' => 'c.id',
                'name' => 'c.name',
                'phone' => 'c.phone',
                'email' => 'c.email',
                'birthday' => 'c.birthday',
                'tags' => 'c.tags',
                'created_at' => 'c.created_at',
                'visits' => new Expression($visitsExpr),
                'no_shows' => new Expression($noShowExpr),
                'spent_tiyin' => new Expression($spentExpr),
                'last_visit' => new Expression($lastExpr),
            ])
            ->orderBy(['c.id' => SORT_DESC])
            ->offset(($page - 1) * $perPage)
            ->limit($perPage)
            ->all();

        $categoriesByClient = $this->categoriesForClients(array_map(
            static fn ($r) => (int) $r['id'],
            $rows
        ));

        foreach ($rows as &$r) {
            $r['visits'] = (int) $r['visits'];
            $r['no_shows'] = (int) $r['no_shows'];
            $r['spent_tiyin'] = (int) $r['spent_tiyin'];
            $r['tags'] = is_string($r['tags']) ? (json_decode($r['tags'], true) ?: []) : ($r['tags'] ?? []);
            $r['categories'] = $categoriesByClient[(int) $r['id']] ?? [];
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
     * GET /v1/clients/<id>
     * Client + recent appointment history + loyalty summary (if available).
     */
    public function actionView(int $id): array
    {
        $client = $this->findClient($id);

        $history = Appointment::find()
            ->andWhere(['client_id' => $client->id])
            ->orderBy(['starts_at' => SORT_DESC])
            ->limit(20)
            ->all();

        $result = [
            'client' => $client,
            'categories' => $this->categoriesForClients([$client->id])[$client->id] ?? [],
            'history' => $history,
        ];

        // Loyalty is an optional cross-module dependency; guard softly.
        if (class_exists(LoyaltyAccount::class)) {
            try {
                $account = LoyaltyAccount::find()
                    ->andWhere(['client_id' => $client->id])
                    ->one();
                if ($account !== null) {
                    $result['loyalty'] = [
                        'points' => (int) $account->points,
                        'cashback_tiyin' => (int) $account->cashback_tiyin,
                    ];
                }
            } catch (\Throwable $e) {
                // Loyalty module not fully wired yet; omit the summary.
            }
        }

        return $result;
    }

    /**
     * POST /v1/clients
     */
    public function actionCreate()
    {
        $this->requireRole('business_owner', 'business_admin');

        $client = new Client();
        $client->load($this->body(), '');
        $client->business_id = Yii::$app->tenant->require();

        if (!$client->save()) {
            return $this->fail422($client);
        }

        return $this->created($client);
    }

    /**
     * PATCH /v1/clients/<id>
     */
    public function actionUpdate(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $client = $this->findClient($id);
        $client->load($this->body(), '');
        // business_id is immutable / tenant-owned; never accept it from the body.
        $client->business_id = Yii::$app->tenant->require();

        if (!$client->save()) {
            return $this->fail422($client);
        }

        return $client;
    }

    /**
     * DELETE /v1/clients/<id>
     */
    public function actionDelete(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $client = $this->findClient($id);
        $client->delete();

        Yii::$app->response->statusCode = 204;
        // Return null so the Envelope early-returns and emits no body for 204.
        return null;
    }

    /**
     * PUT /v1/clients/<id>/categories {category_ids:[..]}
     *
     * Replace the client's whole category set. Every id must belong to the
     * active tenant; unknown/cross-tenant ids are rejected. Returns the client's
     * current categories.
     */
    public function actionSetCategories(int $id): array
    {
        $this->requireRole('business_owner', 'business_admin');

        $client = $this->findClient($id);

        $raw = $this->body('category_ids', []);
        if (!is_array($raw)) {
            $raw = [];
        }
        $requested = array_values(array_unique(array_map('intval', $raw)));

        // Only categories owned by the active tenant are valid targets.
        $valid = [];
        if ($requested !== []) {
            $valid = ClientCategory::find()
                ->select('id')
                ->andWhere(['id' => $requested])
                ->column();
            $valid = array_map('intval', $valid);
        }

        $unknown = array_diff($requested, $valid);
        if ($unknown !== []) {
            Yii::$app->response->statusCode = 422;
            return [[
                'field' => 'category_ids',
                'message' => 'Kategoriya topilmadi: ' . implode(', ', $unknown),
            ]];
        }

        $tx = Client::getDb()->beginTransaction();
        try {
            ClientCategoryAssignment::deleteAll(['client_id' => $client->id]);
            foreach ($valid as $categoryId) {
                $assignment = new ClientCategoryAssignment();
                $assignment->client_id = $client->id;
                $assignment->category_id = $categoryId;
                if (!$assignment->save()) {
                    $tx->rollBack();
                    return $this->fail422($assignment);
                }
            }
            $tx->commit();
        } catch (\Throwable $e) {
            $tx->rollBack();
            throw $e;
        }

        return ['data' => $this->categoriesForClients([$client->id])[$client->id] ?? []];
    }

    /**
     * Batch-load categories for a set of client ids in a single query.
     * Returns [clientId => [{id,name,color}, ...]], ordered by sort then id.
     */
    private function categoriesForClients(array $clientIds): array
    {
        $clientIds = array_values(array_unique(array_map('intval', $clientIds)));
        if ($clientIds === []) {
            return [];
        }

        $rows = (new Query())
            ->select([
                'client_id' => 'a.client_id',
                'id' => 'cc.id',
                'name' => 'cc.name',
                'color' => 'cc.color',
            ])
            ->from(['a' => ClientCategoryAssignment::tableName()])
            ->innerJoin(['cc' => ClientCategory::tableName()], 'cc.id = a.category_id')
            ->where(['a.client_id' => $clientIds])
            ->orderBy(['cc.sort' => SORT_ASC, 'cc.id' => SORT_ASC])
            ->all();

        $byClient = [];
        foreach ($rows as $row) {
            $byClient[(int) $row['client_id']][] = [
                'id' => (int) $row['id'],
                'name' => $row['name'],
                'color' => $row['color'],
            ];
        }

        return $byClient;
    }

    /**
     * Load a tenant-scoped client or 404. The base AR find() already restricts
     * to the active business, so cross-tenant ids naturally miss.
     */
    private function findClient(int $id): Client
    {
        // Assert an active tenant so a JWT with tid=null gets 403, not an
        // unscoped cross-tenant read.
        Yii::$app->tenant->require();

        $client = Client::findOne(['id' => $id]);
        if ($client === null) {
            throw new NotFoundHttpException('Mijoz topilmadi.');
        }
        return $client;
    }
}
