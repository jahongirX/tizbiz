<?php

namespace api\modules\consumer\controllers;

use api\modules\consumer\components\ConsumerController;
use common\models\Appointment;
use common\models\Order;
use common\models\OrderItem;
use common\models\Review;
use common\presenters\ReviewPresenter;
use yii\db\IntegrityException;
use yii\web\BadRequestHttpException;
use yii\web\ConflictHttpException;
use yii\web\NotFoundHttpException;

/**
 * The consumer's own reviews.
 *
 * GET    /v1/consumer/reviews
 * POST   /v1/consumer/reviews        {appointment_id | order_id, rating, comment?}
 * PATCH  /v1/consumer/reviews/<id>   {rating?, comment?}
 * DELETE /v1/consumer/reviews/<id>
 */
class ReviewController extends ConsumerController
{
    private const WITH = ['business', 'staff', 'service'];

    public function actionIndex(): array
    {
        $rows = Review::find()
            ->where(['consumer_id' => (int) $this->consumer()->id])
            ->with(self::WITH)
            ->orderBy(['id' => SORT_DESC])
            ->all();
        return array_map([ReviewPresenter::class, 'mine'], $rows);
    }

    public function actionCreate()
    {
        $consumer = $this->consumer();
        $appointmentId = (int) $this->body('appointment_id', 0);
        $orderId = (int) $this->body('order_id', 0);
        if (($appointmentId > 0) === ($orderId > 0)) {
            throw new BadRequestHttpException('appointment_id yoki order_id talab qilinadi.');
        }

        $review = new Review();
        $review->consumer_id = (int) $consumer->id;
        $review->author_name = Review::maskName($consumer->name);
        $review->status = Review::STATUS_PUBLISHED;

        if ($appointmentId > 0) {
            $appt = Appointment::find()
                ->where(['id' => $appointmentId, 'consumer_id' => (int) $consumer->id])
                ->one();
            if ($appt === null) {
                throw new NotFoundHttpException('Bron topilmadi.');
            }
            if ((string) $appt->status !== Appointment::STATUS_COMPLETED) {
                throw new ConflictHttpException('Faqat yakunlangan tashrif uchun sharh qoldirish mumkin.');
            }
            if (Review::find()->where(['appointment_id' => $appointmentId])->exists()) {
                throw new ConflictHttpException('Bu tashrif uchun sharh allaqachon qoldirilgan.');
            }
            $review->business_id = (int) $appt->business_id;
            $review->appointment_id = (int) $appt->id;
            $review->staff_id = (int) $appt->staff_id;
            $review->service_id = (int) $appt->service_id;
        } else {
            $order = Order::find()
                ->where(['id' => $orderId, 'consumer_id' => (int) $consumer->id])
                ->one();
            if ($order === null) {
                throw new NotFoundHttpException('Buyurtma topilmadi.');
            }
            if ((string) $order->status !== Order::STATUS_DELIVERED) {
                throw new ConflictHttpException('Faqat yakunlangan tashrif uchun sharh qoldirish mumkin.');
            }
            if (Review::find()->where(['order_id' => $orderId])->exists()) {
                throw new ConflictHttpException('Bu tashrif uchun sharh allaqachon qoldirilgan.');
            }
            $firstServiceId = OrderItem::find()
                ->select(['service_id'])
                ->where(['order_id' => (int) $order->id])
                ->andWhere(['not', ['service_id' => null]])
                ->orderBy(['id' => SORT_ASC])
                ->scalar();
            $review->business_id = (int) $order->business_id;
            $review->order_id = (int) $order->id;
            $review->service_id = $firstServiceId !== false && $firstServiceId !== null ? (int) $firstServiceId : null;
        }

        $this->applyInput($review, true);
        try {
            if (!$review->save()) {
                return $this->fail422($review);
            }
        } catch (IntegrityException $e) {
            // UNIQUE(appointment_id) / UNIQUE(order_id) lost a race.
            throw new ConflictHttpException('Bu tashrif uchun sharh allaqachon qoldirilgan.');
        }

        return $this->created(ReviewPresenter::mine($this->findMine((int) $review->id)));
    }

    public function actionUpdate(int $id)
    {
        $review = $this->findMine($id);
        $this->applyInput($review, false);
        if (!$review->save()) {
            return $this->fail422($review);
        }
        return ReviewPresenter::mine($this->findMine($id));
    }

    public function actionDelete(int $id)
    {
        // afterDelete() recomputes the business rating.
        $this->findMine($id)->delete();
        return $this->noContent();
    }

    /** Copy rating/comment from the body (rating is required on create). */
    private function applyInput(Review $review, bool $isCreate): void
    {
        $body = $this->body();
        $body = is_array($body) ? $body : [];
        if ($isCreate || array_key_exists('rating', $body)) {
            $rating = $body['rating'] ?? null;
            // Leave non-integers as-is so the `integer` rule reports 422 on `rating`.
            $review->rating = is_int($rating) || (is_string($rating) && ctype_digit($rating)) ? (int) $rating : $rating;
        }
        if (array_key_exists('comment', $body)) {
            $comment = $body['comment'];
            $review->comment = ($comment === null || (is_string($comment) && trim($comment) === ''))
                ? null
                : (is_string($comment) ? trim($comment) : $comment);
        }
    }

    private function findMine(int $id): Review
    {
        $review = Review::find()
            ->where(['id' => $id, 'consumer_id' => (int) $this->consumer()->id])
            ->with(self::WITH)
            ->one();
        if ($review === null) {
            throw new NotFoundHttpException('Sharh topilmadi.');
        }
        return $review;
    }
}
