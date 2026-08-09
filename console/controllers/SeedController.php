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
