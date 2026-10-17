<?php

namespace api\modules\consumer\services;

use common\models\Appointment;
use common\models\Client;
use common\models\ConsumerFavorite;
use common\models\ConsumerUser;
use common\models\Order;
use common\models\Review;
use Yii;
use yii\db\Query;

/**
 * Links a consumer account to the business-side rows that carry its phone, and
 * anonymizes the account on deletion. Plain table updates (no tenant scope).
 */
final class ConsumerLinker
{
    /**
     * Back-link unclaimed appointments (via clients.phone) and orders (via
     * orders.customer_phone) to the consumer.
     *
     * @return array{appointments:int, orders:int} rows updated
     */
    public static function backLink(ConsumerUser $consumer): array
    {
        $phone = (string) $consumer->phone;
        if ($phone === '' || strncmp($phone, 'deleted-', 8) === 0) {
            return ['appointments' => 0, 'orders' => 0];
        }
        $db = Yii::$app->db;
        $clientIds = (new Query())->select('id')->from(Client::tableName())->where(['phone' => $phone]);

        $appts = $db->createCommand()->update(
            Appointment::tableName(),
            ['consumer_id' => (int) $consumer->id],
            ['and', ['consumer_id' => null], ['in', 'client_id', $clientIds]]
        )->execute();

        $orders = $db->createCommand()->update(
            Order::tableName(),
            ['consumer_id' => (int) $consumer->id],
            ['and', ['consumer_id' => null], ['customer_phone' => $phone]]
        )->execute();

        return ['appointments' => (int) $appts, 'orders' => (int) $orders];
    }

    /**
     * Delete the account the GDPR-friendly way, in one transaction: personal
     * fields wiped, phone freed ("deleted-<id>"), reviews kept but de-attributed,
     * favorites removed, bookings/orders unlinked (the business keeps its rows).
     */
    public static function anonymize(ConsumerUser $consumer): void
    {
        $db = Yii::$app->db;
        $id = (int) $consumer->id;
        $now = time();
        $tx = $db->beginTransaction();
        try {
            $db->createCommand()->update(ConsumerUser::tableName(), [
                'phone' => 'deleted-' . $id,
                'name' => null,
                'birthday' => null,
                'gender' => null,
                'city' => null,
                'status' => ConsumerUser::STATUS_BLOCKED,
                'deleted_at' => $now,
                'updated_at' => $now,
            ], ['id' => $id])->execute();

            $db->createCommand()->update(Review::tableName(), [
                'author_name' => Review::DELETED_AUTHOR,
                'consumer_id' => null,
                'updated_at' => $now,
            ], ['consumer_id' => $id])->execute();

            $db->createCommand()->delete(ConsumerFavorite::tableName(), ['consumer_id' => $id])->execute();
            $db->createCommand()->update(Appointment::tableName(), ['consumer_id' => null], ['consumer_id' => $id])->execute();
            $db->createCommand()->update(Order::tableName(), ['consumer_id' => null], ['consumer_id' => $id])->execute();

            $tx->commit();
        } catch (\Throwable $e) {
            if ($tx->getIsActive()) {
                $tx->rollBack();
            }
            throw $e;
        }
    }
}
