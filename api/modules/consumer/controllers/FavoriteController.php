<?php

namespace api\modules\consumer\controllers;

use api\modules\consumer\components\ConsumerController;
use common\models\Business;
use common\models\ConsumerFavorite;
use common\presenters\BusinessPresenter;
use yii\db\IntegrityException;
use yii\web\NotFoundHttpException;

/**
 * Saved businesses.
 *
 * GET    /v1/consumer/favorites                directory cards (is_favorite: true), newest first
 * PUT    /v1/consumer/favorites/<businessId>   204, idempotent
 * DELETE /v1/consumer/favorites/<businessId>   204, idempotent
 */
class FavoriteController extends ConsumerController
{
    public function actionIndex(): array
    {
        $consumer = $this->consumer();
        $favorites = ConsumerFavorite::find()
            ->alias('f')
            ->innerJoin(['b' => Business::tableName()], 'b.id = f.business_id')
            ->where(['f.consumer_id' => (int) $consumer->id, 'b.status' => Business::STATUS_ACTIVE])
            ->orderBy(['f.created_at' => SORT_DESC, 'f.id' => SORT_DESC])
            ->with('business')
            ->all();

        $businesses = [];
        foreach ($favorites as $f) {
            if ($f->business !== null) {
                $businesses[] = $f->business;
            }
        }
        $prices = BusinessPresenter::priceFromMap($businesses);

        return array_map(static fn (Business $b) => BusinessPresenter::card($b, [
            'price_from_tiyin' => $prices[(int) $b->id] ?? null,
            'is_favorite' => true,
        ]), $businesses);
    }

    public function actionAdd(int $businessId)
    {
        $consumer = $this->consumer();
        $business = Business::find()
            ->where(['id' => $businessId, 'status' => Business::STATUS_ACTIVE])
            ->one();
        if ($business === null) {
            throw new NotFoundHttpException('Biznes topilmadi.');
        }

        $exists = ConsumerFavorite::find()
            ->where(['consumer_id' => (int) $consumer->id, 'business_id' => $businessId])
            ->exists();
        if (!$exists) {
            $fav = new ConsumerFavorite();
            $fav->consumer_id = (int) $consumer->id;
            $fav->business_id = $businessId;
            try {
                $fav->save(false);
            } catch (IntegrityException $e) {
                // Concurrent PUT already inserted it: still idempotent.
            }
        }
        return $this->noContent();
    }

    public function actionRemove(int $businessId)
    {
        $consumer = $this->consumer();
        ConsumerFavorite::deleteAll(['consumer_id' => (int) $consumer->id, 'business_id' => $businessId]);
        return $this->noContent();
    }
}
