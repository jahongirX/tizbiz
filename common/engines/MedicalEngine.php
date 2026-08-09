<?php

namespace common\engines;

/**
 * Medical vertical (clinic / UZI / dentistry). Genuinely appointment-based, so
 * it reuses the slot booking behaviour; only the identity differs. Phase 2+ may
 * add patient records / prescriptions by overriding more of the contract.
 */
class MedicalEngine extends SlotEngine
{
    public static function key(): string
    {
        return 'medical';
    }

    public function label(): string
    {
        return 'Klinika / Tibbiyot';
    }
}
