<?php

namespace common\rest;

use common\models\User;
use Yii;
use yii\filters\auth\HttpBearerAuth;
use yii\web\Controller as WebController;
use yii\web\ForbiddenHttpException;
use yii\web\Response;

/**
 * Base REST controller: JSON I/O, JWT Bearer auth, and per-tenant role checks.
 *
 * Subclasses list public action ids in {@see authOptional()} (login, webhooks,
 * public availability…); everything else requires a valid Bearer token. After
 * auth the active tenant is bound to {@see \common\components\TenantContext}.
 */
class Controller extends WebController
{
    public $enableCsrfValidation = false;

    public function behaviors(): array
    {
        $behaviors = parent::behaviors();
        // CORS must run before auth (handles OPTIONS preflight). Bearer auth only,
        // no cookies, so a wildcard origin is safe unless APP_ORIGINS restricts it.
        $behaviors['corsFilter'] = [
            'class' => \yii\filters\Cors::class,
            'cors' => [
                'Origin' => explode(',', getenv('APP_ORIGINS') ?: '*'),
                'Access-Control-Request-Method' => ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
                'Access-Control-Request-Headers' => ['Authorization', 'Content-Type', 'X-Telegram-Init-Data', 'X-Api-Key'],
                'Access-Control-Max-Age' => 3600,
            ],
        ];
        $behaviors['authenticator'] = [
            'class' => HttpBearerAuth::class,
            'optional' => $this->authOptional(),
        ];
        return $behaviors;
    }

    /** Action ids that do not require authentication. */
    protected function authOptional(): array
    {
        return [];
    }

    public function beforeAction($action)
    {
        Yii::$app->response->format = Response::FORMAT_JSON;
        if (!parent::beforeAction($action)) {
            return false;
        }
        $identity = Yii::$app->user->identity;
        if ($identity instanceof User && Yii::$app->has('tenant')) {
            Yii::$app->tenant->setId($identity->activeTenantId);
        }
        return true;
    }

    protected function currentUser(): ?User
    {
        $identity = Yii::$app->user->identity;
        return $identity instanceof User ? $identity : null;
    }

    /** Require the authenticated user to hold one of the given roles in the active tenant. */
    protected function requireRole(string ...$roles): void
    {
        $user = $this->currentUser();
        if ($user === null || !in_array($user->activeRole, $roles, true)) {
            throw new ForbiddenHttpException('Insufficient role for this action.');
        }
    }

    /** JSON body param helper. */
    protected function body(?string $key = null, $default = null)
    {
        $data = Yii::$app->request->getBodyParams();
        return $key === null ? $data : ($data[$key] ?? $default);
    }

    /** Mark the response as 201 Created and return the payload. */
    protected function created($data)
    {
        Yii::$app->response->statusCode = 201;
        return $data;
    }

    /**
     * Build a 422 validation-error payload from a model; the Envelope turns it
     * into the standard { "errors": [...] } shape. Usage:
     *   if (!$model->save()) { return $this->fail422($model); }
     */
    protected function fail422(\yii\base\Model $model): array
    {
        Yii::$app->response->statusCode = 422;
        $out = [];
        foreach ($model->getFirstErrors() as $field => $message) {
            $out[] = ['field' => $field, 'message' => $message];
        }
        return $out;
    }
}
