<?php

namespace api\modules\consumer\controllers;

use api\modules\consumer\components\ConsumerController;
use api\modules\consumer\components\ConsumerItems;
use api\modules\consumer\services\ConsumerLinker;
use common\models\Appointment;
use common\models\Business;
use common\models\ConsumerFavorite;
use common\models\ConsumerUser;
use common\models\Order;
use common\models\Review;

/**
 * The consumer's own profile.
 *
 * GET    /v1/consumer/me   profile + stats
 * PATCH  /v1/consumer/me   {name?, birthday?, gender?, city?, locale?} (phone is immutable)
 * DELETE /v1/consumer/me   anonymize the account (204); the token stops working
 */
class MeController extends ConsumerController
{
    public function actionView(): array
    {
        return $this->payload($this->consumer());
    }

    public function actionUpdate()
    {
        $consumer = $this->consumer();
        $body = $this->body();
        $body = is_array($body) ? $body : [];

        // Nullable fields: null or "" clears.
        foreach (['name', 'birthday', 'gender', 'city'] as $attr) {
            if (array_key_exists($attr, $body)) {
                $v = $body[$attr];
                $consumer->$attr = ($v === null || (is_string($v) && trim($v) === ''))
                    ? null
                    : (is_scalar($v) ? trim((string) $v) : $v);
            }
        }
        if (array_key_exists('locale', $body) && $body['locale'] !== null && $body['locale'] !== '') {
            $consumer->locale = is_scalar($body['locale']) ? strtolower(trim((string) $body['locale'])) : $body['locale'];
        }

        if (!$consumer->save(true, ['name', 'birthday', 'gender', 'city', 'locale', 'updated_at'])) {
            return $this->fail422($consumer);
        }
        return $this->payload($consumer);
    }

    public function actionDelete()
    {
        ConsumerLinker::anonymize($this->consumer());
        return $this->noContent();
    }

    private function payload(ConsumerUser $consumer): array
    {
        $id = (int) $consumer->id;
        $now = gmdate('Y-m-d H:i:s');

        $upcoming = (int) Appointment::find()
            ->where(['consumer_id' => $id, 'status' => ConsumerItems::upcomingStatuses()])
            ->andWhere(['>=', 'starts_at', $now])
            ->count();
        $total = (int) Appointment::find()->where(['consumer_id' => $id])->count();
        $orders = (int) Order::find()->where(['consumer_id' => $id])->count();
        $reviews = (int) Review::find()->where(['consumer_id' => $id])->count();
        $favorites = (int) ConsumerFavorite::find()
            ->alias('f')
            ->innerJoin(['b' => Business::tableName()], 'b.id = f.business_id')
            ->where(['f.consumer_id' => $id, 'b.status' => Business::STATUS_ACTIVE])
            ->count();

        return $consumer->toArray() + [
            'stats' => [
                'appointments_upcoming' => $upcoming,
                'appointments_total' => $total,
                'orders_total' => $orders,
                'reviews_total' => $reviews,
                'favorites_total' => $favorites,
            ],
        ];
    }
}
