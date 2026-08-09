<?php

namespace api\modules\finance;

use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;

/**
 * Finance module: tenant-scoped money reporting over the transactions ledger.
 *
 * GET /v1/finance/summary       income / refunds / net + by-provider breakdown.
 * GET /v1/finance/transactions  paginated ledger with client & service names.
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\\modules\\finance\\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            'GET v1/finance/summary' => 'finance/finance/summary',
            'GET v1/finance/transactions' => 'finance/finance/transactions',
        ], false);
    }
}
