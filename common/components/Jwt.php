<?php

namespace common\components;

use Firebase\JWT\JWT as FirebaseJwt;
use Firebase\JWT\Key;
use Yii;

/**
 * Thin wrapper around firebase/php-jwt. Signs and verifies HS256 access tokens
 * carrying the user id (`sub`) and the acting tenant (`tid`) so downstream
 * request handling can scope queries by tenant.
 */
class Jwt
{
    public static function secret(): string
    {
        return (string) Yii::$app->params['jwt.secret'];
    }

    /**
     * @param int $userId
     * @param int|null $tenantId active business (tenant) id, if any
     * @param string|null $role the user's role in that tenant (business_owner/business_admin/staff…)
     */
    public static function issue(int $userId, ?int $tenantId = null, ?string $role = null): string
    {
        $now = time();
        $payload = [
            'iss' => Yii::$app->params['jwt.issuer'],
            'iat' => $now,
            'exp' => $now + (int) Yii::$app->params['jwt.ttl'],
            'sub' => $userId,
            'tid' => $tenantId,
            'role' => $role,
        ];

        return FirebaseJwt::encode($payload, self::secret(), 'HS256');
    }

    /**
     * Verify a token and return its payload, or null if invalid/expired.
     */
    public static function parse(string $token): ?array
    {
        try {
            $decoded = FirebaseJwt::decode($token, new Key(self::secret(), 'HS256'));
            return (array) $decoded;
        } catch (\Throwable $e) {
            return null;
        }
    }
}
