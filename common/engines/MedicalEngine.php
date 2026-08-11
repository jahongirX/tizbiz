<?php

namespace common\engines;

/**
 * Medical vertical (clinic / UZI / dentistry). Presents the same web-catalog
 * storefront as the food engine (services grouped by category, with photos),
 * only under its own identity + blue theme. It inherits CatalogEngine's
 * catalog publicData()/offerings() (and, through it, the slot booking
 * behaviour) so a clinic browses like a catalog. Phase 2+ may add patient
 * records / prescriptions by overriding more of the contract.
 */
class MedicalEngine extends CatalogEngine
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
