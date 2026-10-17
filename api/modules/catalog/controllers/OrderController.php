<?php

namespace api\modules\catalog\controllers;

use api\modules\catalog\services\OrderService;
use common\models\Business;
use common\models\Order;
use common\rest\Controller;
use Yii;
use yii\web\BadRequestHttpException;
use yii\web\ConflictHttpException;
use yii\web\NotFoundHttpException;

/**
 * Catalog orders — public checkout (site / bot) and the admin order history.
 */
class OrderController extends Controller
{
    protected function authOptional(): array
    {
        return ['create'];
    }

    /**
     * POST v1/orders  (public)
     * { slug, items:[{service_id, qty}], customer:{name, phone}, note?, source?, init_data? }
     * Prices are taken from the menu server-side — never trusted from the client.
     * Honors Idempotency-Key (replay answers 200 with the same order).
     */
    public function actionCreate()
    {
        $idemKey = Yii::$app->request->getHeaders()->get('Idempotency-Key');
        $body = $this->body();
        [$order, $replayed] = (new OrderService())->create(
            is_array($body) ? $body : [],
            OrderService::MODE_PUBLIC,
            is_string($idemKey) && $idemKey !== '' ? $idemKey : null
        );
        if ($order->hasErrors()) {
            return $this->fail422($order);
        }
        return $replayed ? $order : $this->created($order);
    }

    /**
     * GET v1/orders  (admin, tenant-scoped) — order history, newest first.
     * Optional ?status=&limit=
     */
    public function actionIndex(): array
    {
        // tid=null tokens must not read every business's orders.
        Yii::$app->tenant->require();
        $req = Yii::$app->request;
        $q = Order::find()->with('items')->orderBy(['id' => SORT_DESC]);

        $status = (string) $req->get('status', '');
        if ($status !== '' && in_array($status, Order::STATUSES, true)) {
            $q->andWhere(['status' => $status]);
        }

        // Optional created_at window (unix seconds) — the weekly Jadval sends the
        // exact week it renders so a busy catalog isn't capped to the latest slice.
        $from = (int) $req->get('from', 0);
        $to = (int) $req->get('to', 0);
        if ($from > 0) {
            $q->andWhere(['>=', 'created_at', $from]);
        }
        if ($to > 0) {
            $q->andWhere(['<', 'created_at', $to]);
        }

        // A bounded window may legitimately hold a whole busy week (~300); the
        // unbounded "latest" call (kanban) stays capped to the recent slice.
        $ranged = $from > 0 || $to > 0;
        $limit = min(
            $ranged ? 2000 : 200,
            max(1, (int) $req->get('limit', $ranged ? 2000 : 100))
        );

        return $q->limit($limit)->all();
    }

    /**
     * PATCH v1/orders/<id>  (admin) — change order status.
     */
    public function actionUpdate(int $id)
    {
        Yii::$app->tenant->require();
        $this->requireRole(Business::ROLE_OWNER, Business::ROLE_ADMIN, Business::ROLE_STAFF);
        $order = Order::findOne($id); // tenant-scoped
        if ($order === null) {
            throw new NotFoundHttpException('Buyurtma topilmadi.');
        }
        $status = $this->body('status', '');
        if (!is_string($status) || !in_array($status, Order::STATUSES, true)) {
            throw new BadRequestHttpException('Noto\'g\'ri holat.');
        }
        // Apply on the locked row, and only if nobody (e.g. the consumer
        // cancelling) changed the status since it was read.
        $tx = Order::getDb()->beginTransaction();
        try {
            $fresh = Order::lockForUpdate((int) $order->id);
            if ($fresh === null || (string) $fresh->status !== (string) $order->status) {
                throw new ConflictHttpException('Buyurtma holati o\'zgargan. Sahifani yangilang.');
            }
            $fresh->status = $status;
            if (!$fresh->save()) {
                $tx->rollBack();
                return $this->fail422($fresh);
            }
            $tx->commit();
        } catch (\Throwable $e) {
            if ($tx->getIsActive()) {
                $tx->rollBack();
            }
            throw $e;
        }
        return $fresh;
    }
}
