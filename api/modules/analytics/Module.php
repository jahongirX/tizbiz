<?php

namespace api\modules\analytics;

use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;

/**
 * Analytics module — tenant-scoped business dashboards (revenue, appointments,
 * clients, per-day series, top services, staff load).
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\modules\analytics\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            'GET v1/analytics/overview' => 'analytics/analytics/overview',
        ], false);
    }
}
