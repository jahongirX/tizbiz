<?php

namespace common\components;

use Firebase\JWT\JWT as FirebaseJwt;
use Firebase\JWT\Key;
use Yii;

/**
 * Thin wrapper around firebase/php-jwt. Signs and verifies HS256 access tokens
 * carrying the subject id (`sub`), the acting tenant (`tid`), the tenant role
 * and the token type (`typ`) so downstream request handling can scope queries
 * by tenant and reject tokens of the wrong kind.
 *
 * Token types:
 *  - `biz`      business user (users table); legacy tokens without `typ` are `biz`
 *  - `consumer` Bizcat consumer (consumer_users table)
 */
class Jwt
{
    public const TYP_BIZ = 'biz';
    public const TYP_CONSUMER = 'consumer';

    public static function secret(): string
    {
        return (string) Yii::$app->params['jwt.secret'];
    }

    /**
     * @param int $userId subject id (users.id for biz, consumer_users.id for consumer)
     * @param int|null $tenantId active business (tenant) id, if any
     * @param string|null $role the user's role in that tenant (business_owner/business_admin/staff…)
     * @param string $typ token type, see TYP_* constants
     * @param int|null $ttl lifetime in seconds; null => params['jwt.ttl'] (7 days)
     */
    public static function issue(
        int $userId,
        ?int $tenantId = null,
        ?string $role = null,
        string $typ = self::TYP_BIZ,
        ?int $ttl = null
    ): string {
        $now = time();
        $payload = [
            'iss' => Yii::$app->params['jwt.issuer'],
            'iat' => $now,
            'exp' => $now + self::ttl($ttl),
            'sub' => $userId,
            'tid' => $tenantId,
            'role' => $role,
            'typ' => $typ,
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

    /**
     * Token type from a parsed payload; a missing typ means a legacy business token.
     */
    public static function typ(array $payload): string
    {
        $typ = $payload['typ'] ?? null;
        return is_string($typ) && $typ !== '' ? $typ : self::TYP_BIZ;
    }

    /**
     * exp of a freshly issued token, for responses: time() + ($ttl ?? params['jwt.ttl']).
     */
    public static function expiresAt(?int $ttl = null): int
    {
        return time() + self::ttl($ttl);
    }

    private static function ttl(?int $ttl): int
    {
        return $ttl ?? (int) Yii::$app->params['jwt.ttl'];
    }
}
