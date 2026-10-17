<?php

namespace common\helpers;

use Yii;
use yii\db\Connection;

/**
 * Named advisory locks (GET_LOCK / RELEASE_LOCK) on the main DB connection.
 * Works on MySQL 5.7+ and MariaDB 10.0.2+ (both allow several locks per
 * session). The lock belongs to the DB session, so it serializes concurrent
 * PHP workers; it is released explicitly or when the connection closes.
 *
 * Names are hashed so they always fit the 64-character limit.
 */
final class DbLock
{
    private static function name(string $key): string
    {
        return 'tb:' . sha1($key);
    }

    /** True when the lock was obtained within $timeout seconds. */
    public static function acquire(string $key, int $timeout = 5, ?Connection $db = null): bool
    {
        $db = $db ?? Yii::$app->db;
        $got = $db->createCommand('SELECT GET_LOCK(:k, :t)', [':k' => self::name($key), ':t' => max(0, $timeout)])
            ->queryScalar();
        return (int) $got === 1;
    }

    public static function release(string $key, ?Connection $db = null): void
    {
        $db = $db ?? Yii::$app->db;
        try {
            $db->createCommand('SELECT RELEASE_LOCK(:k)', [':k' => self::name($key)])->queryScalar();
        } catch (\Throwable $e) {
            Yii::warning('RELEASE_LOCK failed: ' . $e->getMessage(), 'db');
        }
    }
}
