<?php

namespace api\modules\consumer\controllers;

use api\modules\catalog\services\OrderService;
use api\modules\consumer\components\ConsumerController;
use api\modules\consumer\components\ConsumerItems;
use common\models\Order;
use Yii;
use yii\web\BadRequestHttpException;
use yii\web\ConflictHttpException;
use yii\web\NotFoundHttpException;

/**
 * The consumer's own catalog orders.
 *
 * GET  /v1/consumer/orders?scope=active|past&page=&per_page=
 * GET  /v1/consumer/orders/<id>
 * POST /v1/consumer/orders              (Idempotency-Key) {slug, items, note?, name?}
 * POST /v1/consumer/orders/<id>/cancel  only while status is "new"
 */
class OrderController extends ConsumerController
{
    private const ACTIVE = [Order::STATUS_NEW, Order::STATUS_CONFIRMED, Order::STATUS_PREPARING, Order::STATUS_READY];
    private const PAST = [Order::STATUS_DELIVERED, Order::STATUS_CANCELLED];
    private const WITH = ['business', 'items'];

    public function actionIndex(): array
    {
        $consumer = $this->consumer();
        $scope = Yii::$app->request->get('scope', 'active');
        if ($scope === 'active') {
            $statuses = self::ACTIVE;
        } elseif ($scope === 'past') {
            $statuses = self::PAST;
        } else {
            throw new BadRequestHttpException('scope active yoki past bo\'lishi kerak.');
        }

        $query = Order::find()
            ->where(['consumer_id' => (int) $consumer->id, 'status' => $statuses])
            ->with(self::WITH)
            ->orderBy(['id' => SORT_DESC]);

        return $this->paginate($query, [ConsumerItems::class, 'orders']);
    }

    public function actionView(int $id): array
    {
        return ConsumerItems::order($this->findMine($id));
    }

    public function actionCreate()
    {
        $consumer = $this->consumer();
        $body = $this->body();
        $body = is_array($body) ? $body : [];
        // Contact details always come from the profile.
        unset($body['customer'], $body['source'], $body['init_data']);

        $idemKey = Yii::$app->request->getHeaders()->get('Idempotency-Key');
        [$order, $replayed] = (new OrderService())->create(
            $body,
            OrderService::MODE_CONSUMER,
            is_string($idemKey) && $idemKey !== '' ? $idemKey : null,
            $consumer
        );
        if ($order->hasErrors()) {
            return $this->fail422($order);
        }

        $item = ConsumerItems::order($this->findMine((int) $order->id));
        return $replayed ? $item : $this->created($item);
    }

    public function actionCancel(int $id): array
    {
        $order = $this->findMine($id);
        // One conditional UPDATE: a kitchen transition made since the read wins.
        $n = Order::updateAll(
            ['status' => Order::STATUS_CANCELLED, 'updated_at' => time()],
            ['id' => (int) $order->id, 'consumer_id' => (int) $this->consumer()->id, 'status' => Order::STATUS_NEW]
        );
        if ($n !== 1) {
            throw new ConflictHttpException('Buyurtmani faqat yangi holatda bekor qilish mumkin.');
        }
        return ConsumerItems::order($this->findMine($id));
    }

    private function findMine(int $id): Order
    {
        $order = Order::find()
            ->where(['id' => $id, 'consumer_id' => (int) $this->consumer()->id])
            ->with(self::WITH)
            ->one();
        if ($order === null) {
            throw new NotFoundHttpException('Buyurtma topilmadi.');
        }
        return $order;
    }
}
