<?php

namespace api\modules\auth;

use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;

/**
 * Auth module — accounts, tenants, sessions (login/register/me/switch).
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\modules\auth\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            'POST v1/auth/login' => 'auth/auth/login',
            'POST v1/auth/register' => 'auth/auth/register',
            'GET v1/auth/check-slug' => 'auth/auth/check-slug',
            'GET v1/auth/me' => 'auth/auth/me',
            'POST v1/auth/switch/<businessId:\d+>' => 'auth/auth/switch',
            'GET v1/team' => 'auth/team/index',
            'POST v1/team' => 'auth/team/create',
            'PATCH v1/team/<userId:\d+>' => 'auth/team/update',
            'DELETE v1/team/<userId:\d+>' => 'auth/team/delete',
        ], false);
    }
}
