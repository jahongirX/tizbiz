<?php

namespace api\modules\sms\controllers;

use common\models\SmsAccount;
use yii\web\UnprocessableEntityHttpException;

/**
 * The logged-in client's own API key (dashboard, Bearer-auth):
 *   GET  v1/sms/apikey              show the key + base URL
 *   POST v1/sms/apikey/regenerate   rotate it (old key stops working)
 *
 * Only accounts provisioned by a superadmin have a key; demo/local users get a
 * clear message instead.
 */
class KeyController extends BaseController
{
    public function actionIndex(): array
    {
        return $this->payload($this->account());
    }

    public function actionRegenerate(): array
    {
        $account = $this->account();
        $account->rotateKey();
        return $this->payload($account);
    }

    private function account(): SmsAccount
    {
        $account = SmsAccount::forUser($this->uid());
        if ($account === null) {
            throw new UnprocessableEntityHttpException('Bu akkaunt uchun API mavjud emas. Administrator bilan bog\'laning.');
        }
        if (($account->api_key ?? '') === '') {
            $account->rotateKey(); // backfill for older rows
        }
        return $account;
    }

    private function payload(SmsAccount $account): array
    {
        return [
            'api_key' => $account->api_key,
            'base_url' => rtrim((string) (getenv('SMS_API_BASE') ?: 'https://api.tizbiz.uz'), '/'),
        ];
    }
}
