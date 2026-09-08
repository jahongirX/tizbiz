<?php

namespace api\modules\superadmin\controllers;

use common\models\SmsLead;
use common\rest\Controller;
use Yii;
use yii\web\ForbiddenHttpException;
use yii\web\NotFoundHttpException;

/**
 * Landing-form applications (leads) + the superadmin mini-CRM over them.
 * `create` is PUBLIC (the sms.tizbiz.uz landing form); the rest require superadmin.
 */
class LeadController extends Controller
{
    protected function authOptional(): array
    {
        return ['create'];
    }

    /** Public: "Ariza qoldirish" from the landing page. */
    public function actionCreate(): array
    {
        $phone = trim((string) $this->body('phone'));
        if ($phone === '') {
            Yii::$app->response->statusCode = 422;
            return ['ok' => false, 'error' => 'Telefon raqam kerak'];
        }
        $lead = new SmsLead();
        $lead->phone = mb_substr($phone, 0, 32);
        $lead->name = self::clip($this->body('name'), 120);
        $lead->business = self::clip($this->body('business'), 160);
        $lead->tariff = self::clip($this->body('tariff'), 20);
        $lead->note = self::clip($this->body('note'), 500);
        $lead->status = 'new';
        $lead->source = 'landing';
        $lead->save(false);
        return ['ok' => true];
    }

    public function actionIndex(): array
    {
        $this->requireSuper();
        $q = SmsLead::find();
        if (($s = trim((string) Yii::$app->request->get('status'))) !== '') {
            $q->andWhere(['status' => $s]);
        }
        return $q->orderBy(['created_at' => SORT_DESC])->limit(500)->all();
    }

    public function actionUpdate(int $id): array
    {
        $this->requireSuper();
        $lead = SmsLead::findOne($id);
        if ($lead === null) {
            throw new NotFoundHttpException('Ariza topilmadi.');
        }
        $status = $this->body('status');
        if ($status !== null && in_array($status, SmsLead::STATUSES, true)) {
            $lead->status = $status;
        }
        if (array_key_exists('note', $this->body())) {
            $lead->note = self::clip($this->body('note'), 500);
        }
        $lead->save(false);
        return ['ok' => true, 'lead' => $lead];
    }

    public function actionDelete(int $id): array
    {
        $this->requireSuper();
        $lead = SmsLead::findOne($id);
        if ($lead !== null) {
            $lead->delete();
        }
        return ['deleted' => true];
    }

    private function requireSuper(): void
    {
        $u = $this->currentUser();
        if ($u === null || !$u->is_superadmin) {
            throw new ForbiddenHttpException('Faqat superadmin uchun.');
        }
    }

    private static function clip($v, int $max): ?string
    {
        $s = trim((string) ($v ?? ''));
        return $s === '' ? null : mb_substr($s, 0, $max);
    }
}
