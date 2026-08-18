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

            'GET v1/sms/templates' => 'sms/template/index',
            'POST v1/sms/templates' => 'sms/template/create',
            'PATCH v1/sms/templates/<id:\d+>' => 'sms/template/update',
            'DELETE v1/sms/templates/<id:\d+>' => 'sms/template/delete',

            'GET v1/sms/contacts' => 'sms/contact/index',
            'POST v1/sms/contacts' => 'sms/contact/create',
            'PATCH v1/sms/contacts/<id:\d+>' => 'sms/contact/update',
            'DELETE v1/sms/contacts/<id:\d+>' => 'sms/contact/delete',

            'GET v1/sms/blacklist' => 'sms/blacklist/index',
            'POST v1/sms/blacklist' => 'sms/blacklist/create',
            'DELETE v1/sms/blacklist/<id:\d+>' => 'sms/blacklist/delete',

            // Client's own API key (dashboard, Bearer-auth).
            'GET v1/sms/apikey' => 'sms/key/index',
            'POST v1/sms/apikey/regenerate' => 'sms/key/regenerate',

            // Public SMS API for third-party integrations (API-key auth).
            'POST v1/sms/api/send' => 'sms/api/send',
            'GET v1/sms/api/balance' => 'sms/api/balance',
            'GET v1/sms/api/messages' => 'sms/api/messages',
            'GET v1/sms/api/messages/<id:\d+>' => 'sms/api/message',
            'GET v1/sms/api/devices' => 'sms/api/devices',
        ], false);
    }
}
