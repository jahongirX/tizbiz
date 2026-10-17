<?php

namespace api\modules\me;

use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;

/**
 * Staff self-service ("me") module: the TizBiz Biznes staff shell. Every route
 * resolves the caller's own staff row (business_user linked via staff.user_id)
 * inside the active tenant and only ever exposes that row's data.
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\modules\me\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            'GET v1/me/staff' => 'me/me/staff',
            'GET v1/me/stats' => 'me/me/stats',
            'GET v1/me/schedule' => 'me/me/schedule',
            'GET v1/me/appointments' => 'me/appointment/index',
            'GET v1/me/appointments/<id:\d+>' => 'me/appointment/view',
            'PATCH v1/me/appointments/<id:\d+>' => 'me/appointment/update',
        ], false);
    }
}
