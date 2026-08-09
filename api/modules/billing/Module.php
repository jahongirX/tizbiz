<?php

namespace api\modules\billing;

use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;

/**
 * Billing module: deposit initiation, refunds and PSP webhooks (Payme + Click).
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\\modules\\billing\\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            'POST v1/payments/deposit' => 'billing/payment/deposit',
            'POST v1/payments/<id:\d+>/refund' => 'billing/payment/refund',
            'POST v1/webhooks/payme' => 'billing/webhook/payme',
            'POST v1/webhooks/click' => 'billing/webhook/click',
        ], false);
    }
}
