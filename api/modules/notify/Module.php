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
            // Per-business webhook: the {biz} path segment tells us which bot
            // (token) the update belongs to. The legacy no-id route is kept for
            // backward compatibility (linking-only, no per-business replies).
            'POST v1/webhooks/telegram/<biz:\d+>' => 'notify/telegram-webhook/update',
            'POST v1/webhooks/telegram' => 'notify/telegram-webhook/update',

            // Telegram Mini App (catalog running inside Telegram): initData-authed.
            'POST v1/telegram/webapp-auth' => 'notify/webapp/auth',
            'GET v1/telegram/orders' => 'notify/webapp/orders',
        ], false);
    }
}
