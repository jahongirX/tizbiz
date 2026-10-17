<?php

namespace api\modules\consumer\controllers;

use api\modules\booking\services\BookingService;
use api\modules\consumer\components\ConsumerController;
use api\modules\consumer\components\ConsumerItems;
use common\models\Appointment;
use common\models\Transaction;
use Yii;
use yii\web\BadRequestHttpException;
use yii\web\ConflictHttpException;
use yii\web\NotFoundHttpException;

/**
 * The consumer's own bookings.
 *
 * GET  /v1/consumer/appointments?scope=upcoming|past&page=&per_page=
 * GET  /v1/consumer/appointments/<id>
 * POST /v1/consumer/appointments              (Idempotency-Key) slot or rental booking
 * POST /v1/consumer/appointments/<id>/cancel  {"reason"?}
 */
class AppointmentController extends ConsumerController
{
    private const WITH = ['business', 'staff', 'service'];

    public function actionIndex(): array
    {
        $consumer = $this->consumer();
        $scope = Yii::$app->request->get('scope', 'upcoming');
        $now = gmdate('Y-m-d H:i:s');
        $live = ConsumerItems::upcomingStatuses();

        $query = Appointment::find()
            ->where(['consumer_id' => (int) $consumer->id])
            ->with(self::WITH);
        if (!is_string($scope)) {
            throw new BadRequestHttpException('scope upcoming yoki past bo\'lishi kerak.');
        }
        if ($scope === 'upcoming') {
            $query->andWhere(['status' => $live])
                ->andWhere(['>=', 'starts_at', $now])
                ->orderBy(['starts_at' => SORT_ASC, 'id' => SORT_ASC]);
        } elseif ($scope === 'past') {
            $query->andWhere(['or', ['<', 'starts_at', $now], ['not in', 'status', $live]])
                ->orderBy(['starts_at' => SORT_DESC, 'id' => SORT_DESC]);
        } else {
            throw new BadRequestHttpException('scope upcoming yoki past bo\'lishi kerak.');
        }

        return $this->paginate($query, [ConsumerItems::class, 'appointments']);
    }

    public function actionView(int $id): array
    {
        return ConsumerItems::appointment($this->findMine($id));
    }

    public function actionCreate()
    {
        $consumer = $this->consumer();
        $body = $this->body();
        $body = is_array($body) ? $body : [];
        // Consumers never pick the client, status or products.
        unset($body['client'], $body['client_id'], $body['status'], $body['products']);

        $idemKey = Yii::$app->request->getHeaders()->get('Idempotency-Key');
        [$model, $replayed] = (new BookingService())->create(
            $body,
            BookingService::MODE_CONSUMER,
            is_string($idemKey) && $idemKey !== '' ? $idemKey : null,
            $consumer
        );
        if ($model->hasErrors()) {
            return $this->fail422($model);
        }

        $model = $this->findMine((int) $model->id);
        $item = ConsumerItems::appointment($model);
        return $replayed ? $item : $this->created($item);
    }

    public function actionCancel(int $id): array
    {
        $this->findMine($id); // 404 unless it is mine

        $reason = $this->body('reason');
        $reason = is_string($reason) ? trim($reason) : '';
        $line = 'Mijoz bekor qildi' . ($reason !== '' ? ': ' . mb_substr($reason, 0, 500) : '');

        // Lock the row and re-check on the latest committed state, so a staff /
        // PSP change made meanwhile is never overwritten.
        $tx = Appointment::getDb()->beginTransaction();
        try {
            $model = Appointment::lockForUpdate($id);
            if ($model === null || (int) $model->consumer_id !== (int) $this->consumer()->id) {
                throw new NotFoundHttpException('Bron topilmadi.');
            }
            if (!in_array((string) $model->status, ConsumerItems::CANCELABLE, true)
                || !ConsumerItems::startsInFuture($model)) {
                throw new ConflictHttpException('Bu bronni bekor qilib bo\'lmaydi.');
            }
            if ($model->paid) {
                throw new ConflictHttpException('Oldindan to\'lov qilingan bronni bekor qilish uchun biznes bilan bog\'laning.');
            }
            // A deposit the PSP already holds (Payme CreateTransaction / Click
            // Prepare done) may still be charged: cancel only via the business.
            $inFlight = Transaction::find()
                ->andWhere([
                    'appointment_id' => (int) $model->id,
                    'type' => Transaction::TYPE_DEPOSIT,
                    'status' => Transaction::STATUS_PENDING,
                ])
                ->exists();
            if ($inFlight) {
                throw new ConflictHttpException('To\'lov jarayonda. Bekor qilish uchun biznes bilan bog\'laning.');
            }

            $notes = trim((string) $model->notes);
            $model->notes = $notes !== '' ? $notes . "\n" . $line : $line;
            $model->status = Appointment::STATUS_CANCELED;
            // afterSave cancels the not-yet-started (created) deposit transactions.
            if (!$model->save(true, ['status', 'notes', 'updated_at'])) {
                throw new ConflictHttpException('Bu bronni bekor qilib bo\'lmaydi.');
            }
            $tx->commit();
        } catch (\Throwable $e) {
            if ($tx->getIsActive()) {
                $tx->rollBack();
            }
            throw $e;
        }

        return ConsumerItems::appointment($this->findMine($id));
    }

    private function findMine(int $id): Appointment
    {
        $model = Appointment::find()
            ->where(['id' => $id, 'consumer_id' => (int) $this->consumer()->id])
            ->with(self::WITH)
            ->one();
        if ($model === null) {
            throw new NotFoundHttpException('Bron topilmadi.');
        }
        return $model;
    }
}
