<?php

namespace common\rbac;

use common\models\Business;

/**
 * Per-role permission keys, mirroring the role matrix of docs/mobile/BACKEND-PLAN.md §2.9.
 *
 * This is descriptive data for clients (returned by /v1/auth/me, login and
 * switch so apps can hide what the role cannot use). Enforcement stays in the
 * controllers (requireRole + tenant->require()).
 */
final class Permissions
{
    public const ALL = [
        'appointments.all',
        'appointments.manage',
        'orders',
        'clients',
        'analytics',
        'finance',
        'payroll',
        'loyalty',
        'inventory',
        'catalog.manage',
        'team.read',
        'team.manage',
        'settings.manage',
        'reviews',
        'uploads',
        'me',
    ];

    /** Exactly the staff shell: orders board + /v1/me/*. */
    public const STAFF = ['orders', 'me'];

    /**
     * @return string[] permission keys of $role (unknown or null role => []).
     */
    public static function forRole(?string $role): array
    {
        switch ($role) {
            case Business::ROLE_OWNER:
                return self::ALL;
            case Business::ROLE_ADMIN:
                return array_values(array_diff(self::ALL, ['team.manage']));
            case Business::ROLE_STAFF:
                return self::STAFF;
            default:
                return [];
        }
    }
}
