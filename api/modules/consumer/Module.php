<?php

namespace api\modules\consumer;

use common\components\ConsumerAuth;
use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;
use yii\web\Request as WebRequest;

/**
 * Bizcat consumer API (/v1/consumer/*): OTP login, profile, favorites, own
 * appointments / orders, loyalty wallet and reviews. Authenticated with
 * typ=consumer JWTs through the separate `consumerUser` component; business
 * tokens get 401 here.
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\\modules\\consumer\\controllers';

    public function bootstrap($app): void
    {
        // Register the consumer user component up front.
        ConsumerAuth::userComponent();

        // Behind a reverse proxy REMOTE_ADDR is the proxy: trust its client-IP
        // headers (only from the configured CIDRs) so Request::getUserIP() — and
        // the per-IP OTP limit — sees the real client. Config, not code: params
        // 'request.trustedHosts' (env TRUSTED_PROXIES) / 'request.ipHeaders'.
        $trusted = (array) ($app->params['request.trustedHosts'] ?? []);
        $request = $app->getRequest();
        if ($trusted !== [] && $request instanceof WebRequest) {
            $ipHeaders = array_values(array_filter((array) ($app->params['request.ipHeaders'] ?? []), 'is_string'));
            $request->trustedHosts = $trusted;
            if ($ipHeaders !== []) {
                $request->ipHeaders = $ipHeaders;
                // Headers outside secureHeaders are never filtered: add them, so
                // an untrusted client cannot spoof e.g. CF-Connecting-IP.
                $request->secureHeaders = array_values(array_unique(array_merge($request->secureHeaders, $ipHeaders)));
            }
        }

        $app->getUrlManager()->addRules([
            'POST v1/consumer/auth/otp' => 'consumer/auth/otp',
            'POST v1/consumer/auth/verify' => 'consumer/auth/verify',
            'GET v1/consumer/me' => 'consumer/me/view',
            'PATCH v1/consumer/me' => 'consumer/me/update',
            'DELETE v1/consumer/me' => 'consumer/me/delete',
            'GET v1/consumer/favorites' => 'consumer/favorite/index',
            'PUT v1/consumer/favorites/<businessId:\d+>' => 'consumer/favorite/add',
            'DELETE v1/consumer/favorites/<businessId:\d+>' => 'consumer/favorite/remove',
            'GET v1/consumer/appointments' => 'consumer/appointment/index',
            'POST v1/consumer/appointments' => 'consumer/appointment/create',
            'GET v1/consumer/appointments/<id:\d+>' => 'consumer/appointment/view',
            'POST v1/consumer/appointments/<id:\d+>/cancel' => 'consumer/appointment/cancel',
            'GET v1/consumer/orders' => 'consumer/order/index',
            'POST v1/consumer/orders' => 'consumer/order/create',
            'GET v1/consumer/orders/<id:\d+>' => 'consumer/order/view',
            'POST v1/consumer/orders/<id:\d+>/cancel' => 'consumer/order/cancel',
            'GET v1/consumer/loyalty' => 'consumer/loyalty/index',
            'GET v1/consumer/reviews' => 'consumer/review/index',
            'POST v1/consumer/reviews' => 'consumer/review/create',
            'PATCH v1/consumer/reviews/<id:\d+>' => 'consumer/review/update',
            'DELETE v1/consumer/reviews/<id:\d+>' => 'consumer/review/delete',
        ], false);
    }
}
