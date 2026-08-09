<?php
$params = require __DIR__ . '/../../common/config/params.php';

return [
    'id' => 'navbat-console',
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
    'controllerMap' => [
        'migrate' => [
            'class' => \yii\console\controllers\MigrateController::class,
            'migrationPath' => '@console/migrations',
        ],
    ],
    'params' => $params,
];
