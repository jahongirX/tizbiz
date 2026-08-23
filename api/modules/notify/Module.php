<?php

namespace api\modules\notify;

use yii\base\BootstrapInterface;

/**
 * notify module: Telegram/SMS delivery and Telegram chat linking.
 */
class Module extends \yii\base\Module implements BootstrapInterface
{
    public $controllerNamespace = 'api\\modules\\notify\\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            'POST v1/webhooks/telegram' => 'notify/telegram-webhook/update',
            'GET v1/notifications' => 'notify/notification/index',
        ], false);
    }
}
