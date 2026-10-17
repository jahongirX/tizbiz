<?php

namespace api\modules\booking\controllers;

use api\modules\booking\services\BookingService;
use common\models\Appointment;
use common\models\Business;
use common\rest\Controller;
use Yii;
use yii\base\Event;
use yii\web\BadRequestHttpException;
use yii\web\ConflictHttpException;
use yii\web\ForbiddenHttpException;
use yii\web\NotFoundHttpException;

/**
 * Appointments: listing (tenant owner/admin), creation (public + admin), status changes.
 *
 * Creation is delegated to {@see BookingService} (shared with the Bizcat consumer
 * endpoint): business_id is always derived from the staff row, never trusted
 * from the client. Overlapping a live appointment yields 409. Idempotency-Key is
 * honored for 24h.
 */
class AppointmentController extends Controller
{
    /** Allowed status transitions. Terminal states have no outgoing edges. */
    private const TRANSITIONS = [
        Appointment::STATUS_PENDING => [
            Appointment::STATUS_CONFIRMED,
            Appointment::STATUS_ARRIVED,
            Appointment::STATUS_COMPLETED,
            Appointment::STATUS_NO_SHOW,
            Appointment::STATUS_CANCELED,
        ],
        Appointment::STATUS_CONFIRMED => [
            Appointment::STATUS_ARRIVED,
            Appointment::STATUS_COMPLETED,
            Appointment::STATUS_NO_SHOW,
            Appointment::STATUS_CANCELED,
        ],
        Appointment::STATUS_ARRIVED => [
            Appointment::STATUS_COMPLETED,
            Appointment::STATUS_NO_SHOW,
            Appointment::STATUS_CANCELED,
        ],
        Appointment::STATUS_COMPLETED => [],
        Appointment::STATUS_NO_SHOW => [],
        Appointment::STATUS_CANCELED => [],
    ];

    protected function authOptional(): array
    {
        return ['create'];
    }

    public function actionIndex(): array
    {
        // Staff tokens use /v1/me/appointments instead.
        $this->requireRole(Business::ROLE_OWNER, Business::ROLE_ADMIN);
        // A valid business context is mandatory: a JWT with tid=null must not
        // bypass tenant scoping and read every business's appointments.
        Yii::$app->tenant->require();

        $query = Appointment::find();

        $from = (string) Yii::$app->request->get('from', '');
        $to = (string) Yii::$app->request->get('to', '');
        $staff = (int) Yii::$app->request->get('staff', 0);
        $status = (string) Yii::$app->request->get('status', '');

        if ($from !== '') {
            $query->andWhere(['>=', 'starts_at', $from]);
        }
        if ($to !== '') {
            $query->andWhere(['<=', 'starts_at', $to]);
        }
        if ($staff > 0) {
            $query->andWhere(['staff_id' => $staff]);
        }
        if ($status !== '') {
            $query->andWhere(['status' => $status]);
        }

        return $query->with(['client', 'service', 'staff', 'items'])->orderBy(['starts_at' => SORT_ASC])->all();
    }

    public function actionView(int $id): Appointment
    {
        $this->requireRole(Business::ROLE_OWNER, Business::ROLE_ADMIN);
        // Require an active tenant so the query below is scoped to the caller's
        // business and cannot leak another tenant's appointment.
        Yii::$app->tenant->require();

        $model = Appointment::findOne($id);
        if ($model === null) {
            throw new NotFoundHttpException('Bron topilmadi.');
        }
        return $model;
    }

    /**
     * POST v1/appointments. Mode by caller:
     *  - no business token            -> public booking link (server-side rules)
     *  - token without active tenant  -> 403
     *  - owner / admin                -> admin mode (backfill / override allowed)
     *  - staff                        -> 403 (staff use /v1/me/*)
     * A new booking answers 201, an Idempotency-Key replay 200.
     */
    public function actionCreate()
    {
        $user = $this->currentUser();
        if ($user === null) {
            $mode = BookingService::MODE_PUBLIC;
        } elseif ($user->activeTenantId === null) {
            throw new ForbiddenHttpException('No active business selected.');
        } elseif (in_array($user->activeRole, [Business::ROLE_OWNER, Business::ROLE_ADMIN], true)) {
            $mode = BookingService::MODE_ADMIN;
        } else {
            throw new ForbiddenHttpException('Insufficient role for this action.');
        }

        $idemKey = Yii::$app->request->getHeaders()->get('Idempotency-Key');
        $body = $this->body();
        [$model, $replayed] = (new BookingService())->create(
            is_array($body) ? $body : [],
            $mode,
            is_string($idemKey) && $idemKey !== '' ? $idemKey : null
        );
        if ($model->hasErrors()) {
            return $this->fail422($model);
        }
        return $replayed ? $model : $this->created($model);
    }

    public function actionUpdate(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = Appointment::findOne($id);
        if ($model === null) {
            throw new NotFoundHttpException('Bron topilmadi.');
        }

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
            if (!$model->save()) {
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
}
