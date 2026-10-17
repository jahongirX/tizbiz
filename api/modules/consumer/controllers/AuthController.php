<?php

namespace api\modules\consumer\controllers;

use api\modules\consumer\components\ConsumerController;
use api\modules\consumer\services\ConsumerLinker;
use api\modules\consumer\services\OtpService;
use common\components\Jwt;
use common\helpers\Phone;
use common\models\ConsumerUser;
use Yii;
use yii\base\DynamicModel;
use yii\web\ForbiddenHttpException;

/**
 * Consumer phone + OTP login (public).
 *
 * POST /v1/consumer/auth/otp     {"phone"}                 -> {sent, ttl_sec, retry_after_sec}
 * POST /v1/consumer/auth/verify  {"phone","code","name"?}  -> {token, expires_at, is_new, consumer}
 */
class AuthController extends ConsumerController
{
    protected function authOptional(): array
    {
        return ['otp', 'verify'];
    }

    public function actionOtp()
    {
        $phone = self::normalizePhone($this->body('phone'));
        if ($phone === null) {
            return $this->fail422($this->fieldError('phone', 'Telefon raqam noto\'g\'ri.'));
        }
        return (new OtpService())->issue($phone, Yii::$app->request->userIP);
    }

    public function actionVerify()
    {
        $phone = self::normalizePhone($this->body('phone'));
        if ($phone === null) {
            return $this->fail422($this->fieldError('phone', 'Telefon raqam noto\'g\'ri.'));
        }
        $code = $this->body('code');
        $code = is_scalar($code) ? trim((string) $code) : '';
        if ($code === '' || !(new OtpService())->verify($phone, $code)) {
            return $this->fail422($this->fieldError('code', 'Kod noto\'g\'ri yoki muddati o\'tgan.'));
        }

        $consumer = ConsumerUser::find()->where(['phone' => $phone])->one();
        $isNew = false;
        if ($consumer === null) {
            $isNew = true;
            $consumer = new ConsumerUser();
            $consumer->phone = $phone;
            $name = $this->body('name');
            $name = is_string($name) ? trim($name) : '';
            $consumer->name = $name !== '' ? mb_substr($name, 0, 128) : null;
            $consumer->locale = 'uz';
            $consumer->status = ConsumerUser::STATUS_ACTIVE;
            if (!$consumer->save()) {
                return $this->fail422($consumer);
            }
        } elseif (!$consumer->isUsable()) {
            throw new ForbiddenHttpException('Hisob bloklangan.');
        }

        $consumer->last_login_at = time();
        $consumer->save(false, ['last_login_at', 'updated_at']);

        ConsumerLinker::backLink($consumer);

        $ttl = (int) Yii::$app->params['consumer.jwt.ttl'];
        $token = Jwt::issue((int) $consumer->id, null, null, Jwt::TYP_CONSUMER, $ttl);

        return [
            'token' => $token,
            'expires_at' => Jwt::expiresAt($ttl),
            'is_new' => $isNew,
            'consumer' => $consumer->toArray(),
        ];
    }

    /**
     * Canonical +998XXXXXXXXX, or null when the input is not a UZ mobile number
     * (9 local digits, optionally prefixed by 998).
     */
    public static function normalizePhone($raw): ?string
    {
        return is_scalar($raw) ? Phone::normalize((string) $raw) : null;
    }

    private function fieldError(string $field, string $message): DynamicModel
    {
        $model = new DynamicModel([$field => null]);
        $model->addError($field, $message);
        return $model;
    }
}
