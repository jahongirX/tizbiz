<?php

namespace api\modules\loyalty;

use yii\base\BootstrapInterface;
use yii\base\Module as BaseModule;
use yii\rest\UrlRule;

/**
 * Loyalty module: cashback/points balances, rules, and referrals.
 */
class Module extends BaseModule implements BootstrapInterface
{
    public $controllerNamespace = 'api\modules\loyalty\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            // Loyalty rules CRUD (single active rule per business is the norm).
            [
                'class' => UrlRule::class,
                'controller' => ['v1/loyalty/rules' => 'loyalty/loyalty-rule'],
                'pluralize' => false,
            ],

            // Discount rules CRUD (explicit verbs; the path already ends in 's').
            'GET v1/loyalty/discount-rules' => 'loyalty/discount-rule/index',
            'POST v1/loyalty/discount-rules' => 'loyalty/discount-rule/create',
            'GET v1/loyalty/discount-rules/<id:\d+>' => 'loyalty/discount-rule/view',
            'PATCH v1/loyalty/discount-rules/<id:\d+>' => 'loyalty/discount-rule/update',
            'PUT v1/loyalty/discount-rules/<id:\d+>' => 'loyalty/discount-rule/update',
            'DELETE v1/loyalty/discount-rules/<id:\d+>' => 'loyalty/discount-rule/delete',

            // Auto-category rules CRUD + manual apply. `apply` must precede the
            // <id> rules so it is not swallowed as a resource id.
            'POST v1/loyalty/auto-category-rules/apply' => 'loyalty/auto-category-rule/apply',
            'GET v1/loyalty/auto-category-rules' => 'loyalty/auto-category-rule/index',
            'POST v1/loyalty/auto-category-rules' => 'loyalty/auto-category-rule/create',
            'GET v1/loyalty/auto-category-rules/<id:\d+>' => 'loyalty/auto-category-rule/view',
            'PATCH v1/loyalty/auto-category-rules/<id:\d+>' => 'loyalty/auto-category-rule/update',
            'PUT v1/loyalty/auto-category-rules/<id:\d+>' => 'loyalty/auto-category-rule/update',
            'DELETE v1/loyalty/auto-category-rules/<id:\d+>' => 'loyalty/auto-category-rule/delete',

            // Loyalty settings (flat view over the active loyalty rule).
            'GET v1/loyalty/settings' => 'loyalty/settings/view',
            'PUT v1/loyalty/settings' => 'loyalty/settings/update',

            // Gift certificates CRUD (explicit verbs; the path already ends in 's').
            'GET v1/certificates' => 'loyalty/certificate/index',
            'POST v1/certificates' => 'loyalty/certificate/create',
            'GET v1/certificates/<id:\d+>' => 'loyalty/certificate/view',
            'PATCH v1/certificates/<id:\d+>' => 'loyalty/certificate/update',
            'PUT v1/certificates/<id:\d+>' => 'loyalty/certificate/update',
            'DELETE v1/certificates/<id:\d+>' => 'loyalty/certificate/delete',

            // Subscription / pass types CRUD.
            'GET v1/subscription-types' => 'loyalty/subscription-type/index',
            'POST v1/subscription-types' => 'loyalty/subscription-type/create',
            'GET v1/subscription-types/<id:\d+>' => 'loyalty/subscription-type/view',
            'PATCH v1/subscription-types/<id:\d+>' => 'loyalty/subscription-type/update',
            'PUT v1/subscription-types/<id:\d+>' => 'loyalty/subscription-type/update',
            'DELETE v1/subscription-types/<id:\d+>' => 'loyalty/subscription-type/delete',

            // Client deposits. The non-numeric `balances` route and the POST must
            // precede the <clientId> rule so they are not swallowed as a client id.
            'GET v1/deposits/balances' => 'loyalty/deposit/balances',
            'POST v1/deposits' => 'loyalty/deposit/create',
            'GET v1/deposits/<clientId:\d+>' => 'loyalty/deposit/view',

            // Referrals.
            'GET v1/referrals' => 'loyalty/referral/index',
            'POST v1/referrals' => 'loyalty/referral/create',
            'POST v1/referrals/<id:\d+>/credit' => 'loyalty/referral/credit',

            // Manual earn / redeem.
            'POST v1/loyalty/earn' => 'loyalty/loyalty/earn',
            'POST v1/loyalty/redeem' => 'loyalty/loyalty/redeem',

            // Per-client account + recent ledger.
            'GET v1/loyalty/<clientId:\d+>' => 'loyalty/loyalty/view',
        ], false);
    }
}
