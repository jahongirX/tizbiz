<?php

namespace common\engines;

use common\models\Business;
use common\models\Service;
use common\models\ServiceCategory;
use common\models\Staff;

/**
 * The slot / online-booking engine (barber, salon, dentistry, clinic…). This is
 * the vertical the whole current system implements; here it is simply *wrapped*
 * behind {@see EngineInterface} — the existing booking/site logic is unchanged
 * and still reachable directly. Nothing is moved or removed (additive refactor).
 */
class SlotEngine implements EngineInterface
{
    public static function key(): string
    {
        return 'slot';
    }

    public function label(): string
    {
        return 'Onlayn navbat';
    }

    /**
     * Mirrors the public site payload (see api\modules\site SiteController):
     * business profile + online-bookable services + active staff, honoring the
     * online_booking_enabled flag.
     */
    public function publicData(Business $business): array
    {
        $enabled = (bool) $business->online_booking_enabled;

        return [
            'engine' => static::key(),
            'business' => $this->businessPayload($business),
            'services' => $enabled ? $this->offerings($business) : [],
            'staff' => $enabled
                ? Staff::find()->where(['business_id' => $business->id, 'is_active' => 1])->all()
                : [],
            // Flat list plus the sections it belongs to: the booking page groups
            // a long menu ("Soch olish", "Soqol va yuz") instead of scrolling one
            // undifferentiated column. Additive — a client that ignores it sees
            // exactly the previous payload.
            'service_categories' => $enabled ? $this->serviceCategories($business) : [],
        ];
    }

    /** @return array<int, array{id:int,name:string,sort:int}> ordered sections */
    protected function serviceCategories(Business $business): array
    {
        $rows = ServiceCategory::find()
            ->where(['business_id' => $business->id])
            ->orderBy(['sort' => SORT_ASC, 'id' => SORT_ASC])
            ->all();

        return array_map(static fn (ServiceCategory $c) => [
            'id' => (int) $c->id,
            'name' => $c->name,
            'sort' => (int) $c->sort,
        ], $rows);
    }

    /** Shared public business profile (reused by sibling engines). */
    protected function businessPayload(Business $business): array
    {
        return [
            'id' => (int) $business->id,
            'name' => $business->name,
            'slug' => $business->slug,
            'category' => $business->category,
            'phone' => $business->phone,
            'timezone' => $business->timezone,
            'online_booking_enabled' => (bool) $business->online_booking_enabled,
            'tagline' => $business->tagline,
            // Branding (nullable) — the public storefront themes itself from these.
            'logo' => $business->logo,
            'cover' => $business->cover,
            'brand_color' => $business->brand_color,
            'brand_color_2' => $business->brand_color_2,
        ];
    }

    /** Online-bookable, active services of the business. */
    public function offerings(Business $business): array
    {
        return Service::find()
            ->where(['business_id' => $business->id, 'is_active' => 1, 'online_bookable' => 1])
            ->all();
    }
}
