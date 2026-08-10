<?php

namespace console\controllers;

use common\models\Business;
use common\models\BusinessUser;
use common\models\Client;
use common\models\LoyaltyRule;
use common\models\Service;
use common\models\ServiceCategory;
use common\models\Staff;
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
        $base = rtrim((string) (\Yii::$app->params['api.base'] ?? ''), '/');
        if ($base === '' || str_contains($base, '127.0.0.1')) {
            $base = 'https://api.startup'; // console default is not the MAMP host
        }

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
        $base = rtrim((string) (\Yii::$app->params['api.base'] ?? ''), '/');
        if ($base === '' || str_contains($base, '127.0.0.1')) {
            $base = 'https://api.startup';
        }

        $services = Service::find()->where(['business_id' => $bid])->orderBy(['id' => SORT_ASC])->all();
        $i = 0;
        $n = 0;
        foreach ($services as $svc) {
            $name = mb_strtolower((string) $svc->name);
            if (str_contains($name, 'kapuchino') || str_contains($name, 'amerikano') || str_contains($name, 'kofe')) {
                $src = $ingredient('Coffee');
            } elseif (str_contains($name, 'choy') || str_contains($name, 'tea')) {
                $src = $ingredient('Tea');
            } elseif (str_contains($name, 'apelsin') || str_contains($name, 'fresh')) {
                $src = $ingredient('Orange');
            } else {
                // Spread across the dessert list for variety (deterministic).
                $src = $desserts[($i * 7) % count($desserts)];
                $i++;
            }

            $ext = str_ends_with($src, '.png') ? 'png' : 'jpg';
            $file = $dir . '/real-' . $svc->id . '.' . $ext;
            $bytes = $this->fetchUrl($src);
            if ($bytes === null || strlen($bytes) < 500 || file_put_contents($file, $bytes) === false) {
                $this->stdout("  skip {$svc->name} (download failed)\n");
                continue;
            }
            $svc->image = $base . '/uploads/menu/real-' . $svc->id . '.' . $ext;
            $svc->save(false, ['image']);
            $n++;
        }

        $this->stdout("Attached $n real photos to '{$business->name}'.\n");
        return ExitCode::OK;
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

    private function makeDishImage(string $path, string $name, int $seed, string $font): void
    {
        $W = 600;
        $H = 400;
        $im = imagecreatetruecolor($W, $H);
        imagealphablending($im, true);

        // Vertical gradient from a seeded, appetising hue.
        $hue = ($seed * 47) % 360;
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
