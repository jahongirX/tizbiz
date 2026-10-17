<?php

namespace api\modules\directory;

use common\components\ConsumerAuth;
use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;

/**
 * Bizcat business directory (/v1/directory/*): categories, searchable business
 * list, business detail and public reviews. Anonymous or consumer token
 * (a consumer token only adds is_favorite); business tokens count as anonymous.
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\\modules\\directory\\controllers';

    public function bootstrap($app): void
    {
        ConsumerAuth::userComponent();

        // The more specific /reviews rule must come before the detail rule.
        $app->getUrlManager()->addRules([
            'GET v1/directory/categories' => 'directory/directory/categories',
            'GET v1/directory/businesses' => 'directory/directory/index',
            'GET v1/directory/map' => 'directory/directory/map',
            'GET v1/directory/businesses/<slug:[a-z0-9-]+>/reviews' => 'directory/directory/reviews',
            'GET v1/directory/businesses/<slug:[a-z0-9-]+>' => 'directory/directory/view',
        ], false);
    }
}
