<?php
$params = require __DIR__ . '/../../common/config/params.php';

return [
    'id' => 'tizbiz-console',
    'basePath' => dirname(__DIR__),
    'controllerNamespace' => 'console\\controllers',
    'aliases' => [
        '@console' => dirname(__DIR__),
    ],
    'components' => [
        'log' => [
            'targets' => [
                [
                    'class' => \yii\log\FileTarget::class,
                    'levels' => ['error', 'warning'],
                ],
            ],
        ],
    ],
    // Console-side auto-complete finishes appointments too, so cashback must be
    // awarded there exactly as it is in the API.
    'on appointmentCompleted' => [\api\modules\loyalty\services\LoyaltyService::class, 'onAppointmentCompleted'],
    'controllerMap' => [
        'migrate' => [
            'class' => \yii\console\controllers\MigrateController::class,
            'migrationPath' => '@console/migrations',
        ],
    ],
    'params' => $params,
];
