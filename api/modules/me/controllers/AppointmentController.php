<?php

namespace api\modules\me\controllers;

use common\models\Appointment;
use Yii;
use yii\base\Event;
use yii\web\BadRequestHttpException;
use yii\web\ConflictHttpException;
use yii\web\NotFoundHttpException;

/**
 * Staff self-service appointments: only the caller's own (staff_id = me).
 *
 *   GET   v1/me/appointments?from=YYYY-MM-DD&to=YYYY-MM-DD&status=  (local days, max 62)
 *   GET   v1/me/appointments/<id>
 *   PATCH v1/me/appointments/<id> {status}
 *
 * Staff may move a visit forward but never cancel it (cancellation stays with
 * owner/admin), so the transition table is the admin one minus `canceled`.
 */
class AppointmentController extends BaseMeController
{
    private const MAX_DAYS = 62;

    private const TRANSITIONS = [
        Appointment::STATUS_PENDING => [
            Appointment::STATUS_CONFIRMED,
            Appointment::STATUS_ARRIVED,
            Appointment::STATUS_COMPLETED,
            Appointment::STATUS_NO_SHOW,
        ],
        Appointment::STATUS_CONFIRMED => [
            Appointment::STATUS_ARRIVED,
            Appointment::STATUS_COMPLETED,
            Appointment::STATUS_NO_SHOW,
        ],
        Appointment::STATUS_ARRIVED => [
            Appointment::STATUS_COMPLETED,
            Appointment::STATUS_NO_SHOW,
        ],
        Appointment::STATUS_COMPLETED => [],
        Appointment::STATUS_NO_SHOW => [],
        Appointment::STATUS_CANCELED => [],
    ];

    /** GET v1/me/appointments */
    public function actionIndex(): array
    {
        $staff = $this->staff();
        $today = $this->todayLocal();
        [$from, $to] = $this->localRange($today, $today, self::MAX_DAYS);
        [$fromUtc, $toUtc] = $this->utcBounds($from, $to);

        $query = Appointment::find() // tenant-scoped
            ->andWhere(['staff_id' => (int) $staff->id])
            ->andWhere(['>=', 'starts_at', $fromUtc])
            ->andWhere(['<=', 'starts_at', $toUtc]);

        $status = Yii::$app->request->get('status');
        if ($status !== null && $status !== '') {
            if (!is_string($status) || !in_array($status, Appointment::STATUSES, true)) {
                throw new BadRequestHttpException('Noma\'lum holat.');
            }
            $query->andWhere(['status' => $status]);
        }

        return $query
            ->with(['client', 'service', 'staff', 'items'])
            ->orderBy(['starts_at' => SORT_ASC, 'id' => SORT_ASC])
            ->all();
    }

    /** GET v1/me/appointments/<id> */
    public function actionView(int $id): Appointment
    {
        return $this->findMine($id);
    }

    /** PATCH v1/me/appointments/<id> {status} */
    public function actionUpdate(int $id)
    {
        $model = $this->findMine($id);

        $next = $this->body('status');
        if (!is_string($next) || $next === '') {
            throw new BadRequestHttpException('status talab qilinadi.');
        }
        if (!in_array($next, Appointment::STATUSES, true)) {
            throw new BadRequestHttpException('Noma\'lum holat.');
        }

        // Decide the transition on the locked, latest committed row, so a
        // concurrent change (e.g. a consumer cancel) is never overwritten.
        $tx = Appointment::getDb()->beginTransaction();
        try {
            $model = Appointment::lockForUpdate((int) $model->id) ?? $model;
            $current = (string) $model->status;
            if ($next === $current) {
                $tx->rollBack();
                return $model; // no-op
            }
            $allowed = self::TRANSITIONS[$current] ?? [];
            if (!in_array($next, $allowed, true)) {
                throw new ConflictHttpException("Holatni '$current' dan '$next' ga o'zgartirib bo'lmaydi.");
            }

            $model->status = $next;
            if (!$model->save(true, ['status', 'updated_at'])) {
                $tx->rollBack();
                return $this->fail422($model);
            }
            $tx->commit();
        } catch (\Throwable $e) {
            if ($tx->getIsActive()) {
                $tx->rollBack();
            }
            throw $e;
        }

        if ($next === Appointment::STATUS_COMPLETED) {
            Yii::$app->trigger('appointmentCompleted', new Event(['sender' => $model]));
        }

        return $model;
    }

    /** The caller's own appointment in the active tenant, or 404. */
    private function findMine(int $id): Appointment
    {
        $staff = $this->staff();
        $model = Appointment::find() // tenant-scoped
            ->andWhere(['id' => $id, 'staff_id' => (int) $staff->id])
            ->with(['client', 'service', 'staff', 'items'])
            ->one();
        if ($model === null) {
            throw new NotFoundHttpException('Bron topilmadi.');
        }
        return $model;
    }
}
