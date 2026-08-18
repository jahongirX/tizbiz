<?php

namespace api\modules\superadmin\controllers;

use common\helpers\Phone;
use common\models\SmsAccount;
use common\models\User;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * Superadmin management of SMS client accounts: create login/password, set the
 * monthly quota, block/unblock, reset password. Each account is a platform user
 * with an sms_accounts row; the client logs into sms.tizbiz.uz and sees only
 * their own data.
 */
class SmsAccountController extends BaseController
{
    public function actionIndex(): array
    {
        $accounts = SmsAccount::find()->with('user')->orderBy(['id' => SORT_DESC])->all();
        return ['items' => array_map([$this, 'serialize'], $accounts)];
    }

    public function actionCreate()
    {
        $phone = Phone::normalize((string) $this->body('phone', ''));
        $name = trim((string) $this->body('name', ''));
        $password = (string) $this->body('password', '');
        $quota = max(0, (int) $this->body('quota_monthly', 0));
        $note = trim((string) $this->body('note', ''));

        $errors = [];
        if ($phone === null) {
            $errors[] = ['field' => 'phone', 'message' => 'Telefon raqam noto‘g‘ri.'];
        }
        if ($name === '') {
            $errors[] = ['field' => 'name', 'message' => 'Nom kiriting.'];
        }
        if (strlen($password) < 5) {
            $errors[] = ['field' => 'password', 'message' => 'Parol kamida 5 ta belgi.'];
        }
        if ($errors !== []) {
            Yii::$app->response->statusCode = 422;
            return $errors;
        }

        $tx = Yii::$app->db->beginTransaction();
        try {
            // Reuse an existing platform user with this phone, else create one.
            $user = User::findOne(['phone' => $phone]);
            if ($user === null) {
                $user = new User();
                $user->phone = $phone;
            }
            $user->name = $name;
            $user->status = User::STATUS_ACTIVE;
            $user->setPassword($password);
            if (!$user->save()) {
                $tx->rollBack();
                return $this->fail422($user);
            }

            if (SmsAccount::findOne(['user_id' => $user->id]) !== null) {
                $tx->rollBack();
                Yii::$app->response->statusCode = 422;
                return [['field' => 'phone', 'message' => 'Bu foydalanuvchida SMS akkaunt allaqachon bor.']];
            }

            $acc = new SmsAccount();
            $acc->user_id = (int) $user->id;
            $acc->quota_monthly = $quota;
            $acc->is_active = true;
            $acc->note = $note !== '' ? $note : null;
            if (!$acc->save()) {
                $tx->rollBack();
                return $this->fail422($acc);
            }
            $tx->commit();
            $acc->populateRelation('user', $user);
            return $this->created($this->serialize($acc));
        } catch (\Throwable $e) {
            $tx->rollBack();
            throw $e;
        }
    }

    public function actionUpdate(int $id)
    {
        $acc = $this->find($id);

        if (($v = $this->body('quota_monthly')) !== null) {
            $acc->quota_monthly = max(0, (int) $v);
        }
        if (($v = $this->body('is_active')) !== null) {
            $acc->is_active = (bool) $v;
        }
        if (array_key_exists('note', $this->body())) {
            $v = $this->body('note');
            $acc->note = ($v === null || trim((string) $v) === '') ? null : trim((string) $v);
        }
        if (!$acc->save()) {
            return $this->fail422($acc);
        }

        // Name lives on the user record.
        if (($name = $this->body('name')) !== null && trim((string) $name) !== '' && $acc->user !== null) {
            $acc->user->name = trim((string) $name);
            $acc->user->save(false, ['name']);
        }
        return $this->serialize($acc);
    }

    /** POST .../<id>/password { password } — reset the account's login password. */
    public function actionPassword(int $id): array
    {
        $acc = $this->find($id);
        $password = (string) $this->body('password', '');
        if (strlen($password) < 5) {
            Yii::$app->response->statusCode = 422;
            return [['field' => 'password', 'message' => 'Parol kamida 5 ta belgi.']];
        }
        if ($acc->user === null) {
            throw new NotFoundHttpException('Foydalanuvchi topilmadi.');
        }
        $acc->user->setPassword($password);
        $acc->user->save(false, ['password_hash']);
        return ['ok' => true];
    }

    /** POST .../<id>/apikey — rotate the account's public API key. */
    public function actionApikey(int $id): array
    {
        $acc = $this->find($id);
        $acc->rotateKey();
        return ['api_key' => $acc->api_key];
    }

    /** Revoke SMS access (removes the sms_account row; the login itself remains). */
    public function actionDelete(int $id): array
    {
        $this->find($id)->delete();
        return ['deleted' => true];
    }

    private function find(int $id): SmsAccount
    {
        $acc = SmsAccount::find()->with('user')->where(['id' => $id])->one();
        if ($acc === null) {
            throw new NotFoundHttpException('Akkaunt topilmadi.');
        }
        return $acc;
    }

    private function serialize(SmsAccount $a): array
    {
        return [
            'id' => (int) $a->id,
            'user_id' => (int) $a->user_id,
            'name' => $a->user?->name,
            'phone' => $a->user?->phone,
            'quota_monthly' => (int) $a->quota_monthly,
            'usage' => $a->usageThisMonth(),
            'remaining' => $a->remaining(),
            'is_active' => (bool) $a->is_active,
            'note' => $a->note,
            'api_key' => $a->api_key,
            'created_at' => (int) $a->created_at,
        ];
    }
}
