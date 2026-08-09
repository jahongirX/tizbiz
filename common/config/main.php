<?php
/**
 * Shared application config merged into every app (api, console).
 * App-specific config lives in {api,console}/config/main.php.
 */
return [
    'language' => 'uz-UZ',
    'aliases' => [
        '@bower' => '@vendor/bower-asset',
        '@npm' => '@vendor/npm-asset',
    ],
    'components' => [
        'db' => require __DIR__ . '/db.php',
        'cache' => [
            'class' => \yii\caching\FileCache::class,
        ],
        'tenant' => [
            'class' => \common\components\TenantContext::class,
        ],
        'security' => [
            // bcrypt cost 13 is ~4.7s on some (MAMP) PHP builds; 10 (~0.5s) is a
            // sane local default. New/rehashed passwords use this cost.
            'passwordHashCost' => (int) (getenv('PASSWORD_HASH_COST') ?: 10),
        ],
        'i18n' => [
            'translations' => [
                'yii' => [
                    'class' => \yii\i18n\PhpMessageSource::class,
                    'basePath' => '@common/messages',
                    'sourceLanguage' => 'en-US',
                    'forceTranslation' => true,
                ],
            ],
        ],
    ],
];
