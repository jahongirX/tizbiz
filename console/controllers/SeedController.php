<?php

namespace console\controllers;

use common\models\Appointment;
use common\models\AutoCategoryRule;
use common\models\Business;
use common\models\BusinessUser;
use common\models\Certificate;
use common\models\Client;
use common\models\ClientCategory;
use common\models\ClientCategoryAssignment;
use common\models\DepositTransaction;
use common\models\DiscountRule;
use common\models\LoyaltyAccount;
use common\models\LoyaltyRule;
use common\models\LoyaltyTransaction;
use common\models\Order;
use common\models\OrderItem;
use common\models\Service;
use common\models\ServiceCategory;
use common\models\Staff;
use common\models\SubscriptionType;
use common\models\Transaction;
use common\models\User;
use common\models\WorkingHours;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\db\ActiveRecord;

/**
 * Demo data for local testing of the Phase 1 loop.
 * Usage: php yii seed/demo   (run against a fresh, migrated database)
 */
class SeedController extends Controller
{
    public function actionDemo(): int
    {
        $owner = $this->save(new User([
            'phone' => '+998900000001',
            'name' => 'Demo Owner',
            'status' => User::STATUS_ACTIVE,
        ]), fn(User $u) => $u->setPassword('secret123'));

        $business = $this->save(new Business([
            'name' => 'Demo Klinika',
            'slug' => 'demo',
            'phone' => '+998900000001',
            'category' => 'clinic',
            'tariff' => 'free',
            'timezone' => 'Asia/Tashkent',
            'status' => 10,
        ]));

        $this->save(new BusinessUser([
            'business_id' => $business->id,
            'user_id' => $owner->id,
            'role' => 'business_owner',
        ]));

        $staff = $this->save(new Staff([
            'business_id' => $business->id,
            'name' => 'Dr. Aziz',
            'specialization' => 'Stomatolog',
            'is_active' => 1,
        ]));

        for ($weekday = 1; $weekday <= 6; $weekday++) { // Mon..Sat
            $this->save(new WorkingHours([
                'staff_id' => $staff->id,
                'weekday' => $weekday,
                'start_time' => '09:00:00',
                'end_time' => '18:00:00',
            ]));
        }

        $category = $this->save(new ServiceCategory([
            'business_id' => $business->id,
            'name' => 'Stomatologiya',
            'sort' => 0,
        ]));

        $service = $this->save(new Service([
            'business_id' => $business->id,
            'category_id' => $category->id,
            'name' => 'Konsultatsiya',
            'duration_min' => 30,
            'price_tiyin' => 5000000,   // 50 000 so'm
            'deposit_tiyin' => 1000000, // 10 000 so'm
            'is_active' => 1,
        ]));

        $client = $this->save(new Client([
            'business_id' => $business->id,
            'name' => 'Ali Valiyev',
            'phone' => '+998901112233',
            'tags' => [],
        ]));

        $this->save(new LoyaltyRule([
            'business_id' => $business->id,
            'earn_rate' => 500, // 5% (basis points)
            'active' => 1,
            'gift_config' => [
                'referral_bonus_tiyin' => 2000000, // 20 000 so'm to the referrer
                'referral_bonus_points' => 20,
            ],
        ]));

        $this->stdout("Seeded demo data:\n");
        $this->stdout(sprintf(
            "  owner_id=%d business_id=%d staff_id=%d category_id=%d service_id=%d client_id=%d\n",
            $owner->id, $business->id, $staff->id, $category->id, $service->id, $client->id
        ));
        $this->stdout("  login: phone=+998900000001 password=secret123\n");

        return ExitCode::OK;
    }

    /**
     * Add sample clients + a week of appointments to the demo business, so the
     * timetable and client base are not empty. Idempotent: skips if already run.
     * Usage: php yii seed/sample
     */
    public function actionSample(): int
    {
        $business = \common\models\Business::findOne(['slug' => 'demo']);
        if ($business === null) {
            $this->stderr("Run seed/demo first.\n");
            return ExitCode::UNSPECIFIED_ERROR;
        }
        $bid = (int) $business->id;
        if (\common\models\Client::find()->where(['business_id' => $bid])->count() > 2) {
            $this->stdout("Sample data already present; skipping.\n");
            return ExitCode::OK;
        }
        $staff = \common\models\Staff::findOne(['business_id' => $bid]);
        $service = \common\models\Service::findOne(['business_id' => $bid]);
        if ($staff === null || $service === null) {
            $this->stderr("Demo staff/service missing.\n");
            return ExitCode::UNSPECIFIED_ERROR;
        }

        $people = [
            ['Aziz Karimov', '+998901234501'],
            ['Dilnoza Yusupova', '+998901234502'],
            ['Sardor Aliyev', '+998901234503'],
            ['Nigora Rashidova', '+998901234504'],
            ['Jasur Toshpulatov', '+998901234505'],
            ['Malika Ergasheva', '+998901234506'],
        ];
        $clients = [];
        foreach ($people as [$name, $phone]) {
            $c = new \common\models\Client([
                'business_id' => $bid, 'name' => $name, 'phone' => $phone, 'tags' => [],
            ]);
            $c->save(false);
            $clients[] = $c;
        }

        // Appointments Mon..Sat of the current week, 09:00 local (04:00 UTC) onward.
        // Past days -> completed, today/future -> confirmed.
        $weekMondayUtc = strtotime(gmdate('Y-m-d', strtotime('monday this week')) . ' 04:00:00 UTC');
        $nowTs = time();
        $dur = (int) $service->duration_min;
        $made = 0;
        for ($i = 0; $i < 12; $i++) {
            $day = $i % 6;                 // Mon..Sat
            $hour = ($i % 8);              // 0..7 -> 04:00..11:00 UTC (09:00..16:00 local)
            $startTs = $weekMondayUtc + $day * 86400 + $hour * 3600;
            $client = $clients[$i % count($clients)];
            $appt = new \common\models\Appointment([
                'business_id' => $bid,
                'client_id' => $client->id,
                'staff_id' => $staff->id,
                'service_id' => $service->id,
                'starts_at' => gmdate('Y-m-d H:i:s', $startTs),
                'ends_at' => gmdate('Y-m-d H:i:s', $startTs + $dur * 60),
                'status' => $startTs < $nowTs
                    ? \common\models\Appointment::STATUS_COMPLETED
                    : \common\models\Appointment::STATUS_CONFIRMED,
                'source' => 'admin',
            ]);
            $appt->save(false);
            $made++;
        }

        $this->stdout(sprintf("Added %d clients and %d appointments to demo.\n", count($clients), $made));
        return ExitCode::OK;
    }

    /**
     * Seed one demo business per vertical (barber / cafe / clinic / rental), each
     * with its engine, category and vertical-appropriate sample data, so the
     * per-vertical demo logins each open into a matching, non-empty admin.
     * Idempotent: skips a vertical whose slug already exists.
     * Usage: php yii seed/verticals
     */
    public function actionVerticals(): int
    {
        $defs = [
            [
                'slug' => 'barber', 'name' => 'Aziza Beauty', 'category' => 'barber', 'engine' => 'slot',
                'phone' => '+998901111111', 'owner' => 'Aziza Karimova', 'staff_count' => 3, 'branches' => 1,
                'staff' => ['Usta Jahongir', 'Sartarosh'], 'cat' => 'Sartaroshxona',
                'service' => ['Soch olish', 30, 5000000, 1000000],
            ],
            [
                'slug' => 'tort', 'name' => 'Shirin Tort', 'category' => 'cafe', 'engine' => 'catalog',
                'phone' => '+998902222222', 'owner' => 'Dilnoza Yusupova', 'staff_count' => 5, 'branches' => 2,
                'staff' => ['Oshpaz Dilnoza', 'Qandolatchi'], 'cat' => 'Shirinliklar',
                'service' => ['Napoleon tort (1kg)', 60, 15000000, 5000000],
            ],
            [
                // Food / restaurant — same catalog storefront as the cake shop.
                'slug' => 'restoran', 'name' => 'Milliy Taomlar', 'category' => 'restaurant', 'engine' => 'catalog',
                'phone' => '+998905555555', 'owner' => 'Bekzod Rahimov', 'staff_count' => 12, 'branches' => 3,
                'staff' => ['Oshpaz Bekzod', 'Ofitsiant'], 'cat' => 'Milliy taomlar',
                'service' => ['Osh (palov)', 30, 3500000, 0],
            ],
            [
                'slug' => 'klinika', 'name' => 'Sog\'lom Oila Klinikasi', 'category' => 'clinic', 'engine' => 'medical',
                'phone' => '+998903333333', 'owner' => 'Dr. Sardor', 'staff_count' => 8, 'branches' => 1,
                'staff' => ['Dr. Aziza', 'Shifokor'], 'cat' => 'Diagnostika',
                'service' => ['UZI tekshiruvi', 30, 8000000, 2000000],
            ],
            [
                'slug' => 'ijara', 'name' => 'Malika Kelin Salon', 'category' => 'rental', 'engine' => 'rental',
                'phone' => '+998904444444', 'owner' => 'Malika Ergasheva', 'staff_count' => 2, 'branches' => 1,
                'staff' => ['Menejer Malika', 'Stilist'], 'cat' => 'Ijara buyumlari',
                'service' => ['Kelin ko\'ylagi (1 kun)', 60, 30000000, 10000000],
            ],
        ];

        foreach ($defs as $d) {
            if (Business::find()->where(['slug' => $d['slug']])->exists()) {
                $this->stdout("  skip {$d['slug']} (already exists)\n");
                continue;
            }

            $owner = User::findOne(['phone' => $d['phone']]);
            if ($owner === null) {
                $owner = $this->save(new User([
                    'phone' => $d['phone'], 'name' => $d['owner'], 'status' => User::STATUS_ACTIVE,
                ]), fn (User $u) => $u->setPassword('secret123'));
            }

            $business = $this->save(new Business([
                'name' => $d['name'], 'slug' => $d['slug'], 'phone' => $d['phone'],
                'category' => $d['category'], 'engine' => $d['engine'],
                'staff_count' => $d['staff_count'], 'branches_count' => $d['branches'],
                'tariff' => 'free', 'timezone' => 'Asia/Tashkent', 'status' => 10,
            ]));

            $this->save(new BusinessUser([
                'business_id' => $business->id, 'user_id' => $owner->id, 'role' => 'business_owner',
            ]));

            $staff = $this->save(new Staff([
                'business_id' => $business->id, 'name' => $d['staff'][0],
                'specialization' => $d['staff'][1], 'is_active' => 1,
            ]));
            for ($weekday = 1; $weekday <= 6; $weekday++) {
                $this->save(new WorkingHours([
                    'staff_id' => $staff->id, 'weekday' => $weekday,
                    'start_time' => '09:00:00', 'end_time' => '18:00:00',
                ]));
            }

            $category = $this->save(new ServiceCategory([
                'business_id' => $business->id, 'name' => $d['cat'], 'sort' => 0,
            ]));
            $this->save(new Service([
                'business_id' => $business->id, 'category_id' => $category->id,
                'name' => $d['service'][0], 'duration_min' => $d['service'][1],
                'price_tiyin' => $d['service'][2], 'deposit_tiyin' => $d['service'][3], 'is_active' => 1,
            ]));

            $this->stdout(sprintf(
                "  seeded %-8s business_id=%d  login: %s / secret123\n",
                $d['slug'], $business->id, $d['phone']
            ));
        }

        $this->stdout("Vertical demos ready.\n");
        return ExitCode::OK;
    }

    /**
     * Enrich the catalog demo (slug `tort`) with a multi-category menu so the
     * storefront looks real. Idempotent: skips if the menu already has >1 item.
     * Usage: php yii seed/catalog-menu
     */
    public function actionCatalogMenu(): int
    {
        $business = Business::findOne(['slug' => 'tort']);
        if ($business === null) {
            $this->stderr("Run seed/verticals first (needs the 'tort' business).\n");
            return ExitCode::UNSPECIFIED_ERROR;
        }
        $bid = (int) $business->id;
        if (Service::find()->where(['business_id' => $bid])->count() >= 8) {
            $this->stdout("Catalog menu already present; skipping.\n");
            return ExitCode::OK;
        }

        // category => [ [name, price_so'm], ... ]  (duration is irrelevant here)
        $menu = [
            'Tortlar' => [
                ['Napoleon tort (1kg)', 150000], ['Medovik tort (1kg)', 160000],
                ['Chizkeyk (1kg)', 180000], ['Shokoladli tort (1kg)', 170000],
            ],
            'Shirinliklar' => [
                ['Ekler (6 dona)', 45000], ['Makaron (6 dona)', 60000],
                ['Pirojnoye', 15000], ['Kruassan', 20000],
            ],
            'Ichimliklar' => [
                ['Amerikano', 22000], ['Kapuchino', 28000],
                ['Choy (choynak)', 15000], ['Fresh apelsin', 30000],
            ],
            'Kombo' => [
                ['Tort bo\'lagi + kofe', 40000], ['2 ta ekler + choy', 55000],
            ],
        ];

        $sort = 0;
        $items = 0;
        foreach ($menu as $catName => $rows) {
            // find-or-create the category (idempotent, tolerates a partial prior run)
            $category = ServiceCategory::findOne(['business_id' => $bid, 'name' => $catName])
                ?? $this->save(new ServiceCategory([
                    'business_id' => $bid, 'name' => $catName, 'sort' => $sort,
                ]));
            $sort++;
            foreach ($rows as [$name, $som]) {
                if (Service::find()->where(['business_id' => $bid, 'name' => $name])->exists()) {
                    continue;
                }
                $this->save(new Service([
                    'business_id' => $bid, 'category_id' => $category->id, 'name' => $name,
                    'duration_min' => 30, 'price_tiyin' => $som * 100, 'deposit_tiyin' => 0, 'is_active' => 1,
                ]));
                $items++;
            }
        }

        $this->stdout(sprintf("Added %d menu items across %d categories to '%s'.\n", $items, count($menu), $business->name));
        return ExitCode::OK;
    }

    /**
     * Generate a placeholder photo for every menu item of the catalog demo
     * (slug `tort`) — an appetising gradient card with the dish name — and
     * attach it. Self-contained (GD + a system font), no external images.
     * Usage: php yii seed/catalog-images
     */
    public function actionCatalogImages(): int
    {
        $business = Business::findOne(['slug' => 'tort']);
        if ($business === null) {
            $this->stderr("Run seed/verticals + seed/catalog-menu first.\n");
            return ExitCode::UNSPECIFIED_ERROR;
        }
        if (!function_exists('imagecreatetruecolor')) {
            $this->stderr("GD extension not available.\n");
            return ExitCode::UNSPECIFIED_ERROR;
        }
        $font = null;
        foreach ([
            '/System/Library/Fonts/Supplemental/Arial.ttf',
            '/Library/Fonts/Arial.ttf',
            '/System/Library/Fonts/Supplemental/Verdana.ttf',
        ] as $f) {
            if (is_file($f)) {
                $font = $f;
                break;
            }
        }
        if ($font === null) {
            $this->stderr("No TTF font found.\n");
            return ExitCode::UNSPECIFIED_ERROR;
        }

        $bid = (int) $business->id;
        $services = Service::find()->where(['business_id' => $bid])->all();
        $dir = \Yii::getAlias('@api/web/uploads/menu');
        \yii\helpers\FileHelper::createDirectory($dir, 0775);
        $base = $this->assetBase();

        $n = 0;
        foreach ($services as $svc) {
            $this->makeDishImage($dir . '/' . $svc->id . '.png', (string) $svc->name, (int) $svc->id, $font);
            $svc->image = $base . '/uploads/menu/' . $svc->id . '.png';
            $svc->save(false, ['image']);
            $n++;
        }
        $this->stdout("Generated $n menu images for '{$business->name}'.\n");
        return ExitCode::OK;
    }

    /**
     * Fill the catalog demo (slug `tort`) with REAL food photos downloaded from
     * TheMealDB (desserts) + ingredient images for drinks, stored locally so the
     * storefront is self-contained. "Similar is fine" — a cake shop, so dessert
     * photos suit every item. Usage: php yii seed/catalog-real-images
     */
    public function actionCatalogRealImages(): int
    {
        $business = Business::findOne(['slug' => 'tort']);
        if ($business === null) {
            $this->stderr("Run seed/verticals + seed/catalog-menu first.\n");
            return ExitCode::UNSPECIFIED_ERROR;
        }
        $bid = (int) $business->id;

        $listJson = $this->fetchUrl('https://www.themealdb.com/api/json/v1/1/filter.php?c=Dessert');
        $meals = $listJson !== null ? (json_decode($listJson, true)['meals'] ?? []) : [];
        $desserts = array_values(array_filter(array_map(static fn ($m) => $m['strMealThumb'] ?? null, $meals)));
        if ($desserts === []) {
            $this->stderr("Could not fetch dessert images (network?).\n");
            return ExitCode::UNSPECIFIED_ERROR;
        }
        $ingredient = static fn (string $n) => "https://www.themealdb.com/images/ingredients/{$n}.png";

        $dir = \Yii::getAlias('@api/web/uploads/menu');
        \yii\helpers\FileHelper::createDirectory($dir, 0775);
        $base = $this->assetBase();

        $services = Service::find()->where(['business_id' => $bid])->orderBy(['id' => SORT_ASC])->all();
        $count = count($desserts);
        $i = 0;
        $n = 0;
        foreach ($services as $svc) {
            $name = mb_strtolower((string) $svc->name);
            $isDrink = false;
            if (str_contains($name, 'kapuchino') || str_contains($name, 'amerikano') || str_contains($name, 'kofe')) {
                $primary = $ingredient('Coffee');
                $isDrink = true;
            } elseif (str_contains($name, 'choy') || str_contains($name, 'tea')) {
                $primary = $ingredient('Tea');
                $isDrink = true;
            } elseif (str_contains($name, 'apelsin') || str_contains($name, 'fresh')) {
                $primary = $ingredient('Orange');
                $isDrink = true;
            } else {
                $primary = $desserts[($i * 7) % $count];
            }

            $gallery = [];
            $main = $this->saveImage($primary, $dir, 'real-' . $svc->id, $base);
            if ($main === null) {
                $this->stdout("  skip {$svc->name} (download failed)\n");
                continue;
            }
            $gallery[] = $main;

            // A couple more shots for the gallery (desserts only — drinks stay 1).
            if (!$isDrink) {
                foreach ([2, 3] as $k) {
                    $extra = $this->saveImage($desserts[(($i * 7) + $k * 13) % $count], $dir, 'real-' . $svc->id . '-' . $k, $base);
                    if ($extra !== null) {
                        $gallery[] = $extra;
                    }
                }
            }
            $i++;

            $svc->image = $main;
            $svc->gallery = $gallery;
            $svc->description = $this->dishDescription((string) $svc->name);
            $svc->save(false, ['image', 'gallery', 'description']);
            $n++;
        }

        $this->stdout("Attached photos + galleries to $n items of '{$business->name}'.\n");
        return ExitCode::OK;
    }

    /**
     * Fill the restaurant demo (slug `restoran`) with a real food menu + REAL
     * food photos from TheMealDB (Beef/Chicken/Seafood/Pasta/Vegetarian), so the
     * catalog storefront works for food & restaurants exactly like the cake shop.
     * Idempotent for the menu; re-attaches photos each run.
     * Usage: php yii seed/restaurant-menu
     */
    public function actionRestaurantMenu(): int
    {
        $business = Business::findOne(['slug' => 'restoran']);
        if ($business === null) {
            $this->stderr("Run seed/verticals first (needs the 'restoran' business).\n");
            return ExitCode::UNSPECIFIED_ERROR;
        }
        $bid = (int) $business->id;

        // category => [ [name, price_so'm], ... ]
        $menu = [
            'Milliy taomlar' => [
                ['Osh (palov)', 35000], ['Lagmon', 32000], ['Manti (5 dona)', 30000],
                ['Norin', 33000], ['Somsa (tandir)', 12000],
            ],
            'Shashlik / Grill' => [
                ['Mol shashlik (1 six)', 28000], ['Tovuq shashlik (1 six)', 22000],
                ['Qazan kabob', 45000], ['Jigar shashlik', 25000],
            ],
            'Salatlar' => [
                ['Achichuk', 15000], ['Sezar salat', 38000], ['Vinegret', 18000],
            ],
            'Fast food' => [
                ['Lavash (tovuq)', 30000], ['Burger', 35000], ['Xot-dog', 20000],
            ],
            'Ichimliklar' => [
                ['Choy (choynak)', 10000], ['Kompot', 12000],
                ['Coca-Cola 0.5', 12000], ['Fresh apelsin', 28000],
            ],
        ];

        $sort = 0;
        foreach ($menu as $catName => $rows) {
            $category = ServiceCategory::findOne(['business_id' => $bid, 'name' => $catName])
                ?? $this->save(new ServiceCategory([
                    'business_id' => $bid, 'name' => $catName, 'sort' => $sort,
                ]));
            $sort++;
            foreach ($rows as [$name, $som]) {
                if (Service::find()->where(['business_id' => $bid, 'name' => $name])->exists()) {
                    continue;
                }
                $this->save(new Service([
                    'business_id' => $bid, 'category_id' => $category->id, 'name' => $name,
                    'duration_min' => 30, 'price_tiyin' => $som * 100, 'deposit_tiyin' => 0, 'is_active' => 1,
                ]));
            }
        }

        // Build a pool of real food thumbnails from several savoury categories.
        $pool = [];
        foreach (['Beef', 'Chicken', 'Seafood', 'Pasta', 'Vegetarian'] as $cat) {
            $json = $this->fetchUrl('https://www.themealdb.com/api/json/v1/1/filter.php?c=' . $cat);
            $meals = $json !== null ? (json_decode($json, true)['meals'] ?? []) : [];
            foreach ($meals as $m) {
                if (!empty($m['strMealThumb'])) {
                    $pool[] = $m['strMealThumb'];
                }
            }
        }
        if ($pool === []) {
            $this->stderr("Could not fetch food images (network?). Menu seeded without photos.\n");
            return ExitCode::OK;
        }
        $ingredient = static fn (string $n) => "https://www.themealdb.com/images/ingredients/{$n}.png";

        $dir = \Yii::getAlias('@api/web/uploads/menu');
        \yii\helpers\FileHelper::createDirectory($dir, 0775);
        $base = $this->assetBase();

        $services = Service::find()->where(['business_id' => $bid])->orderBy(['id' => SORT_ASC])->all();
        $count = count($pool);
        $i = 0;
        $n = 0;
        foreach ($services as $svc) {
            $name = mb_strtolower((string) $svc->name);
            $isDrink = false;
            if (str_contains($name, 'choy') || str_contains($name, 'tea')) {
                $primary = $ingredient('Tea');
                $isDrink = true;
            } elseif (str_contains($name, 'kofe') || str_contains($name, 'kapuchino')) {
                $primary = $ingredient('Coffee');
                $isDrink = true;
            } elseif (str_contains($name, 'kompot') || str_contains($name, 'apelsin') || str_contains($name, 'fresh') || str_contains($name, 'cola')) {
                $primary = $ingredient('Orange');
                $isDrink = true;
            } else {
                $primary = $pool[($i * 7) % $count];
            }

            $gallery = [];
            $main = $this->saveImage($primary, $dir, 'rest-' . $svc->id, $base);
            if ($main === null) {
                $this->stdout("  skip {$svc->name} (download failed)\n");
                continue;
            }
            $gallery[] = $main;
            if (!$isDrink) {
                foreach ([2, 3] as $k) {
                    $extra = $this->saveImage($pool[(($i * 7) + $k * 13) % $count], $dir, 'rest-' . $svc->id . '-' . $k, $base);
                    if ($extra !== null) {
                        $gallery[] = $extra;
                    }
                }
            }
            $i++;

            $svc->image = $main;
            $svc->gallery = $gallery;
            $svc->description = $this->dishDescription((string) $svc->name);
            $svc->save(false, ['image', 'gallery', 'description']);
            $n++;
        }

        $this->stdout("Restaurant '{$business->name}' menu + photos ready ($n items).\n");
        return ExitCode::OK;
    }

    /**
     * Fill the clinic demo (slug `klinika`) with a medical service catalog so it
     * renders the same web-catalog storefront as food — grouped by category, each
     * service with a blue medical tile image + description. Idempotent for the
     * menu; re-attaches images each run. Usage: php yii seed/medical-catalog
     */
    public function actionMedicalCatalog(): int
    {
        $business = Business::findOne(['slug' => 'klinika']);
        if ($business === null) {
            $this->stderr("Run seed/verticals first (needs the 'klinika' business).\n");
            return ExitCode::UNSPECIFIED_ERROR;
        }
        $bid = (int) $business->id;

        // category => [ [name, price_so'm], ... ]
        $menu = [
            'UZI / Diagnostika' => [
                ['UZI (qorin bo\'shlig\'i)', 80000], ['UZI (buyrak)', 70000],
                ['EKG', 50000], ['Rentgen', 60000],
            ],
            'Laboratoriya' => [
                ['Umumiy qon tahlili', 40000], ['Qand tahlili', 25000], ['Gormonlar tahlili', 120000],
            ],
            'Shifokor qabuli' => [
                ['Terapevt qabuli', 50000], ['Kardiolog qabuli', 80000], ['Nevrolog qabuli', 80000],
            ],
            'Stomatologiya' => [
                ['Tish davolash', 150000], ['Tish oqartirish', 300000], ['Stomatolog konsultatsiyasi', 30000],
            ],
        ];

        $sort = 0;
        foreach ($menu as $catName => $rows) {
            $category = ServiceCategory::findOne(['business_id' => $bid, 'name' => $catName])
                ?? $this->save(new ServiceCategory([
                    'business_id' => $bid, 'name' => $catName, 'sort' => $sort,
                ]));
            $sort++;
            foreach ($rows as [$name, $som]) {
                if (Service::find()->where(['business_id' => $bid, 'name' => $name])->exists()) {
                    continue;
                }
                $this->save(new Service([
                    'business_id' => $bid, 'category_id' => $category->id, 'name' => $name,
                    'duration_min' => 30, 'price_tiyin' => $som * 100, 'deposit_tiyin' => 0, 'is_active' => 1,
                ]));
            }
        }

        $font = $this->ttfFont();
        if (!function_exists('imagecreatetruecolor') || $font === null) {
            $this->stdout("Medical catalog seeded (no GD/font, images skipped).\n");
            return ExitCode::OK;
        }

        $dir = \Yii::getAlias('@api/web/uploads/menu');
        \yii\helpers\FileHelper::createDirectory($dir, 0775);
        $base = $this->assetBase();

        $services = Service::find()->where(['business_id' => $bid])->orderBy(['id' => SORT_ASC])->all();
        $n = 0;
        foreach ($services as $svc) {
            $file = $dir . '/med-' . $svc->id . '.png';
            // 205° = medical blue.
            $this->makeDishImage($file, (string) $svc->name, (int) $svc->id, $font, 205);
            $url = $base . '/uploads/menu/med-' . $svc->id . '.png';
            $svc->image = $url;
            $svc->gallery = [$url];
            $svc->description = $this->medicalDescription((string) $svc->name);
            $svc->save(false, ['image', 'gallery', 'description']);
            $n++;
        }

        $this->stdout("Clinic '{$business->name}' catalog + images ready ($n services).\n");
        return ExitCode::OK;
    }

    /**
     * Fill a catalog business (cafe / tort) with a full, realistic demo dataset —
     * staff, clients, loyalty cards + ledger, and ~50 orders spread across the
     * last two weeks with varied times / statuses / sources — so the admin
     * (orders kanban, the Jadval orders-timeline, clients, loyalty) looks alive
     * for a screencast. Order timestamps are backdated so the timeline is real.
     *
     * Usage: php yii seed/fill            (defaults to the local 'tort' business)
     *        php yii seed/fill <slug>     (e.g. the prod cake-shop slug)
     *
     * Staff/clients/loyalty are found-or-created; orders are only added when the
     * business has < 25 already, so re-running is safe.
     */
    public function actionFill(string $slug = 'tort'): int
    {
        $business = Business::findOne(['slug' => $slug]);
        if ($business === null) {
            $this->stderr("Business '$slug' topilmadi. Mavjud catalog bizneslar:\n");
            foreach (Business::find()->where(['engine' => 'catalog'])->all() as $b) {
                $this->stdout(sprintf("  %-18s %s\n", $b->slug, $b->name));
            }
            return ExitCode::DATAERR;
        }
        $bid = (int) $business->id;
        $this->stdout("Filling '{$business->name}' (id=$bid)…\n");

        // 1) Menu (Services) — need something orderable.
        $services = Service::find()->where(['business_id' => $bid, 'is_active' => 1])->all();
        if ($services === []) {
            $cat = ServiceCategory::findOne(['business_id' => $bid])
                ?? $this->save(new ServiceCategory(['business_id' => $bid, 'name' => 'Tortlar', 'sort' => 0]));
            foreach ([
                ['Napoleon tort (1kg)', 150000], ['Medovik tort (1kg)', 160000],
                ['Shokoladli tort (1kg)', 170000], ['Chizkeyk (1kg)', 180000],
                ['Ekler (6 dona)', 45000], ['Makaron (6 dona)', 60000],
                ['Kapuchino', 28000], ['Amerikano', 22000], ['Choy (choynak)', 15000],
            ] as [$n, $som]) {
                $services[] = $this->save(new Service([
                    'business_id' => $bid, 'category_id' => $cat->id, 'name' => $n,
                    'duration_min' => 30, 'price_tiyin' => $som * 100, 'deposit_tiyin' => 0, 'is_active' => 1,
                ]));
            }
        }

        // 2) Staff (hodimlar)
        $staffAdded = 0;
        foreach ([
            ['Oshpaz Dilnoza', 'Bosh qandolatchi'], ['Qandolatchi Malika', 'Qandolatchi'],
            ['Ofitsiant Jasur', 'Ofitsiant'], ['Kassir Nigora', 'Kassir'],
            ['Kuryer Sardor', 'Yetkazib beruvchi'],
        ] as [$name, $spec]) {
            if (Staff::find()->where(['business_id' => $bid, 'name' => $name])->exists()) {
                continue;
            }
            $this->save(new Staff(['business_id' => $bid, 'name' => $name, 'specialization' => $spec, 'is_active' => 1]));
            $staffAdded++;
        }

        // 3) Clients (mijozlar)
        $people = [
            ['Aziz Karimov', '+998901234511'], ['Dilnoza Yusupova', '+998901234512'],
            ['Sardor Aliyev', '+998901234513'], ['Nigora Rashidova', '+998901234514'],
            ['Jasur Toshpulatov', '+998901234515'], ['Malika Ergasheva', '+998901234516'],
            ['Bekzod Rahimov', '+998901234517'], ['Kamola Saidova', '+998901234518'],
            ['Sanjar Yusupov', '+998901234519'], ['Gulnora Aliyeva', '+998901234520'],
            ['Otabek Nazarov', '+998901234521'], ['Feruza Karimova', '+998901234522'],
            ['Shoxrux Mirzayev', '+998901234523'], ['Zilola Umarova', '+998901234524'],
            ['Islom Tursunov', '+998901234525'], ['Madina Qodirova', '+998901234526'],
            ['Javohir Abdullayev', '+998901234527'], ['Sevara Xolmatova', '+998901234528'],
        ];
        $clients = [];
        foreach ($people as [$name, $phone]) {
            $clients[] = Client::findOne(['business_id' => $bid, 'phone' => $phone])
                ?? $this->save(new Client(['business_id' => $bid, 'name' => $name, 'phone' => $phone, 'tags' => []]));
        }

        // 4) Loyalty — rule + accounts with a small ledger.
        LoyaltyRule::findOne(['business_id' => $bid]) ?? $this->save(new LoyaltyRule([
            'business_id' => $bid, 'earn_rate' => 500, 'active' => 1,
            'gift_config' => ['referral_bonus_tiyin' => 2000000, 'referral_bonus_points' => 20],
        ]));
        $loyAdded = 0;
        foreach (array_slice($clients, 0, 12) as $c) {
            if (LoyaltyAccount::findOne(['business_id' => $bid, 'client_id' => $c->id]) !== null) {
                continue;
            }
            $acc = new LoyaltyAccount(['business_id' => $bid, 'client_id' => $c->id, 'points' => 0, 'cashback_tiyin' => 0]);
            $acc->save(false);

            $txs = [];
            $earns = mt_rand(1, 3);
            for ($k = 0; $k < $earns; $k++) {
                $txs[] = ['earn', mt_rand(10, 120), mt_rand(30, 600) * 100];
            }
            if (mt_rand(1, 100) <= 35) {
                $cbSum = array_sum(array_column($txs, 2));
                $red = min($cbSum, mt_rand(50, 300) * 100);
                if ($red > 0) {
                    $txs[] = ['redeem', 0, -$red];
                }
            }
            $pts = 0;
            $cb = 0;
            foreach ($txs as [$reason, $dp, $dc]) {
                $t = new LoyaltyTransaction([
                    'account_id' => $acc->id, 'delta_points' => $dp,
                    'delta_cashback_tiyin' => $dc, 'reason' => $reason, 'ref' => 'seed',
                ]);
                $t->save(false);
                $this->backdate('{{%loyalty_transactions}}', (int) $t->id, time() - mt_rand(1, 20) * 86400);
                $pts += $dp;
                $cb += $dc;
            }
            $acc->points = max(0, $pts);
            $acc->cashback_tiyin = max(0, $cb);
            $acc->save(false);
            $loyAdded++;
        }

        // 5) Orders (zakazlar) — backdated across ~2 weeks, status by age.
        $existing = (int) Order::find()->where(['business_id' => $bid])->count();
        $ordersAdded = 0;
        if ($existing >= 25) {
            $this->stdout("  '{$business->name}' allaqachon $existing ta zakazga ega; zakaz seed o'tkazib yuborildi.\n");
        } else {
            $notes = ['tezda kerak', 'muzsiz', 'kam shakar', '2 qavatli bo\'lsin', 'yozuv bilan', 'sovuq bo\'lsin', null, null, null, null];
            $dayWeights = [0, 0, 1, 1, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6, 7, 8, 9, 10, 11, 12, 13];
            for ($i = 0; $i < 52; $i++) {
                $dayOffset = $dayWeights[mt_rand(0, count($dayWeights) - 1)];
                $hour = mt_rand(9, 20);
                $min = mt_rand(0, 59);
                // Local Tashkent (UTC+5) H:M on that day -> absolute unix seconds.
                $ts = strtotime(gmdate('Y-m-d', time() - $dayOffset * 86400) . ' 00:00:00 UTC')
                    + ($hour * 3600 + $min * 60) - 5 * 3600;

                if ($dayOffset >= 5) {
                    $status = $this->pick(['delivered' => 72, 'cancelled' => 18, 'ready' => 10]);
                } elseif ($dayOffset >= 2) {
                    $status = $this->pick(['delivered' => 40, 'ready' => 20, 'preparing' => 18, 'confirmed' => 12, 'cancelled' => 10]);
                } else {
                    $status = $this->pick(['new' => 30, 'confirmed' => 25, 'preparing' => 22, 'ready' => 15, 'delivered' => 8]);
                }
                $source = $this->pick(['bot' => 55, 'site' => 30, 'admin' => 15]);

                if (mt_rand(1, 100) <= 75) {
                    $c = $clients[array_rand($clients)];
                    $cname = $c->name;
                    $cphone = $c->phone;
                    $cid = (int) $c->id;
                } else {
                    $cname = 'Mehmon';
                    $cphone = '+99890' . mt_rand(1000000, 9999999);
                    $cid = null;
                }

                $order = new Order([
                    'business_id' => $bid, 'client_id' => $cid,
                    'customer_name' => $cname, 'customer_phone' => $cphone,
                    'status' => $status, 'source' => $source,
                    'note' => $notes[array_rand($notes)], 'total_tiyin' => 0,
                ]);
                $order->save(false);

                $total = 0;
                $used = [];
                $lines = mt_rand(1, 3);
                for ($l = 0; $l < $lines; $l++) {
                    $svc = $services[array_rand($services)];
                    if (isset($used[$svc->id])) {
                        continue;
                    }
                    $used[$svc->id] = true;
                    $qty = mt_rand(1, 2);
                    $it = new OrderItem([
                        'order_id' => (int) $order->id, 'business_id' => $bid, 'service_id' => (int) $svc->id,
                        'name' => $svc->name, 'price_tiyin' => (int) $svc->price_tiyin, 'qty' => $qty,
                    ]);
                    $it->save(false);
                    $this->backdate('{{%order_items}}', (int) $it->id, $ts);
                    $total += (int) $svc->price_tiyin * $qty;
                }
                $order->total_tiyin = $total;
                $order->save(false);
                $this->backdate('{{%orders}}', (int) $order->id, $ts);
                $ordersAdded++;
            }
        }

        // 6) Client categories (mijoz kategoriyalari) + assignments.
        $catAdded = 0;
        $categories = [];
        foreach ([['VIP', '#f59e0b'], ['Doimiy', '#10b981'], ['Yangi', '#3b82f6'], ['Nofaol', '#6b7280']] as $ci => [$cn, $col]) {
            $cat = ClientCategory::findOne(['business_id' => $bid, 'name' => $cn]);
            if ($cat === null) {
                $cat = $this->save(new ClientCategory(['business_id' => $bid, 'name' => $cn, 'color' => $col, 'sort' => $ci]));
                $catAdded++;
            }
            $categories[$cn] = $cat;
        }
        foreach ($clients as $idx => $c) {
            $cn = $idx < 4 ? 'VIP' : ($idx < 10 ? 'Doimiy' : ($idx < 15 ? 'Yangi' : 'Nofaol'));
            $cat = $categories[$cn];
            if (!ClientCategoryAssignment::find()->where(['client_id' => $c->id, 'category_id' => $cat->id])->exists()) {
                (new ClientCategoryAssignment(['client_id' => (int) $c->id, 'category_id' => (int) $cat->id]))->save(false);
            }
        }

        // 7) Auto-category rules (kategoriya qoidalari).
        $acrAdded = 0;
        foreach ([
            ['VIP', 'sold', 2000000, 'add'], ['Doimiy', 'visits', 5, 'add'], ['Nofaol', 'inactive_days', 60, 'add'],
        ] as [$cn, $metric, $th, $act]) {
            $cat = $categories[$cn] ?? null;
            if ($cat === null || AutoCategoryRule::find()->where(['business_id' => $bid, 'category_id' => $cat->id, 'metric' => $metric])->exists()) {
                continue;
            }
            $this->save(new AutoCategoryRule(['business_id' => $bid, 'category_id' => (int) $cat->id, 'metric' => $metric, 'threshold' => $th, 'action' => $act, 'active' => 1]));
            $acrAdded++;
        }

        // 8) Discount rules (chegirma qoidalari).
        $drAdded = 0;
        foreach ([['paid', 500000, 5], ['paid', 2000000, 10], ['visits', 10, 7]] as [$metric, $th, $pct]) {
            if (DiscountRule::find()->where(['business_id' => $bid, 'metric' => $metric, 'threshold' => $th])->exists()) {
                continue;
            }
            $this->save(new DiscountRule(['business_id' => $bid, 'metric' => $metric, 'threshold' => $th, 'percent' => $pct, 'active' => 1]));
            $drAdded++;
        }

        // 9) Certificates (sertifikatlar).
        $certAdded = 0;
        if ((int) Certificate::find()->where(['business_id' => $bid])->count() < 4) {
            $certDefs = [
                ['Sovg\'a sertifikati 100k', 10000000, 10000000, 'active'],
                ['Sovg\'a sertifikati 200k', 20000000, 20000000, 'active'],
                ['Sovg\'a sertifikati 50k', 5000000, 5000000, 'active'],
                ['Tug\'ilgan kun 150k', 15000000, 6000000, 'active'],
                ['Sovg\'a sertifikati 100k', 10000000, 0, 'used'],
                ['Aksiya 300k', 30000000, 30000000, 'active'],
            ];
            foreach ($certDefs as $k => [$name, $val, $bal, $st]) {
                $c = $clients[array_rand($clients)];
                $this->save(new Certificate([
                    'business_id' => $bid, 'code' => 'TIZ-' . strtoupper(substr(md5($bid . $k . mt_rand()), 0, 6)),
                    'name' => $name, 'value_tiyin' => $val, 'balance_tiyin' => $bal,
                    'client_id' => (int) $c->id, 'status' => $st,
                    'expires_at' => gmdate('Y-m-d', time() + mt_rand(30, 180) * 86400),
                ]));
                $certAdded++;
            }
        }

        // 10) Subscription types (abonementlar).
        $subAdded = 0;
        foreach ([
            ['10 ta kofe abonement', 10, 250000, 60], ['Oylik shirinlik klubi', 8, 400000, 30], ['VIP tort klub', 4, 600000, 90],
        ] as [$name, $visits, $som, $days]) {
            if (SubscriptionType::find()->where(['business_id' => $bid, 'name' => $name])->exists()) {
                continue;
            }
            $this->save(new SubscriptionType(['business_id' => $bid, 'name' => $name, 'visits' => $visits, 'price_tiyin' => $som * 100, 'valid_days' => $days, 'is_active' => 1]));
            $subAdded++;
        }

        // 11) Deposits (depozitlar) — top-ups (+ occasional spend) per client.
        $depAdded = 0;
        if ((int) DepositTransaction::find()->where(['business_id' => $bid])->count() === 0) {
            foreach (array_slice($clients, 0, 9) as $c) {
                $top = mt_rand(100, 800) * 1000; // 100k..800k so'm in tiyin? -> *100 below
                $topTiyin = $top * 100;
                $t = new DepositTransaction(['business_id' => $bid, 'client_id' => (int) $c->id, 'delta_tiyin' => $topTiyin, 'type' => 'topup', 'reason' => 'Balans to\'ldirish']);
                $t->save(false);
                $this->backdate('{{%deposit_transactions}}', (int) $t->id, time() - mt_rand(2, 25) * 86400);
                $depAdded++;
                if (mt_rand(1, 100) <= 50) {
                    $spend = min($topTiyin, mt_rand(20, 200) * 1000 * 100);
                    $s = new DepositTransaction(['business_id' => $bid, 'client_id' => (int) $c->id, 'delta_tiyin' => -$spend, 'type' => 'spend', 'reason' => 'Buyurtma to\'lovi']);
                    $s->save(false);
                    $this->backdate('{{%deposit_transactions}}', (int) $s->id, time() - mt_rand(1, 20) * 86400);
                    $depAdded++;
                }
            }
        }

        // 12) Payments (Finance / Hisobotlar money) — paid Payme/Click transactions.
        $txAdded = 0;
        if ((int) Transaction::find()->where(['business_id' => $bid])->count() < 10) {
            for ($i = 0; $i < 30; $i++) {
                $dayOffset = mt_rand(0, 29);
                $ts = time() - $dayOffset * 86400 - mt_rand(0, 40000);
                $status = $this->pick(['paid' => 80, 'pending' => 10, 'refunded' => 6, 'canceled' => 4]);
                $tx = new Transaction([
                    'business_id' => $bid, 'provider' => $this->pick(['payme' => 60, 'click' => 40]),
                    'amount_tiyin' => mt_rand(30, 350) * 1000 * 100, 'type' => $this->pick(['deposit' => 70, 'float' => 30]),
                    'status' => $status, 'external_id' => 'seed-' . mt_rand(100000, 999999),
                    'idempotency_key' => 'seed:' . $bid . ':' . $i . ':' . mt_rand(1000, 9999),
                ]);
                $tx->save(false);
                $this->backdate('{{%transactions}}', (int) $tx->id, $ts);
                $txAdded++;
            }
        }

        // 13) Appointments — analytics (Hisobotlar) reads these; the menu items
        // become the services so revenue / top-services / staff-load populate.
        $apptAdded = 0;
        $staffList = Staff::find()->where(['business_id' => $bid, 'is_active' => 1])->all();
        if ($staffList !== [] && (int) Appointment::find()->where(['business_id' => $bid])->count() < 20) {
            for ($i = 0; $i < 46; $i++) {
                $dayOffset = mt_rand(0, 29);
                $hour = mt_rand(9, 19);
                $min = [0, 15, 30, 45][mt_rand(0, 3)];
                $ts = strtotime(gmdate('Y-m-d', time() - $dayOffset * 86400) . ' 00:00:00 UTC')
                    + ($hour * 3600 + $min * 60) - 5 * 3600;
                $svc = $services[array_rand($services)];
                $st = $staffList[array_rand($staffList)];
                $c = $clients[array_rand($clients)];
                $dur = (int) ($svc->duration_min ?: 30);
                $status = $dayOffset === 0
                    ? $this->pick(['confirmed' => 45, 'pending' => 30, 'completed' => 25])
                    : $this->pick(['completed' => 74, 'no_show' => 12, 'canceled' => 9, 'confirmed' => 5]);
                $appt = new Appointment([
                    'business_id' => $bid, 'client_id' => (int) $c->id, 'staff_id' => (int) $st->id,
                    'service_id' => (int) $svc->id, 'starts_at' => gmdate('Y-m-d H:i:s', $ts),
                    'ends_at' => gmdate('Y-m-d H:i:s', $ts + $dur * 60), 'status' => $status,
                    'source' => $this->pick(['site' => 40, 'bot' => 40, 'admin' => 20]),
                    'paid' => $status === 'completed' ? 1 : 0,
                ]);
                $appt->save(false);
                $this->backdate('{{%appointments}}', (int) $appt->id, $ts);
                $apptAdded++;
            }
        }

        $this->stdout(sprintf(
            "Tayyor '%s': +%d hodim, %d mijoz, +%d loyallik, +%d zakaz, +%d kategoriya, "
            . "+%d kat.qoida, +%d chegirma, +%d sertifikat, +%d abonement, +%d depozit, "
            . "+%d to'lov, +%d appointment(hisobot).\n",
            $business->name, $staffAdded, count($clients), $loyAdded, $ordersAdded,
            $catAdded, $acrAdded, $drAdded, $certAdded, $subAdded, $depAdded, $txAdded, $apptAdded
        ));
        return ExitCode::OK;
    }

    /**
     * Rebuild a catalog business's demo data from a clean slate for a screencast:
     * 5 BRANCHES instead of cook-staff, a busy order stream (~30-40/day), and a
     * large per-branch appointment volume so Payroll (Ish haqi) and Hisobotlar
     * show 30-40 records/day per branch. Orders stay bounded (~14 days) because
     * the kanban renders every one; appointments can be many (only aggregated).
     *
     * Usage: php yii seed/refill [slug]   (default 'tort'). WIPES the business's
     * demo transactions/staff first (keeps the business, clients and menu).
     */
    public function actionRefill(string $slug = 'tort'): int
    {
        $business = Business::findOne(['slug' => $slug]);
        if ($business === null) {
            $this->stderr("Business '$slug' topilmadi. Mavjud catalog bizneslar:\n");
            foreach (Business::find()->where(['engine' => 'catalog'])->all() as $b) {
                $this->stdout(sprintf("  %-18s %s\n", $b->slug, $b->name));
            }
            return ExitCode::DATAERR;
        }
        $bid = (int) $business->id;
        $db = \Yii::$app->db;
        $this->stdout("Refilling '{$business->name}' (id=$bid) — clean slate…\n");

        // --- 1) Wipe demo transactions + staff (keep business, clients, menu) ---
        $del = static function (string $sql) use ($db): void {
            try { $db->createCommand($sql)->execute(); } catch (\Throwable $e) { /* optional table */ }
        };
        $db->createCommand()->delete('{{%order_items}}', ['business_id' => $bid])->execute();
        $db->createCommand()->delete('{{%orders}}', ['business_id' => $bid])->execute();
        $del("DELETE ai FROM {{%appointment_items}} ai JOIN {{%appointments}} a ON a.id=ai.appointment_id WHERE a.business_id=$bid");
        $db->createCommand()->delete('{{%appointments}}', ['business_id' => $bid])->execute();
        $db->createCommand()->delete('{{%transactions}}', ['business_id' => $bid])->execute();
        $db->createCommand()->delete('{{%deposit_transactions}}', ['business_id' => $bid])->execute();
        $del("DELETE lt FROM {{%loyalty_transactions}} lt JOIN {{%loyalty_accounts}} la ON la.id=lt.account_id WHERE la.business_id=$bid");
        $db->createCommand()->delete('{{%loyalty_accounts}}', ['business_id' => $bid])->execute();
        $db->createCommand()->delete('{{%certificates}}', ['business_id' => $bid])->execute();
        $db->createCommand()->delete('{{%discount_rules}}', ['business_id' => $bid])->execute();
        $db->createCommand()->delete('{{%auto_category_rules}}', ['business_id' => $bid])->execute();
        $db->createCommand()->delete('{{%subscription_types}}', ['business_id' => $bid])->execute();
        $del("DELETE ca FROM {{%client_category_assignment}} ca JOIN {{%client_categories}} cc ON cc.id=ca.category_id WHERE cc.business_id=$bid");
        $db->createCommand()->delete('{{%client_categories}}', ['business_id' => $bid])->execute();
        $del("DELETE wh FROM {{%working_hours}} wh JOIN {{%staff}} s ON s.id=wh.staff_id WHERE s.business_id=$bid");
        $del("DELETE t FROM {{%time_off}} t JOIN {{%staff}} s ON s.id=t.staff_id WHERE s.business_id=$bid");
        $db->createCommand()->delete('{{%staff}}', ['business_id' => $bid])->execute();

        // --- 2) Branches (filiallar) as "staff" ---
        $branches = [];
        foreach (['Chilonzor filiali', 'Yunusobod filiali', 'Sergeli filiali', 'Yakkasaroy filiali', 'Olmazor filiali'] as $bn) {
            $s = $this->save(new Staff(['business_id' => $bid, 'name' => $bn, 'specialization' => 'Filial', 'is_active' => 1]));
            for ($wd = 1; $wd <= 7; $wd++) {
                $this->save(new WorkingHours(['staff_id' => $s->id, 'weekday' => $wd, 'start_time' => '09:00:00', 'end_time' => '22:00:00']));
            }
            $branches[] = $s;
        }

        // --- 3) Menu + clients (create if missing) ---
        $services = Service::find()->where(['business_id' => $bid, 'is_active' => 1])->all();
        if ($services === []) {
            $cat = ServiceCategory::findOne(['business_id' => $bid]) ?? $this->save(new ServiceCategory(['business_id' => $bid, 'name' => 'Tortlar', 'sort' => 0]));
            foreach ([['Napoleon tort (1kg)', 150000], ['Medovik tort (1kg)', 160000], ['Shokoladli tort (1kg)', 170000], ['Chizkeyk (1kg)', 180000], ['Ekler (6 dona)', 45000], ['Kapuchino', 28000], ['Choy (choynak)', 15000]] as [$n, $som]) {
                $services[] = $this->save(new Service(['business_id' => $bid, 'category_id' => $cat->id, 'name' => $n, 'duration_min' => 30, 'price_tiyin' => $som * 100, 'deposit_tiyin' => 0, 'is_active' => 1]));
            }
        }
        $clients = Client::find()->where(['business_id' => $bid])->all();
        if (count($clients) < 12) {
            for ($i = count($clients); $i < 20; $i++) {
                $clients[] = $this->save(new Client(['business_id' => $bid, 'name' => 'Mijoz ' . ($i + 1), 'phone' => '+99890' . mt_rand(1000000, 9999999), 'tags' => []]));
            }
        }

        // --- 4) Orders (~30-40/day over 14 days) ---
        $notes = ['tezda kerak', 'muzsiz', 'kam shakar', '2 qavatli bo\'lsin', 'yozuv bilan', null, null, null, null];
        $ordersAdded = 0;
        for ($d = 0; $d < 14; $d++) {
            $count = mt_rand(28, 42);
            for ($j = 0; $j < $count; $j++) {
                $hour = mt_rand(9, 21);
                $ts = strtotime(gmdate('Y-m-d', time() - $d * 86400) . ' 00:00:00 UTC') + ($hour * 3600 + mt_rand(0, 59) * 60) - 5 * 3600;
                if ($d >= 5) {
                    $status = $this->pick(['delivered' => 74, 'cancelled' => 16, 'ready' => 10]);
                } elseif ($d >= 2) {
                    $status = $this->pick(['delivered' => 42, 'ready' => 20, 'preparing' => 18, 'confirmed' => 12, 'cancelled' => 8]);
                } else {
                    $status = $this->pick(['new' => 32, 'confirmed' => 24, 'preparing' => 22, 'ready' => 14, 'delivered' => 8]);
                }
                $c = $clients[array_rand($clients)];
                $order = new Order(['business_id' => $bid, 'client_id' => (int) $c->id, 'customer_name' => $c->name, 'customer_phone' => $c->phone, 'status' => $status, 'source' => $this->pick(['bot' => 55, 'site' => 30, 'admin' => 15]), 'note' => $notes[array_rand($notes)], 'total_tiyin' => 0]);
                $order->save(false);
                $total = 0;
                $used = [];
                $lines = mt_rand(1, 3);
                for ($l = 0; $l < $lines; $l++) {
                    $svc = $services[array_rand($services)];
                    if (isset($used[$svc->id])) { continue; }
                    $used[$svc->id] = true;
                    $qty = mt_rand(1, 2);
                    $it = new OrderItem(['order_id' => (int) $order->id, 'business_id' => $bid, 'service_id' => (int) $svc->id, 'name' => $svc->name, 'price_tiyin' => (int) $svc->price_tiyin, 'qty' => $qty]);
                    $it->save(false);
                    $this->backdate('{{%order_items}}', (int) $it->id, $ts);
                    $total += (int) $svc->price_tiyin * $qty;
                }
                $order->total_tiyin = $total;
                $order->save(false);
                $this->backdate('{{%orders}}', (int) $order->id, $ts);
                $ordersAdded++;
            }
        }

        // --- 5) Appointments: 30-40/day PER BRANCH over 14 days (Payroll/Hisobot) ---
        $rows = [];
        for ($d = 0; $d < 14; $d++) {
            foreach ($branches as $st) {
                $n = mt_rand(30, 40);
                for ($k = 0; $k < $n; $k++) {
                    $hour = mt_rand(9, 20);
                    $min = [0, 15, 30, 45][mt_rand(0, 3)];
                    $ts = strtotime(gmdate('Y-m-d', time() - $d * 86400) . ' 00:00:00 UTC') + ($hour * 3600 + $min * 60) - 5 * 3600;
                    $svc = $services[array_rand($services)];
                    $c = $clients[array_rand($clients)];
                    $dur = (int) ($svc->duration_min ?: 30);
                    $status = $d === 0
                        ? $this->pick(['confirmed' => 45, 'pending' => 30, 'completed' => 25])
                        : $this->pick(['completed' => 78, 'no_show' => 10, 'canceled' => 8, 'confirmed' => 4]);
                    $rows[] = [$bid, (int) $c->id, (int) $st->id, (int) $svc->id, gmdate('Y-m-d H:i:s', $ts), gmdate('Y-m-d H:i:s', $ts + $dur * 60), $status, $this->pick(['site' => 40, 'bot' => 40, 'admin' => 20]), (int) $svc->deposit_tiyin, $status === 'completed' ? 1 : 0, $ts, $ts];
                }
            }
        }
        $cols = ['business_id', 'client_id', 'staff_id', 'service_id', 'starts_at', 'ends_at', 'status', 'source', 'deposit_tiyin', 'paid', 'created_at', 'updated_at'];
        $apptAdded = count($rows);
        foreach (array_chunk($rows, 400) as $chunk) {
            $db->createCommand()->batchInsert('{{%appointments}}', $cols, $chunk)->execute();
        }

        // --- 6) Loyalty + finance + categories (aggregated views) ---
        $this->fillAux($bid, $clients, $services, $branches);

        $this->stdout(sprintf(
            "Tayyor '%s': %d filial, %d zakaz (~%d/kun), %d appointment (payroll/hisobot uchun).\n",
            $business->name, count($branches), $ordersAdded, (int) round($ordersAdded / 14), $apptAdded
        ));
        return ExitCode::OK;
    }

    /** Categories, rules, certificates, subscriptions, deposits, payments. */
    private function fillAux(int $bid, array $clients, array $services, array $branches): void
    {
        LoyaltyRule::findOne(['business_id' => $bid]) ?? $this->save(new LoyaltyRule(['business_id' => $bid, 'earn_rate' => 500, 'active' => 1, 'gift_config' => ['referral_bonus_tiyin' => 2000000, 'referral_bonus_points' => 20]]));

        $categories = [];
        foreach ([['VIP', '#f59e0b'], ['Doimiy', '#10b981'], ['Yangi', '#3b82f6'], ['Nofaol', '#6b7280']] as $ci => [$cn, $col]) {
            $categories[$cn] = $this->save(new ClientCategory(['business_id' => $bid, 'name' => $cn, 'color' => $col, 'sort' => $ci]));
        }
        foreach ($clients as $idx => $c) {
            $cn = $idx < 4 ? 'VIP' : ($idx < 10 ? 'Doimiy' : ($idx < 15 ? 'Yangi' : 'Nofaol'));
            (new ClientCategoryAssignment(['client_id' => (int) $c->id, 'category_id' => (int) $categories[$cn]->id]))->save(false);

            if ($idx < 12) {
                $acc = new LoyaltyAccount(['business_id' => $bid, 'client_id' => (int) $c->id, 'points' => mt_rand(20, 400), 'cashback_tiyin' => mt_rand(30, 900) * 1000]);
                $acc->save(false);
                (new LoyaltyTransaction(['account_id' => (int) $acc->id, 'delta_points' => (int) $acc->points, 'delta_cashback_tiyin' => (int) $acc->cashback_tiyin, 'reason' => 'earn', 'ref' => 'seed']))->save(false);
            }
        }
        foreach ([['VIP', 'sold', 2000000, 'add'], ['Doimiy', 'visits', 5, 'add'], ['Nofaol', 'inactive_days', 60, 'add']] as [$cn, $m, $th, $a]) {
            $this->save(new AutoCategoryRule(['business_id' => $bid, 'category_id' => (int) $categories[$cn]->id, 'metric' => $m, 'threshold' => $th, 'action' => $a, 'active' => 1]));
        }
        foreach ([['paid', 500000, 5], ['paid', 2000000, 10], ['visits', 10, 7]] as [$m, $th, $p]) {
            $this->save(new DiscountRule(['business_id' => $bid, 'metric' => $m, 'threshold' => $th, 'percent' => $p, 'active' => 1]));
        }
        foreach ([['Sovg\'a 100k', 10000000, 10000000, 'active'], ['Sovg\'a 200k', 20000000, 20000000, 'active'], ['Sovg\'a 50k', 5000000, 5000000, 'active'], ['Tug\'ilgan kun 150k', 15000000, 6000000, 'active'], ['Sovg\'a 100k', 10000000, 0, 'used'], ['Aksiya 300k', 30000000, 30000000, 'active']] as $k => [$name, $val, $bal, $stx]) {
            $c = $clients[array_rand($clients)];
            $this->save(new Certificate(['business_id' => $bid, 'code' => 'TIZ-' . strtoupper(substr(md5($bid . $k . mt_rand()), 0, 6)), 'name' => $name, 'value_tiyin' => $val, 'balance_tiyin' => $bal, 'client_id' => (int) $c->id, 'status' => $stx, 'expires_at' => gmdate('Y-m-d', time() + mt_rand(30, 180) * 86400)]));
        }
        foreach ([['10 ta kofe abonement', 10, 250000, 60], ['Oylik shirinlik klubi', 8, 400000, 30], ['VIP tort klub', 4, 600000, 90]] as [$name, $v, $som, $days]) {
            $this->save(new SubscriptionType(['business_id' => $bid, 'name' => $name, 'visits' => $v, 'price_tiyin' => $som * 100, 'valid_days' => $days, 'is_active' => 1]));
        }
        foreach (array_slice($clients, 0, 9) as $c) {
            $top = mt_rand(100, 800) * 1000 * 100;
            $t = new DepositTransaction(['business_id' => $bid, 'client_id' => (int) $c->id, 'delta_tiyin' => $top, 'type' => 'topup', 'reason' => 'Balans to\'ldirish']);
            $t->save(false);
            $this->backdate('{{%deposit_transactions}}', (int) $t->id, time() - mt_rand(2, 25) * 86400);
        }
        for ($i = 0; $i < 40; $i++) {
            $ts = time() - mt_rand(0, 29) * 86400 - mt_rand(0, 40000);
            $tx = new Transaction(['business_id' => $bid, 'provider' => $this->pick(['payme' => 60, 'click' => 40]), 'amount_tiyin' => mt_rand(30, 350) * 1000 * 100, 'type' => $this->pick(['deposit' => 70, 'float' => 30]), 'status' => $this->pick(['paid' => 82, 'pending' => 9, 'refunded' => 6, 'canceled' => 3]), 'external_id' => 'seed-' . mt_rand(100000, 999999), 'idempotency_key' => 'refill:' . $bid . ':' . $i . ':' . mt_rand(1000, 9999)]);
            $tx->save(false);
            $this->backdate('{{%transactions}}', (int) $tx->id, $ts);
        }
    }

    /** Backdate a row's created_at directly (bypasses TimestampBehavior). */
    private function backdate(string $table, int $id, int $ts): void
    {
        \Yii::$app->db->createCommand()->update($table, ['created_at' => $ts], ['id' => $id])->execute();
    }

    /** Weighted random pick: ['a'=>70,'b'=>30] -> 'a' ~70% of the time. */
    private function pick(array $weighted): string
    {
        $sum = array_sum($weighted);
        $r = mt_rand(1, max(1, $sum));
        $acc = 0;
        foreach ($weighted as $key => $w) {
            $acc += $w;
            if ($r <= $acc) {
                return (string) $key;
            }
        }
        return (string) array_key_first($weighted);
    }

    /**
     * Absolute base for generated asset URLs. Prefers the ASSET_BASE env, then
     * the configured api.base; a protocol-relative api.base (//host) is promoted
     * to https. Falls back to the local MAMP host so console seeding still works.
     */
    private function assetBase(): string
    {
        $base = trim((string) (getenv('ASSET_BASE') ?: ''));
        if ($base === '') {
            $base = (string) (\Yii::$app->params['api.base'] ?? '');
        }
        if (str_starts_with($base, '//')) {
            $base = 'https:' . $base;
        }
        $base = rtrim($base, '/');
        if ($base === '' || str_contains($base, '127.0.0.1')) {
            $base = 'https://api.startup';
        }
        return $base;
    }

    private function medicalDescription(string $name): string
    {
        return $name . ' — malakali shifokorlar va zamonaviy uskunalar bilan amalga oshiriladi. '
            . 'Onlayn navbat oling, qulay vaqtni tanlang. Natijalar tez va aniq.';
    }

    /** First available system TTF font, or null. */
    private function ttfFont(): ?string
    {
        foreach ([
            '/System/Library/Fonts/Supplemental/Arial.ttf',
            '/Library/Fonts/Arial.ttf',
            '/System/Library/Fonts/Supplemental/Verdana.ttf',
        ] as $f) {
            if (is_file($f)) {
                return $f;
            }
        }
        return null;
    }

    /** Download an image to $dir/$name.<ext> and return its public URL, or null. */
    private function saveImage(string $url, string $dir, string $name, string $base): ?string
    {
        $ext = str_ends_with($url, '.png') ? 'png' : 'jpg';
        $bytes = $this->fetchUrl($url);
        if ($bytes === null || strlen($bytes) < 500) {
            return null;
        }
        $file = $dir . '/' . $name . '.' . $ext;
        if (file_put_contents($file, $bytes) === false) {
            return null;
        }
        return $base . '/uploads/menu/' . $name . '.' . $ext;
    }

    private function dishDescription(string $name): string
    {
        return $name . ' — yangi, mazali va sifatli ingredientlardan tayyorlanadi. '
            . 'Buyurtma bering, tez orada tayyorlab beramiz. Ofis va uyga yetkazib berish mavjud.';
    }

    /** GET a URL and return the body, or null on failure. */
    private function fetchUrl(string $url): ?string
    {
        if (function_exists('curl_init')) {
            $ch = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_TIMEOUT => 25,
                CURLOPT_USERAGENT => 'TizBiz-seed/1.0',
                CURLOPT_SSL_VERIFYPEER => false,
            ]);
            $body = curl_exec($ch);
            $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            return ($body !== false && $code === 200) ? (string) $body : null;
        }
        $ctx = stream_context_create(['http' => ['timeout' => 25, 'user_agent' => 'TizBiz-seed/1.0']]);
        $body = @file_get_contents($url, false, $ctx);
        return $body === false ? null : $body;
    }

    private function makeDishImage(string $path, string $name, int $seed, string $font, ?int $hueBase = null): void
    {
        $W = 600;
        $H = 400;
        $im = imagecreatetruecolor($W, $H);
        imagealphablending($im, true);

        // Vertical gradient. Default: a seeded, appetising hue. When $hueBase is
        // given (e.g. blue for a clinic) the hue stays near it with slight variety.
        $hue = $hueBase !== null
            ? (($hueBase + (($seed * 13) % 40) - 20) + 360) % 360
            : ($seed * 47) % 360;
        [$r1, $g1, $b1] = $this->hsl($hue, 62, 58);
        [$r2, $g2, $b2] = $this->hsl(($hue + 28) % 360, 66, 40);
        for ($y = 0; $y < $H; $y++) {
            $t = $y / $H;
            $col = imagecolorallocate(
                $im,
                (int) round($r1 + ($r2 - $r1) * $t),
                (int) round($g1 + ($g2 - $g1) * $t),
                (int) round($b1 + ($b2 - $b1) * $t)
            );
            imageline($im, 0, $y, $W, $y, $col);
        }

        // Decorative translucent "plate".
        $plate = imagecolorallocatealpha($im, 255, 255, 255, 100);
        imagefilledellipse($im, $W - 95, 95, 160, 160, $plate);

        // Dark gradient at the bottom for text legibility.
        $start = (int) ($H * 0.5);
        for ($y = $start; $y < $H; $y++) {
            $p = ($y - $start) / ($H - $start);
            $alpha = 127 - (int) round(100 * $p);
            imageline($im, 0, $y, $W, $y, imagecolorallocatealpha($im, 0, 0, 0, $alpha));
        }

        // Dish name (wrapped), bottom-left.
        $white = imagecolorallocate($im, 255, 255, 255);
        $size = 30;
        $lh = 42;
        $lines = $this->wrapText($name, $font, $size, $W - 60);
        $y = $H - 34 - $lh * (count($lines) - 1);
        foreach ($lines as $line) {
            imagettftext($im, $size, 0, 30, $y, $white, $font, $line);
            $y += $lh;
        }

        imagepng($im, $path);
        imagedestroy($im);
    }

    /** @return string[] up to 3 lines fitting $maxW pixels. */
    private function wrapText(string $text, string $font, int $size, int $maxW): array
    {
        $words = preg_split('/\s+/', trim($text)) ?: [];
        $lines = [];
        $cur = '';
        foreach ($words as $w) {
            $try = $cur === '' ? $w : $cur . ' ' . $w;
            $bb = imagettfbbox($size, 0, $font, $try);
            if (abs($bb[2] - $bb[0]) > $maxW && $cur !== '') {
                $lines[] = $cur;
                $cur = $w;
            } else {
                $cur = $try;
            }
        }
        if ($cur !== '') {
            $lines[] = $cur;
        }
        return array_slice($lines, 0, 3);
    }

    /** HSL (deg,%,%) -> [r,g,b] 0-255. */
    private function hsl(float $h, float $s, float $l): array
    {
        $h /= 360;
        $s /= 100;
        $l /= 100;
        if ($s == 0.0) {
            $r = $g = $b = $l;
        } else {
            $q = $l < 0.5 ? $l * (1 + $s) : $l + $s - $l * $s;
            $p = 2 * $l - $q;
            $r = $this->hue2rgb($p, $q, $h + 1 / 3);
            $g = $this->hue2rgb($p, $q, $h);
            $b = $this->hue2rgb($p, $q, $h - 1 / 3);
        }
        return [(int) round($r * 255), (int) round($g * 255), (int) round($b * 255)];
    }

    private function hue2rgb(float $p, float $q, float $t): float
    {
        if ($t < 0) {
            $t += 1;
        }
        if ($t > 1) {
            $t -= 1;
        }
        if ($t < 1 / 6) {
            return $p + ($q - $p) * 6 * $t;
        }
        if ($t < 1 / 2) {
            return $q;
        }
        if ($t < 2 / 3) {
            return $p + ($q - $p) * (2 / 3 - $t) * 6;
        }
        return $p;
    }

    /** Save a model or abort with its validation errors. */
    private function save(ActiveRecord $model, ?callable $before = null): ActiveRecord
    {
        if ($before !== null) {
            $before($model);
        }
        if (!$model->save()) {
            $this->stderr(get_class($model) . " save failed: " . json_encode($model->getErrors(), JSON_UNESCAPED_UNICODE) . "\n");
            exit(ExitCode::UNSPECIFIED_ERROR);
        }
        return $model;
    }
}
