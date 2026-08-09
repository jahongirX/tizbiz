<?php
/**
 * Database connection. Configured via environment variables so the same code
 * runs on local, cPanel and VPS without editing committed files.
 */
return [
    'class' => \yii\db\Connection::class,
    'dsn' => getenv('DB_DSN') ?: 'mysql:host=127.0.0.1;dbname=navbat',
    'username' => getenv('DB_USER') ?: 'root',
    'password' => getenv('DB_PASSWORD') ?: '',
    'charset' => 'utf8mb4',
    'enableSchemaCache' => YII_ENV_PROD,
    'schemaCacheDuration' => 3600,
];
