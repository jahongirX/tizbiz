<?php

namespace common\engines;

/**
 * Rental vertical (wedding dresses / suit rental). Its real flow is an item
 * calendar + deposit + return (Phase 3). Until that is built it reuses the slot
 * booking behaviour so the public page and admin keep working; only the
 * identity (key/label) differs. Phase 3 overrides the contract for rentals.
 */
class RentalEngine extends SlotEngine
{
    public static function key(): string
    {
        return 'rental';
    }

    public function label(): string
    {
        return 'Ijara (ko\'ylak / kostyum)';
    }
}
