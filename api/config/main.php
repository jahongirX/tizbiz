<?php
$params = require __DIR__ . '/../../common/config/params.php';

return [
    'id' => 'tizbiz-api',
    'basePath' => dirname(__DIR__),
    'controllerNamespace' => 'api\\controllers',
    'aliases' => [
        '@api' => dirname(__DIR__),
    ],
    // Listing a module id in bootstrap triggers its Module::bootstrap(), which
    // self-registers that module's REST URL rules.
    'bootstrap' => ['log', 'auth', 'booking', 'crm', 'loyalty', 'billing', 'notify', 'site', 'analytics', 'finance', 'payroll', 'inventory'],
    // When an appointment is completed, credit loyalty cashback for the client.
    'on appointmentCompleted' => [\api\modules\loyalty\services\LoyaltyService::class, 'onAppointmentCompleted'],
    // Answer CORS preflight (OPTIONS) before verb-scoped routing can 404 it.
    'on beforeRequest' => [\common\rest\Cors::class, 'preflight'],
    'components' => [
        'request' => [
            'enableCookieValidation' => false,
            'enableCsrfValidation' => false,
            'parsers' => [
                'application/json' => \yii\web\JsonParser::class,
            ],
        ],
        'response' => [
            'format' => \yii\web\Response::FORMAT_JSON,
            'on beforeSend' => [\common\rest\Envelope::class, 'onBeforeSend'],
        ],
        'user' => [
            'identityClass' => \common\models\User::class,
            'enableAutoLogin' => false,
            'enableSession' => false,
            'loginUrl' => null,
        ],
        'errorHandler' => [
            'errorAction' => null,
        ],
        'log' => [
            'targets' => [
                [
                    'class' => \yii\log\FileTarget::class,
                    'levels' => ['error', 'warning'],
                ],
            ],
        ],
        'urlManager' => [
            'enablePrettyUrl' => true,
            'enableStrictParsing' => true,
            'showScriptName' => false,
            'rules' => [
                // REST rules are contributed per module (booking, crm, billing…).
            ],
        ],
    ],
    'modules' => [
        'auth' => ['class' => \api\modules\auth\Module::class],
        'booking' => ['class' => \api\modules\booking\Module::class],
        'crm' => ['class' => \api\modules\crm\Module::class],
        'loyalty' => ['class' => \api\modules\loyalty\Module::class],
        'billing' => ['class' => \api\modules\billing\Module::class],
        'notify' => ['class' => \api\modules\notify\Module::class],
        'site' => ['class' => \api\modules\site\Module::class],
        'analytics' => ['class' => \api\modules\analytics\Module::class],
        'finance' => ['class' => \api\modules\finance\Module::class],
        'payroll' => ['class' => \api\modules\payroll\Module::class],
        'inventory' => ['class' => \api\modules\inventory\Module::class],
    ],
    'params' => $params,
];
