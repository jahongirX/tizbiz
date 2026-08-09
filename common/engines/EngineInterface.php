<?php

namespace common\engines;

use common\models\Business;

/**
 * Stable contract for a business "engine" (vertical). Selected per business by
 * its `engine` field via {@see EngineFactory}. New engines (catalog/rental/
 * medical…) implement this same interface so a single codebase serves every
 * vertical. DO NOT change this contract lightly — engines depend on it.
 */
interface EngineInterface
{
    /** Machine key stored in businesses.engine (e.g. 'slot'). */
    public static function key(): string;

    /** Human label (Uzbek). */
    public function label(): string;

    /**
     * Public storefront payload for {slug}.tizbiz.uz — everything the public
     * page needs to render for this vertical.
     */
    public function publicData(Business $business): array;

    /** What the business offers/sells (services, products, items…). */
    public function offerings(Business $business): array;
}
