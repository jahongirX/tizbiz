<?php

namespace api\modules\booking\controllers;

use common\models\Staff;
use common\models\TimeOff;
use common\models\WorkingHours;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * Staff schedule management: weekly working hours and one-off time off.
 * Reads: any authed member. Writes: owner/admin. Staff is always resolved
 * through the active tenant so cross-tenant access is impossible.
 */
class ScheduleController extends Controller
{
    // --- Working hours ---

    public function actionWorkingHours(int $id): array
    {
        $staff = $this->findStaff($id);
        return WorkingHours::find()
            ->andWhere(['staff_id' => $staff->id])
            ->orderBy(['weekday' => SORT_ASC, 'start_time' => SORT_ASC])
            ->all();
    }

    /**
     * Replace the whole weekly set atomically. Body: { "items": [ {weekday,
     * start_time, end_time}, ... ] } (or a bare JSON array of such objects).
     */
    public function actionUpdateWorkingHours(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');
        $staff = $this->findStaff($id);

        $items = $this->extractItems();

        // Validate all rows first (fail before deleting anything).
        $models = [];
        foreach ($items as $i => $row) {
            if (!is_array($row)) {
                throw new \yii\web\BadRequestHttpException('Har bir ish vaqti elementi obyekt bo\'lishi kerak.');
            }
            $wh = new WorkingHours();
            $wh->staff_id = $staff->id;
            $wh->weekday = $row['weekday'] ?? null;
            $wh->start_time = $row['start_time'] ?? null;
            $wh->end_time = $row['end_time'] ?? null;
            if (!$wh->validate()) {
                Yii::$app->response->statusCode = 422;
                $out = [];
                foreach ($wh->getFirstErrors() as $field => $message) {
                    $out[] = ['field' => "items[$i].$field", 'message' => $message];
                }
                return $out;
            }
            $models[] = $wh;
        }

        $tx = Yii::$app->db->beginTransaction();
        try {
            WorkingHours::deleteAll(['staff_id' => $staff->id]);
            foreach ($models as $wh) {
                $wh->save(false);
            }
            $tx->commit();
        } catch (\Throwable $e) {
            $tx->rollBack();
            throw $e;
        }

        return WorkingHours::find()
            ->andWhere(['staff_id' => $staff->id])
            ->orderBy(['weekday' => SORT_ASC, 'start_time' => SORT_ASC])
            ->all();
    }

    // --- Time off ---

    public function actionTimeOff(int $id): array
    {
        $staff = $this->findStaff($id);
        return TimeOff::find()
            ->andWhere(['staff_id' => $staff->id])
            ->orderBy(['date' => SORT_ASC, 'start_time' => SORT_ASC])
            ->all();
    }

    public function actionCreateTimeOff(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');
        $staff = $this->findStaff($id);

        $model = new TimeOff();
        $model->staff_id = $staff->id;
        $model->date = $this->body('date');
        $model->start_time = $this->body('start_time');
        $model->end_time = $this->body('end_time');
        $model->reason = $this->body('reason');

        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $this->created($model);
    }

    public function actionDeleteTimeOff(int $staffId, int $id): array
    {
        $this->requireRole('business_owner', 'business_admin');
        $staff = $this->findStaff($staffId);

        $model = TimeOff::find()
            ->andWhere(['id' => $id, 'staff_id' => $staff->id])
            ->one();
        if ($model === null) {
            throw new NotFoundHttpException('Dam olish vaqti topilmadi.');
        }
        $model->delete();
        return ['deleted' => true];
    }

    /** @return array<int, mixed> */
    private function extractItems(): array
    {
        $body = $this->body();
        if (isset($body['items']) && is_array($body['items'])) {
            return array_values($body['items']);
        }
        if (is_array($body) && (array_is_list($body))) {
            return $body;
        }
        return [];
    }

    /** Resolve staff within the active tenant (404 otherwise). */
    private function findStaff(int $id): Staff
    {
        $model = Staff::findOne($id);
        if ($model === null) {
            throw new NotFoundHttpException('Xodim topilmadi.');
        }
        return $model;
    }
}
