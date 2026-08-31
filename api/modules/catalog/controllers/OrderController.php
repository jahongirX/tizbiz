<?php

namespace api\modules\catalog\controllers;

use common\helpers\Phone;
use common\helpers\TelegramWebApp;
use common\models\Business;
use common\models\Order;
use common\models\OrderItem;
use common\models\Service;
use common\rest\Controller;
use Yii;
use yii\web\BadRequestHttpException;
use yii\web\NotFoundHttpException;
use yii\web\ServerErrorHttpException;

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
     * { slug, items:[{service_id, qty}], customer:{name, phone}, note?, source? }
     * Prices are taken from the menu server-side — never trusted from the client.
     */
    public function actionCreate()
    {
        $slug = (string) $this->body('slug', '');
        $business = Business::find()
            ->where(['slug' => $slug, 'status' => Business::STATUS_ACTIVE])
            ->one();
        if ($business === null) {
            throw new NotFoundHttpException('Biznes topilmadi.');
        }

        // Collapse the cart to service_id => qty (ignoring junk / non-positive).
        $wanted = [];
        foreach ((array) $this->body('items', []) as $it) {
            $sid = (int) ($it['service_id'] ?? 0);
            $qty = (int) ($it['qty'] ?? 1);
            if ($sid > 0 && $qty > 0) {
                $wanted[$sid] = ($wanted[$sid] ?? 0) + $qty;
            }
        }
        if ($wanted === []) {
            throw new BadRequestHttpException('Savat bo\'sh.');
        }

        $services = Service::find()
            ->where(['business_id' => $business->id, 'is_active' => 1, 'id' => array_keys($wanted)])
            ->indexBy('id')
            ->all();
        if ($services === []) {
            throw new BadRequestHttpException('Mahsulotlar topilmadi.');
        }

        $customer = (array) $this->body('customer', []);
        $note = trim((string) ($this->body('note', '') ?? ''));
        $source = (string) $this->body('source', 'site');

        // If placed from the Telegram Mini App, verify the signed initData and
        // tie the order to that Telegram user (for their order history).
        $tgUserId = null;
        $initData = (string) $this->body('init_data', '');
        if ($initData !== '' && ($business->telegram_bot_token ?? '') !== '') {
            $verified = TelegramWebApp::verify($initData, (string) $business->telegram_bot_token);
            if ($verified !== null) {
                $tgUserId = (int) $verified['user']['id'];
                $source = 'bot';
            }
        }

        $tx = Yii::$app->db->beginTransaction();
        try {
            $order = new Order();
            $order->business_id = (int) $business->id; // public: no tenant, set explicitly
            $order->customer_name = isset($customer['name']) ? (string) $customer['name'] : null;
            $order->customer_phone = isset($customer['phone'])
                ? (Phone::normalize((string) $customer['phone']) ?? (string) $customer['phone'])
                : null;
            $order->note = $note !== '' ? $note : null;
            $order->source = in_array($source, Order::SOURCES, true) ? $source : 'site';
            // Only touch tg_user_id when actually linked, so a plain web order
            // never references the column (keeps working before the migration).
            if ($tgUserId !== null) {
                $order->tg_user_id = $tgUserId;
            }
            $order->status = Order::STATUS_NEW;
            $order->total_tiyin = 0;
            if (!$order->save()) {
                $tx->rollBack();
                return $this->fail422($order);
            }

            $total = 0;
            foreach ($wanted as $sid => $qty) {
                $svc = $services[$sid] ?? null;
                if ($svc === null) {
                    continue; // requested item not on this menu — skip
                }
                $line = new OrderItem();
                $line->order_id = (int) $order->id;
                $line->business_id = (int) $business->id;
                $line->service_id = (int) $sid;
                $line->name = $svc->name;
                $line->price_tiyin = (int) $svc->price_tiyin;
                $line->qty = (int) $qty;
                if (!$line->save()) {
                    $tx->rollBack();
                    return $this->fail422($line);
                }
                $total += (int) $svc->price_tiyin * (int) $qty;
            }

            $order->total_tiyin = $total;
            $order->save(false, ['total_tiyin']);
            $tx->commit();
        } catch (\Throwable $e) {
            $tx->rollBack();
            throw new ServerErrorHttpException('Buyurtma yaratishda xatolik.');
        }

        $order->refresh();
        return $this->created($order);
    }

    /**
     * GET v1/orders  (admin, tenant-scoped) — order history, newest first.
     * Optional ?status=&limit=
     */
    public function actionIndex(): array
    {
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
        $this->requireRole(Business::ROLE_OWNER, Business::ROLE_ADMIN, Business::ROLE_STAFF);
        $order = Order::findOne($id); // tenant-scoped
        if ($order === null) {
            throw new NotFoundHttpException('Buyurtma topilmadi.');
        }
        $status = (string) $this->body('status', '');
        if (!in_array($status, Order::STATUSES, true)) {
            throw new BadRequestHttpException('Noto\'g\'ri holat.');
        }
        $order->status = $status;
        if (!$order->save()) {
            return $this->fail422($order);
        }
        return $order;
    }
}
