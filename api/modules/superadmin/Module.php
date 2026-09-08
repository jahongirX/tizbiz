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
            'POST v1/superadmin/sms-accounts/<id:\d+>/apikey' => 'superadmin/sms-account/apikey',
            'DELETE v1/superadmin/sms-accounts/<id:\d+>' => 'superadmin/sms-account/delete',
            // Per-account activity
            'GET v1/superadmin/sms-accounts/<id:\d+>/messages' => 'superadmin/sms-account/messages',
            'GET v1/superadmin/sms-accounts/<id:\d+>/contacts' => 'superadmin/sms-account/contacts',
            'GET v1/superadmin/sms-accounts/<id:\d+>/activity' => 'superadmin/sms-account/activity',
            // Leads (public create + CRM)
            'POST v1/leads' => 'superadmin/lead/create',
            'GET v1/superadmin/leads' => 'superadmin/lead/index',
            'PATCH v1/superadmin/leads/<id:\d+>' => 'superadmin/lead/update',
            'DELETE v1/superadmin/leads/<id:\d+>' => 'superadmin/lead/delete',
            // Sales
            'GET v1/superadmin/sales' => 'superadmin/sale/index',
            'POST v1/superadmin/sales' => 'superadmin/sale/create',
            'DELETE v1/superadmin/sales/<id:\d+>' => 'superadmin/sale/delete',
            // Recipients base + reports
            'GET v1/superadmin/recipients' => 'superadmin/recipient/index',
            'GET v1/superadmin/report' => 'superadmin/report/summary',
        ], false);
    }
}
