<?php

namespace api\modules\sms\controllers;

use common\models\SmsAccount;
use common\rest\Controller;
use Yii;
use yii\web\UnauthorizedHttpException;
use yii\web\UnprocessableEntityHttpException;

/**
 * Base for the PUBLIC SMS API (v1/sms/api/*) used by third-party systems.
 *
 * Auth is by secret API key, NOT a JWT Bearer token, so no dashboard login is
 * needed. The key may be supplied as:
 *   - header  X-Api-Key: tzb_…            (preferred)
 *   - header  Authorization: Bearer tzb_… (convenient for most HTTP clients)
 *   - query/body  key=tzb_…               (simplest for quick tests)
 *
 * The resolved {@see SmsAccount} scopes everything (its user's devices, quota
 * and blacklist). Responses use the platform envelope: success => { data: … },
 * error => { errors: [ { status, title, detail } ] }.
 */
abstract class ApiBaseController extends Controller
{
    protected ?SmsAccount $account = null;

    /** API-key auth replaces the Bearer authenticator; CORS still applies. */
    public function behaviors(): array
    {
        $behaviors = parent::behaviors();
        unset($behaviors['authenticator']);
        return $behaviors;
    }

    public function beforeAction($action): bool
    {
        if (!parent::beforeAction($action)) {
            return false;
        }

        $account = SmsAccount::findByApiKey((string) $this->extractKey());
        if ($account === null) {
            throw new UnauthorizedHttpException('API kalit noto\'g\'ri yoki berilmagan.');
        }
        if (!$account->is_active) {
            throw new UnprocessableEntityHttpException('SMS akkaunt bloklangan.');
        }
        $this->account = $account;
        return true;
    }

    protected function uid(): int
    {
        return $this->account ? (int) $this->account->user_id : 0;
    }

    /** Read the key from header, Bearer, or query/body — first match wins. */
    private function extractKey(): string
    {
        $req = Yii::$app->request;

        $header = (string) $req->getHeaders()->get('X-Api-Key', '');
        if (trim($header) !== '') {
            return trim($header);
        }

        $auth = (string) $req->getHeaders()->get('Authorization', '');
        if (preg_match('/^Bearer\s+(.+)$/i', trim($auth), $m)) {
            return trim($m[1]);
        }

        $key = $req->get('key');
        if ($key === null) {
            $key = $req->getBodyParam('key');
        }
        return trim((string) $key);
    }
}
