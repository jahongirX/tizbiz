<?php

namespace api\modules\site;

use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;

/**
 * Public, unauthenticated read surface for the per-business booking site
 * ({slug}.navbat.uz). Exposes just enough for the consumer booking flow.
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\\modules\\site\\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            'GET v1/site/<slug:[a-z0-9-]+>' => 'site/site/view',
        ], false);
    }
}
