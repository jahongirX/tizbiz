<?php

namespace api\modules\inventory;

use yii\base\BootstrapInterface;
use yii\rest\UrlRule;

/**
 * Inventory module: products (goods) + stock movement ledger.
 *
 * Sub-resource verbs and the non-numeric `summary` collection route are
 * registered BEFORE the generic rest UrlRule so they win over the default
 * view/update pattern that would otherwise swallow `summary` as an id.
 */
class Module extends \yii\base\Module implements BootstrapInterface
{
    public $controllerNamespace = 'api\modules\inventory\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            // Collection-level summary (non-numeric segment must beat view/<id>).
            'GET v1/products/summary' => 'inventory/product/summary',

            // Stock sub-resource: adjust quantity + append a ledger row.
            'POST v1/products/<id:\d+>/stock' => 'inventory/product/stock',
            'GET v1/products/<id:\d+>/movements' => 'inventory/product/movements',

            // Standard CRUD for products.
            [
                'class' => UrlRule::class,
                'controller' => ['v1/products' => 'inventory/product'],
                'pluralize' => false,
            ],
        ], false);
    }
}
