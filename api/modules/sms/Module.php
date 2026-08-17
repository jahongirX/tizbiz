<?php

namespace api\modules\sms;

use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;

/**
 * SMS gateway dashboard API (sms.tizbiz.uz). Multi-account: every resource is
 * scoped to the authenticated user. Devices = Android phones; messages = the
 * outbound log; send = dispatch through a device; stats = dashboard counters.
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\modules\sms\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            'GET v1/sms/devices' => 'sms/device/index',
            'POST v1/sms/devices' => 'sms/device/create',
            'PATCH v1/sms/devices/<id:\d+>' => 'sms/device/update',
            'DELETE v1/sms/devices/<id:\d+>' => 'sms/device/delete',

            'GET v1/sms/messages' => 'sms/message/index',
            'POST v1/sms/send' => 'sms/send/send',
            'GET v1/sms/stats' => 'sms/stats/index',
        ], false);
    }
}
