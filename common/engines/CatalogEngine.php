<?php

namespace common\engines;

/**
 * Catalog vertical (cafe / restaurant / cakes / sweets). Its real flow is a
 * menu + orders (Phase 2). Until that is built it reuses the slot booking
 * behaviour so the public page and admin keep working; only the identity
 * (key/label) differs. Phase 2 overrides publicData()/offerings() for a menu.
 */
class CatalogEngine extends SlotEngine
{
    public static function key(): string
    {
        return 'catalog';
    }

    public function label(): string
    {
        return 'Kafe / Restoran / Shirinliklar';
    }
}
