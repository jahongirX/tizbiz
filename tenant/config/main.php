<?php
$params = require __DIR__ . '/../../common/config/params.php';

return [
    'id' => 'navbat-tenant',
    'basePath' => dirname(__DIR__),
    'controllerNamespace' => 'tenant\\controllers',
    'aliases' => [
        '@tenant' => dirname(__DIR__),
    ],
    'components' => [
        'request' => [
            'enableCookieValidation' => false,
            'enableCsrfValidation' => false,
        ],
        'errorHandler' => [
            'errorAction' => 'site/index',
        ],
        'urlManager' => [
            'enablePrettyUrl' => true,
            'showScriptName' => false,
            'rules' => [
                '' => 'site/index',
                '<path:.*>' => 'site/index', // SPA history fallback
            ],
        ],
    ],
    'params' => $params,
];
