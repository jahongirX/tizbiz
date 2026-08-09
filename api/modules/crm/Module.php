<?php

namespace api\modules\crm;

use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;
use yii\rest\UrlRule;

/**
 * CRM module — client database.
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\modules\crm\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            'PUT v1/clients/<id:\d+>/categories' => 'crm/client/set-categories',
            [
                'class' => UrlRule::class,
                'controller' => ['v1/clients' => 'crm/client'],
                'pluralize' => true,
            ],
            [
                'class' => UrlRule::class,
                'controller' => ['v1/client-categories' => 'crm/client-category'],
                'pluralize' => true,
            ],
        ], false);
    }
}
