<?php

namespace api\modules\catalog;

use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;

/**
 * Catalog module — orders for the cafe/restaurant/cakes (catalog engine)
 * vertical: public checkout + admin order history.
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\modules\catalog\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            'POST v1/orders' => 'catalog/order/create',
            'GET v1/orders' => 'catalog/order/index',
            'PATCH v1/orders/<id:\d+>' => 'catalog/order/update',
        ], false);
    }
}
