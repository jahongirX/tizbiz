<?php

namespace api\modules\catalog\services;

use api\modules\booking\services\BookingService;
use common\helpers\DbLock;
use common\helpers\Phone;
use common\helpers\TelegramWebApp;
use common\models\Business;
use common\models\ConsumerUser;
use common\models\Order;
use common\models\OrderItem;
use common\models\Service;
use Yii;
use yii\web\BadRequestHttpException;
use yii\web\ConflictHttpException;
use yii\web\ForbiddenHttpException;
use yii\web\NotFoundHttpException;
use yii\web\ServerErrorHttpException;

/**
 * Catalog order creation shared by POST /v1/orders (public site / Telegram
 * Mini App) and POST /v1/consumer/orders (Bizcat app).
 *
 * Prices are always taken from the menu server-side. The CRM Client is upserted
 * by normalized phone and linked via orders.client_id. Idempotency-Key is
 * honored for 24 h in both modes; same-key requests are serialized by a named
 * DB lock (GET_LOCK) so concurrent retries replay instead of duplicating.
 */
final class OrderService
{
    public const MODE_PUBLIC = 'public';
    public const MODE_CONSUMER = 'consumer';

    private const IDEM_TTL = 86400;

    /**
     * Public body:   {slug, items:[{service_id, qty}], customer:{name, phone}, note?, source?, init_data?}
     * Consumer body: {slug, items:[{service_id, qty}], note?, name?}
     *
     * @return array{0: Order, 1: bool} [order, replayed]. When $order->hasErrors()
     *         the caller returns fail422($order).
     * @throws NotFoundHttpException|BadRequestHttpException|ForbiddenHttpException|ServerErrorHttpException
     */
    public function create(array $body, string $mode, ?string $idempotencyKey, ?ConsumerUser $consumer = null): array
    {
        if (!in_array($mode, [self::MODE_PUBLIC, self::MODE_CONSUMER], true)) {
            throw new \InvalidArgumentException('Unknown order mode: ' . $mode);
        }
        if ($mode === self::MODE_CONSUMER && $consumer === null) {
            throw new \InvalidArgumentException('Consumer mode requires a consumer.');
        }

        $slug = is_scalar($body['slug'] ?? null) ? (string) $body['slug'] : '';
        $business = Business::find()
            ->where(['slug' => $slug, 'status' => Business::STATUS_ACTIVE])
            ->one();
        if ($business === null) {
            throw new NotFoundHttpException('Biznes topilmadi.');
        }
        $businessId = (int) $business->id;

        $cacheKey = null;
        if ($idempotencyKey !== null && $idempotencyKey !== '') {
            $cacheKey = $mode === self::MODE_CONSUMER
                ? 'order:idem:c' . (int) $consumer->id . ':' . $idempotencyKey
                : 'order:idem:' . $businessId . ':' . $idempotencyKey;
        }
        $replayBusiness = $mode === self::MODE_CONSUMER ? null : $businessId;
        $replayConsumer = $mode === self::MODE_CONSUMER ? (int) $consumer->id : null;
        $replay = $this->replay($cacheKey, $replayBusiness, $replayConsumer);
        if ($replay !== null) {
            return [$replay, true];
        }
        if ($cacheKey === null) {
            return $this->createLocked($body, $mode, $consumer, $business, null);
        }

        // Same-key requests run one at a time (named DB lock: FileCache add() is
        // not atomic). A request queued on the lock replays the winner's order.
        $lockKey = 'order-idem:' . $cacheKey;
        if (!DbLock::acquire($lockKey, 10)) {
            throw new ConflictHttpException('So\'rov hali bajarilmoqda. Birozdan keyin qayta urinib ko\'ring.');
        }
        try {
            $replay = $this->replay($cacheKey, $replayBusiness, $replayConsumer);
            if ($replay !== null) {
                return [$replay, true];
            }
            return $this->createLocked($body, $mode, $consumer, $business, $cacheKey);
        } finally {
            DbLock::release($lockKey);
        }
    }

    /**
     * The create proper (called with the idempotency lock held when a key is given).
     *
     * @return array{0: Order, 1: bool}
     */
    private function createLocked(array $body, string $mode, ?ConsumerUser $consumer, Business $business, ?string $cacheKey): array
    {
        $businessId = (int) $business->id;

        if ($mode === self::MODE_CONSUMER && !$business->online_booking_enabled) {
            throw new ForbiddenHttpException('Bu biznes hozir onlayn buyurtma qabul qilmaydi.');
        }

        // Collapse the cart to service_id => qty (ignoring junk / non-positive).
        $wanted = [];
        $items = $body['items'] ?? [];
        foreach (is_array($items) ? $items : [] as $it) {
            if (!is_array($it)) {
                continue;
            }
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
            ->where(['business_id' => $businessId, 'is_active' => 1, 'id' => array_keys($wanted)])
            ->indexBy('id')
            ->all();
        if ($services === []) {
            throw new BadRequestHttpException('Mahsulotlar topilmadi.');
        }

        $note = is_scalar($body['note'] ?? null) ? trim((string) $body['note']) : '';
        $tgUserId = null;

        if ($mode === self::MODE_CONSUMER) {
            $givenName = isset($body['name']) && is_string($body['name']) && trim($body['name']) !== ''
                ? trim($body['name'])
                : null;
            $customerName = $givenName ?? ($consumer->name ?: (string) $consumer->phone);
            $customerPhone = (string) $consumer->phone;
            $source = 'app';
            $clientId = (new BookingService())->upsertClient(
                $businessId,
                ['phone' => $customerPhone, 'name' => $givenName],
                $customerName
            );
        } else {
            $customer = is_array($body['customer'] ?? null) ? $body['customer'] : [];
            $customerName = isset($customer['name']) && $customer['name'] !== '' ? (string) $customer['name'] : null;
            $customerPhone = isset($customer['phone']) && $customer['phone'] !== ''
                ? (Phone::normalize((string) $customer['phone']) ?? (string) $customer['phone'])
                : null;
            $source = (string) ($body['source'] ?? 'site');
            // Public web/bot never claims the app source.
            if (!in_array($source, ['site', 'bot', 'admin'], true)) {
                $source = 'site';
            }

            // Placed from the Telegram Mini App: verify the signed initData and
            // tie the order to that Telegram user (for their order history).
            $initData = (string) ($body['init_data'] ?? '');
            if ($initData !== '' && ($business->telegram_bot_token ?? '') !== '') {
                $verified = TelegramWebApp::verify($initData, (string) $business->telegram_bot_token);
                if ($verified !== null) {
                    $tgUserId = (int) $verified['user']['id'];
                    $source = 'bot';
                }
            }

            $clientId = $customerPhone !== null
                ? (new BookingService())->upsertClient(
                    $businessId,
                    ['phone' => $customerPhone, 'name' => $customerName],
                    $customerName
                )
                : null;
        }

        $tx = Yii::$app->db->beginTransaction();
        try {
            $order = new Order();
            $order->business_id = $businessId; // no tenant on these endpoints: set explicitly
            $order->client_id = $clientId;
            if ($mode === self::MODE_CONSUMER) {
                $order->consumer_id = (int) $consumer->id;
            }
            $order->customer_name = $customerName !== null ? mb_substr($customerName, 0, 128) : null;
            $order->customer_phone = $customerPhone;
            $order->note = $note !== '' ? $note : null;
            $order->source = $source;
            // Only touch tg_user_id when actually linked.
            if ($tgUserId !== null) {
                $order->tg_user_id = $tgUserId;
            }
            $order->status = Order::STATUS_NEW;
            $order->total_tiyin = 0;
            if (!$order->save()) {
                $tx->rollBack();
                return [$order, false];
            }

            $total = 0;
            foreach ($wanted as $sid => $qty) {
                $svc = $services[$sid] ?? null;
                if ($svc === null) {
                    continue; // requested item not on this menu — skip
                }
                $line = new OrderItem();
                $line->order_id = (int) $order->id;
                $line->business_id = $businessId;
                $line->service_id = (int) $sid;
                $line->name = $svc->name;
                $line->price_tiyin = (int) $svc->price_tiyin;
                $line->qty = (int) $qty;
                if (!$line->save()) {
                    $tx->rollBack();
                    $order->addError('items', $line->getFirstError('name') ?? 'Mahsulot qatori saqlanmadi.');
                    return [$order, false];
                }
                $total += (int) $svc->price_tiyin * (int) $qty;
            }

            $order->total_tiyin = $total;
            $order->save(false, ['total_tiyin']);
            $tx->commit();
        } catch (\Throwable $e) {
            if ($tx->getIsActive()) {
                $tx->rollBack();
            }
            Yii::error('Order create failed: ' . $e->getMessage(), 'catalog');
            throw new ServerErrorHttpException('Buyurtma yaratishda xatolik.');
        }

        $order->refresh();
        if ($cacheKey !== null && Yii::$app->has('cache')) {
            Yii::$app->cache->set($cacheKey, (int) $order->id, self::IDEM_TTL);
        }
        return [$order, false];
    }

    private function replay(?string $cacheKey, ?int $businessId, ?int $consumerId): ?Order
    {
        if ($cacheKey === null || !Yii::$app->has('cache')) {
            return null;
        }
        $cachedId = Yii::$app->cache->get($cacheKey);
        if ($cachedId === false) {
            return null;
        }
        $existing = Order::findOne((int) $cachedId);
        if ($existing === null) {
            return null;
        }
        if ($businessId !== null && (int) $existing->business_id !== $businessId) {
            return null;
        }
        if ($consumerId !== null && (int) $existing->consumer_id !== $consumerId) {
            return null;
        }
        return $existing;
    }
}
