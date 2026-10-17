<?php

namespace common\presenters;

use common\models\Staff;

/**
 * Public (storefront / consumer) view of a staff member. Never exposes
 * user_id, commission_percent, business_id or timestamps.
 */
final class StaffPresenter
{
    /** @return array{id:int, name:string, specialization:?string} */
    public static function public(Staff $s): array
    {
        return [
            'id' => (int) $s->id,
            'name' => (string) $s->name,
            'specialization' => $s->specialization !== null && $s->specialization !== '' ? (string) $s->specialization : null,
        ];
    }

    /** @return array{id:int, name:string} */
    public static function short(Staff $s): array
    {
        return ['id' => (int) $s->id, 'name' => (string) $s->name];
    }
}
