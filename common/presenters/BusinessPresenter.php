<?php

namespace common\presenters;

use common\helpers\Categories;
use common\models\Business;
use common\models\BusinessBranch;
use Yii;
use yii\db\Query;

/**
 * Explicit, whitelisted public views of a {@see Business}. Endpoints must never
 * return the Business AR itself (it holds telegram_bot_token, features, tariff).
 */
final class BusinessPresenter
{
    /** Engines whose services must also be online_bookable to count as offered. */
    private const BOOKING_ENGINES = ['slot', 'rental'];

    /** Public storefront profile: exactly the keys GET /v1/site/{slug} has always returned. */
    public static function site(Business $b): array
    {
        return [
            'id' => (int) $b->id,
            'name' => $b->name,
            'slug' => $b->slug,
            'category' => $b->category,
            'phone' => $b->phone,
            'address' => $b->address,
            'map_url' => $b->map_url,
            'timezone' => $b->timezone,
            'online_booking_enabled' => (bool) $b->online_booking_enabled && (bool) $b->is_claimed,
            'is_claimed' => (bool) $b->is_claimed,
            'tagline' => $b->tagline,
            // Branding (nullable) — the public storefront themes itself from these.
            'logo' => $b->logo,
            'cover' => $b->cover,
            'brand_color' => $b->brand_color,
            'brand_color_2' => $b->brand_color_2,
        ];
    }

    /**
     * Directory card. $extra may carry precomputed `price_from_tiyin` and
     * `is_favorite` (batch-computed by the caller to avoid N+1); when absent,
     * price_from_tiyin is computed for this one business and is_favorite=false.
     */
    public static function card(Business $b, array $extra = []): array
    {
        $price = array_key_exists('price_from_tiyin', $extra)
            ? $extra['price_from_tiyin']
            : (self::priceFromMap([$b])[(int) $b->id] ?? null);
        $featuredUntil = $b->featured_until !== null ? (int) $b->featured_until : 0;

        return [
            'id' => (int) $b->id,
            'slug' => $b->slug,
            'name' => $b->name,
            'category' => $b->category,
            'category_label' => Categories::label($b->category),
            'engine' => self::engine($b),
            'tagline' => $b->tagline,
            'logo' => $b->logo,
            'cover' => $b->cover,
            'brand_color' => $b->brand_color,
            'brand_color_2' => $b->brand_color_2,
            'address' => $b->address,
            'city' => $b->city,
            'district' => $b->district,
            'lat' => self::floatOrNull($b->lat),
            'lng' => self::floatOrNull($b->lng),
            'rating_avg' => round((float) $b->rating_avg, 2),
            'rating_count' => (int) $b->rating_count,
            'is_featured' => $featuredUntil > time(),
            'online_booking_enabled' => (bool) $b->online_booking_enabled && (bool) $b->is_claimed,
            'is_claimed' => (bool) $b->is_claimed,
            'price_from_tiyin' => $price !== null ? (int) $price : null,
            'is_favorite' => (bool) ($extra['is_favorite'] ?? false),
        ] + (array_key_exists('branches', $extra)
            ? ['branches' => array_map([self::class, 'branch'], $extra['branches'])]
            : []);
    }

    /** One branch: its name, address and map point. */
    public static function branch(BusinessBranch $br): array
    {
        return [
            'id' => (int) $br->id,
            'name' => $br->name,
            'city' => $br->city,
            'district' => $br->district,
            'address' => $br->address,
            'landmark' => $br->landmark,
            'phone' => $br->phone,
            'hours' => $br->hours,
            'lat' => self::floatOrNull($br->lat),
            'lng' => self::floatOrNull($br->lng),
        ];
    }

    /** Directory detail: card + contact/about fields + opening hours. */
    public static function detail(Business $b, array $extra = []): array
    {
        $extra += ['branches' => BusinessBranch::activeByBusiness([(int) $b->id])[(int) $b->id] ?? []];
        return self::card($b, $extra) + [
            'phone' => $b->phone,
            'map_url' => $b->map_url,
            'description' => $b->description,
            'timezone' => $b->timezone ?: 'Asia/Tashkent',
            'telegram_bot_username' => $b->telegram_bot_username,
            'hours' => self::hours((int) $b->id),
        ];
    }

    /** Compact business block embedded in consumer appointments / orders. */
    public static function consumerSubset(Business $b): array
    {
        return [
            'id' => (int) $b->id,
            'slug' => $b->slug,
            'name' => $b->name,
            'logo' => $b->logo,
            'brand_color' => $b->brand_color,
            'phone' => $b->phone,
            'address' => $b->address,
            'map_url' => $b->map_url,
            'timezone' => $b->timezone ?: 'Asia/Tashkent',
            'engine' => self::engine($b),
        ];
    }

    /** Minimal block {id, slug, name, logo[, brand_color]}. */
    public static function mini(Business $b, bool $withColor = false): array
    {
        $out = [
            'id' => (int) $b->id,
            'slug' => $b->slug,
            'name' => $b->name,
            'logo' => $b->logo,
        ];
        if ($withColor) {
            $out['brand_color'] = $b->brand_color;
        }
        return $out;
    }

    public static function engine(Business $b): string
    {
        return $b->engine ?: 'slot';
    }

    /**
     * MIN(price_tiyin) of offered services per business: active services, and
     * for booking engines (slot/rental) also online_bookable.
     *
     * @param Business[] $businesses
     * @return array<int, int> business_id => min price (missing = none)
     */
    public static function priceFromMap(array $businesses): array
    {
        $booking = [];
        $other = [];
        foreach ($businesses as $b) {
            if (in_array(self::engine($b), self::BOOKING_ENGINES, true)) {
                $booking[] = (int) $b->id;
            } else {
                $other[] = (int) $b->id;
            }
        }
        $out = [];
        $run = static function (array $ids, bool $bookableOnly) use (&$out): void {
            if ($ids === []) {
                return;
            }
            $q = (new Query())
                ->select(['business_id', 'p' => 'MIN(price_tiyin)'])
                ->from('{{%services}}')
                ->where(['business_id' => $ids, 'is_active' => 1])
                ->groupBy('business_id');
            if ($bookableOnly) {
                $q->andWhere(['online_bookable' => 1]);
            }
            foreach ($q->all(Yii::$app->db) as $r) {
                if ($r['p'] !== null) {
                    $out[(int) $r['business_id']] = (int) $r['p'];
                }
            }
        };
        $run($booking, true);
        $run($other, false);
        return $out;
    }

    /**
     * Opening hours per ISO weekday: MIN(start)..MAX(end) over the working hours
     * of active staff. Weekdays without rows are omitted.
     *
     * @return array<int, array{weekday:int, open:string, close:string}>
     */
    public static function hours(int $businessId): array
    {
        $rows = (new Query())
            ->select(['wh.weekday', 'open' => 'MIN(wh.start_time)', 'close' => 'MAX(wh.end_time)'])
            ->from(['wh' => '{{%working_hours}}'])
            ->innerJoin(['s' => '{{%staff}}'], 's.id = wh.staff_id')
            ->where(['s.business_id' => $businessId, 's.is_active' => 1])
            ->groupBy('wh.weekday')
            ->orderBy(['wh.weekday' => SORT_ASC])
            ->all(Yii::$app->db);
        $out = [];
        foreach ($rows as $r) {
            $out[] = [
                'weekday' => (int) $r['weekday'],
                'open' => substr((string) $r['open'], 0, 5),
                'close' => substr((string) $r['close'], 0, 5),
            ];
        }
        return $out;
    }

    private static function floatOrNull($v): ?float
    {
        return $v === null || $v === '' ? null : (float) $v;
    }
}
