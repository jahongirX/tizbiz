<?php

namespace api\modules\superadmin;

use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;

/**
 * Platform superadmin API (superadmin.tizbiz.uz). Every action requires a user
 * with is_superadmin. First feature: managing SMS client accounts + quotas.
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\modules\superadmin\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            'GET v1/superadmin/sms-accounts' => 'superadmin/sms-account/index',
            'POST v1/superadmin/sms-accounts' => 'superadmin/sms-account/create',
            'PATCH v1/superadmin/sms-accounts/<id:\d+>' => 'superadmin/sms-account/update',
            'POST v1/superadmin/sms-accounts/<id:\d+>/password' => 'superadmin/sms-account/password',
            'DELETE v1/superadmin/sms-accounts/<id:\d+>' => 'superadmin/sms-account/delete',
        ], false);
    }
}
