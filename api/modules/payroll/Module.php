<?php

namespace api\modules\payroll;

use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;

/**
 * Payroll module: per-staff earnings from completed appointments.
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\modules\payroll\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            'GET v1/payroll' => 'payroll/payroll/index',
        ], false);
    }
}
