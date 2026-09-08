<?php

namespace api\modules\superadmin\controllers;

use common\helpers\Phone;
use common\models\SmsAccount;
use common\models\SmsLead;
use common\models\User;
use common\rest\Controller;
use Yii;
use yii\web\ForbiddenHttpException;
use yii\web\NotFoundHttpException;

/**
 * Landing-form applications (leads) + a self-service free trial + the superadmin
 * mini-CRM. `create` and `trial` are PUBLIC (landing); the rest need superadmin.
 */
class LeadController extends Controller
{
    /** How many SMS a free trial account gets. */
    private const TRIAL_QUOTA = 100;

    protected function authOptional(): array
    {
        return ['create', 'trial'];
    }

    /**
     * Public: "Bepul boshlash" — instantly create a 100-SMS trial account so
     * anyone can sign up and test. Returns the login (phone); the caller set the
     * password. Also drops a CRM lead (source=trial) for follow-up.
     */
    public function actionTrial(): array
    {
        $phone = Phone::normalize((string) $this->body('phone', ''));
        $name = trim((string) $this->body('name', ''));
        $password = (string) $this->body('password', '');
        if ($phone === null) {
            Yii::$app->response->statusCode = 422;
            return ['ok' => false, 'error' => 'Telefon raqam noto‘g‘ri'];
        }
        if (strlen($password) < 5) {
            Yii::$app->response->statusCode = 422;
            return ['ok' => false, 'error' => 'Parol kamida 5 ta belgi'];
        }

        $existing = User::findOne(['phone' => $phone]);
        if ($existing !== null && SmsAccount::findOne(['user_id' => $existing->id]) !== null) {
            Yii::$app->response->statusCode = 409;
            return ['ok' => false, 'error' => 'Bu raqamda akkaunt bor — Kirish sahifasidan kiring.'];
        }

        $tx = Yii::$app->db->beginTransaction();
        try {
            $user = $existing ?? new User();
            $user->phone = $phone;
            $user->name = $name !== '' ? $name : ($user->name ?: $phone);
            $user->status = User::STATUS_ACTIVE;
            $user->setPassword($password);
            if (!$user->save()) {
                $tx->rollBack();
                Yii::$app->response->statusCode = 422;
                return ['ok' => false, 'error' => 'Saqlab bo‘lmadi'];
            }

            $acc = new SmsAccount();
            $acc->user_id = (int) $user->id;
            $acc->quota_monthly = self::TRIAL_QUOTA;
            $acc->is_active = true;
            $acc->note = 'Bepul sinov (' . self::TRIAL_QUOTA . ' SMS)';
            $acc->save(false);

            $lead = new SmsLead();
            $lead->phone = $phone;
            $lead->name = $name !== '' ? $name : null;
            $lead->tariff = 'trial';
            $lead->status = 'new';
            $lead->source = 'trial';
            $lead->save(false);

            $tx->commit();
            return ['ok' => true, 'login' => $phone, 'quota' => self::TRIAL_QUOTA];
        } catch (\Throwable $e) {
            $tx->rollBack();
            Yii::$app->response->statusCode = 500;
            return ['ok' => false, 'error' => 'Xatolik yuz berdi'];
        }
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
