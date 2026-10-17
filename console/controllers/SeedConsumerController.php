<?php

namespace console\controllers;

use api\modules\booking\services\AvailabilityService;
use api\modules\booking\services\BookingService;
use api\modules\consumer\services\ConsumerLinker;
use common\models\Appointment;
use common\models\Business;
use common\models\BusinessUser;
use common\models\ConsumerFavorite;
use common\models\ConsumerUser;
use common\models\LoyaltyAccount;
use common\models\Order;
use common\models\OrderItem;
use common\models\Review;
use common\models\Service;
use common\models\Staff;
use DateTimeImmutable;
use DateTimeZone;
use Yii;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\db\Query;

/**
 * Demo data for the Bizcat consumer app (BACKEND-PLAN §6.2). Idempotent: safe to
 * re-run, nothing is duplicated.
 *
 *   php yii seed-consumer
 *
 * 1. Directory fields (city, district, lat/lng, description, is_listed,
 *    featured) on the 5 demo businesses (prod slug | local slug).
 * 2. Demo consumers (+998900000001..3, OTP 1111) + 12 review-only consumers.
 * 3. 10..15 realistic Uzbek reviews per demo business (count = 10 + id % 6),
 *    on completed appointments / delivered orders; ~40% with an owner reply.
 * 4. Rich data for Aziza (+998900000001), 5. a rental booking for Bobur
 *    (+998900000002), 6. an empty account for Dilnoza (+998900000003).
 * 7. Back-link by phone and print a summary.
 */
class SeedConsumerController extends Controller
{
    /** Demo businesses: key => slug aliases (prod first, then local). */
    private const BUSINESSES = [
        'shox-barber' => ['shox-barber', 'barber'],
        'aziza-tortlari' => ['aziza-tortlari', 'tort'],
        'restoran' => ['restoran'],
        'sanatrix' => ['sanatrix', 'klinika'],
        'serenada' => ['serenada', 'ijara'],
    ];

    /** key => [district, lat, lng, description, comment vertical] */
    private const DIRECTORY = [
        'shox-barber' => ['Chilonzor', '41.2756000', '69.2034000', 'Erkaklar uchun zamonaviy barbershop: soch turmagi, soqol dizayni va parvarish.', 'barber'],
        'aziza-tortlari' => ['Yunusobod', '41.3665000', '69.2890000', "Buyurtma asosida uy tortlari, shirinliklar va bayram to'plamlari.", 'cake'],
        'restoran' => ['Yakkasaroy', '41.2860000', '69.2630000', 'Milliy taomlar: palov, shashlik, somsa. Oilaviy muhit.', 'restaurant'],
        'sanatrix' => ['Mirobod', '41.2895000', '69.2870000', "Ko'p tarmoqli klinika: UZI, tahlillar, shifokor qabuli.", 'clinic'],
        'serenada' => ['Sergeli', '41.2270000', '69.2200000', "To'y va tantanalar uchun zamonaviy zal, 300 mehmongacha.", 'hall'],
    ];

    /** [phone, name, gender] — demo consumers that can log in with the demo OTP. */
    private const DEMO = [
        ['+998900000001', 'Aziza Karimova', 'female'],
        ['+998900000002', 'Bobur Rahimov', 'male'],
        ['+998900000003', 'Dilnoza Yusupova', 'female'],
    ];

    /** [phone, name, gender] — review-only consumers (not on the demo list, cannot log in). */
    private const REVIEWERS = [
        ['+998977000101', 'Sardor Aliyev', 'male'],
        ['+998977000102', 'Nigora Rashidova', 'female'],
        ['+998977000103', 'Jasur Toshpulatov', 'male'],
        ['+998977000104', 'Malika Ergasheva', 'female'],
        ['+998977000105', 'Kamola Saidova', 'female'],
        ['+998977000106', 'Sanjar Yusupov', 'male'],
        ['+998977000107', 'Gulnora Aliyeva', 'female'],
        ['+998977000108', 'Otabek Nazarov', 'male'],
        ['+998977000109', 'Feruza Karimova', 'female'],
        ['+998977000110', 'Shoxrux Mirzayev', 'male'],
        ['+998977000111', 'Zilola Umarova', 'female'],
        ['+998977000112', 'Islom Tursunov', 'male'],
    ];

    /** 60% fives, 30% fours, 10% threes (cycled). */
    private const RATINGS = [5, 5, 4, 5, 3, 5, 4, 5, 5, 4];

    /** vertical => ['high' => 4-5 star texts, 'mid' => 3 star texts] */
    private const COMMENTS = [
        'barber' => [
            'high' => [
                "Usta juda e'tiborli, soch ajoyib chiqdi!",
                "Soqol dizayni zo'r bo'ldi, rahmat!",
                'Har doim vaqtida qabul qilishadi, navbat kutmadim.',
                'Toza va shinam joy, ustalar professional.',
                "O'g'limni ham olib keldim, juda sabr bilan ishlashdi.",
                "Narxi o'rtacha, sifati esa a'lo darajada.",
                'Onlayn yozilish juda qulay ekan, endi faqat shu yerga kelaman.',
                'Fade qilib berishdi, aynan xohlagandek.',
                "Ustaning qo'li yengil, maslahatlari ham foydali bo'ldi.",
                "Do'stlarimga ham tavsiya qildim.",
                'Choy berib kutib olishdi, muomala juda yoqdi.',
                'Uchinchi marta kelyapman, har safar natija bir xil yaxshi.',
                'Soch yuvish va ukladka ham kirdi, mamnunman.',
            ],
            'mid' => [
                "Yaxshi, lekin biroz kutishga to'g'ri keldi.",
                'Soch olish yaxshi, ammo narxi biroz qimmatroq.',
                "Umuman yomon emas, keyingi safar boshqa ustani sinab ko'raman.",
            ],
        ],
        'cake' => [
            'high' => [
                'Napoleon torti juda mazali chiqdi, mehmonlar maqtashdi!',
                "Tug'ilgan kunga buyurtma qildim, yozuvi chiroyli va aniq bo'ldi.",
                'Kremi yengil, juda shirin emas, aynan biz xohlagandek.',
                "Vaqtida tayyor bo'ldi, qadoqlash ham chiroyli.",
                "Medovik ajoyib, uydagidek ta'm.",
                "Bolalar bayrami uchun kapkeyklar zo'r bo'ldi.",
                'Narxi sifatiga mos, yana buyurtma beraman.',
                'Dizaynni rasm bo\'yicha aynan qilib berishdi.',
                'Mevali tort juda yangi va mazali edi.',
                'Telefon orqali tez javob berishdi, xizmat yoqdi.',
                "To'yimizga ikki qavatli tort oldik, hamma hayron qoldi.",
                "Chizkeyk mazasi a'lo, qayta-qayta buyurtma qilaman.",
                "Shokoladli tortning ta'mi esdan chiqmaydi.",
            ],
            'mid' => [
                'Tort mazali, lekin biroz kech tayyor bo\'ldi.',
                "Yaxshi, ammo krem biroz shirinroq bo'lib qoldi.",
                "O'rtacha, rasmdagidek chiqmadi, lekin ta'mi yaxshi.",
            ],
        ],
        'restaurant' => [
            'high' => [
                'Palov juda mazali, porsiyasi ham katta!',
                'Shashlik yumshoq va yaxshi pishgan edi.',
                'Oilaviy kechki ovqat uchun ajoyib joy.',
                'Xizmat tez, ofitsiantlar xushmuomala.',
                'Somsa issiq va qarsildoq, tavsiya qilaman.',
                "Lag'mon uydagidek, juda yoqdi.",
                'Bolalar uchun ham qulay, muhit shinam.',
                "Narxlar maqbul, ta'mi esa a'lo.",
                "Olib ketish uchun buyurtma berdim, hammasi o'z vaqtida tayyor bo'ldi.",
                "Milliy taomlar haqiqiy ta'mda, yana kelamiz.",
                "Choy va shirinliklar ham zo'r ekan.",
                'Mehmonlarni olib keldim, hammasi mamnun qoldi.',
                'Manti juda mazali, xamiri yupqa.',
            ],
            'mid' => [
                'Ovqat mazali, lekin biroz kutdik.',
                'Yaxshi, ammo dam olish kunlari juda gavjum.',
                "Shashlik zo'r, salatlar esa o'rtacha.",
            ],
        ],
        'clinic' => [
            'high' => [
                "Shifokor juda e'tiborli, hamma narsani tushuntirib berdi.",
                'UZI tez va sifatli qilindi, natijani darhol berishdi.',
                'Navbatsiz, belgilangan vaqtda qabul qilishdi.',
                'Klinika toza, xodimlar xushmuomala.',
                "Tahlil natijalari bir kunda tayyor bo'ldi.",
                'Bolamni olib bordim, shifokor juda mehribon ekan.',
                "Onlayn yozilish qulay, telefon qilib o'tirmadim.",
                'Narxlar adolatli, xizmat sifati yuqori.',
                "Doktor maslahatlari juda foydali bo'ldi, rahmat.",
                'Zamonaviy uskunalar, professional yondashuv.',
                "Qabulxonada tez ro'yxatdan o'tkazishdi.",
                "Oilamiz bilan shu yerda tekshiruvdan o'tamiz.",
                "Muolajadan keyin ham qo'ng'iroq qilib holimni so'rashdi.",
            ],
            'mid' => [
                "Shifokor yaxshi, lekin biroz kutishga to'g'ri keldi.",
                'Xizmat yaxshi, ammo narxi qimmatroq.',
                "Umuman yaxshi, natijalarni olishda biroz kechikish bo'ldi.",
            ],
        ],
        'hall' => [
            'high' => [
                "To'yimiz ajoyib o'tdi, zal juda chiroyli!",
                "Xizmat ko'rsatish a'lo darajada, ofitsiantlar tez.",
                'Mehmonlar taomlarni juda maqtashdi.',
                'Bezaklar biz xohlagandek qilindi, rahmat.',
                "Ovoz va yorug'lik uskunalari zo'r ekan.",
                "300 kishilik to'yni hech qanday muammosiz o'tkazdik.",
                'Menejer har bir savolimizga javob berdi.',
                "Narxi sifatiga to'liq mos keladi.",
                "Avtoturargoh keng, mehmonlarga qulay bo'ldi.",
                "Unashtiruvni shu yerda o'tkazdik, hamma mamnun.",
                'Zal toza va salqin, yozda ham qulay.',
                'Tort va shirinliklar ham juda mazali edi.',
                "Yana bir bor rahmat, hayotimizdagi eng yaxshi kun bo'ldi.",
            ],
            'mid' => [
                "Yaxshi, lekin xizmat biroz sekin bo'ldi.",
                'Zal chiroyli, ammo menyuda tanlov kamroq.',
                'Umuman yaxshi, faqat musiqa juda baland edi.',
            ],
        ],
    ];

    private const REPLIES_POSITIVE = [
        'Rahmat! Sizni yana kutamiz.',
        "Iliq so'zlaringiz uchun rahmat!",
        'Tanlaganingiz uchun rahmat, yana kelib turing!',
        'Rahmat! Jamoamizga albatta yetkazamiz.',
    ];
    private const REPLY_MID = "Fikringiz uchun rahmat, kamchiliklarni albatta tuzatamiz.";

    /** @var array<string, Business> key => business */
    private array $biz = [];

    /** @var array<string, ConsumerUser> phone => consumer */
    private array $consumers = [];

    public function actionIndex(): int
    {
        $this->stdout("== seed-consumer\n");

        $this->resolveBusinesses();
        $this->seedDirectoryFields();
        $this->seedConsumers();
        foreach (array_keys(self::BUSINESSES) as $key) {
            try {
                $this->seedReviews($key);
            } catch (\Throwable $e) {
                $this->stdout("  ! reviews {$key}: " . $e->getMessage() . "\n");
            }
        }
        foreach (['seedAziza', 'seedBobur', 'seedDilnoza'] as $step) {
            try {
                $this->$step();
            } catch (\Throwable $e) {
                $this->stdout("  ! {$step}: " . $e->getMessage() . "\n");
            }
        }

        foreach ($this->biz as $b) {
            Review::recomputeBusinessRating((int) $b->id);
        }
        foreach (self::DEMO as [$phone]) {
            if (isset($this->consumers[$phone])) {
                ConsumerLinker::backLink($this->consumers[$phone]);
            }
        }

        $this->summary();
        return ExitCode::OK;
    }

    // ------------------------------------------------------------------ steps

    private function resolveBusinesses(): void
    {
        foreach (self::BUSINESSES as $key => $aliases) {
            $found = null;
            foreach ($aliases as $slug) {
                $found = Business::find()->andWhere(['slug' => $slug])->one();
                if ($found !== null) {
                    break;
                }
            }
            if ($found === null) {
                $this->stdout("  skip {$key}: business not found (" . implode('|', $aliases) . ")\n");
                continue;
            }
            $this->biz[$key] = $found;
        }
    }

    private function seedDirectoryFields(): void
    {
        $this->stdout("-- directory fields\n");
        foreach ($this->biz as $key => $b) {
            [$district, $lat, $lng, $description] = self::DIRECTORY[$key];
            $cols = [
                'city' => 'Toshkent',
                'district' => $district,
                'lat' => $lat,
                'lng' => $lng,
                'description' => $description,
                'is_listed' => 1,
            ];
            if ($b->address === null || $b->address === '') {
                $cols['address'] = $district . ' tumani';
            }
            if ($key === 'shox-barber') {
                $cols['featured_until'] = time() + 30 * 86400;
            }
            Yii::$app->db->createCommand()->update(Business::tableName(), $cols, ['id' => (int) $b->id])->execute();
            $b->refresh();
            $this->stdout("  {$b->slug}: {$district}, Toshkent\n");
        }
    }

    private function seedConsumers(): void
    {
        $this->stdout("-- consumers\n");
        foreach (array_merge(self::DEMO, self::REVIEWERS) as [$phone, $name, $gender]) {
            $c = ConsumerUser::find()->where(['phone' => $phone])->one();
            if ($c === null) {
                $c = new ConsumerUser();
                $c->phone = $phone;
                $c->name = $name;
                $c->gender = $gender;
                $c->city = 'Toshkent';
                $c->locale = 'uz';
                $c->status = ConsumerUser::STATUS_ACTIVE;
                $c->save(false);
                $this->stdout("  + {$phone} {$name}\n");
            }
            $this->consumers[$phone] = $c;
        }
    }

    private function seedReviews(string $key): void
    {
        if (!isset($this->biz[$key])) {
            return;
        }
        $b = $this->biz[$key];
        $bid = (int) $b->id;
        $target = 10 + $bid % 6;
        $existing = (int) (new Query())->from(Review::tableName())->where(['business_id' => $bid])->count();
        $need = max(0, $target - $existing);
        if ($need === 0) {
            $this->stdout("  {$b->slug}: {$existing} reviews already (target {$target})\n");
            return;
        }

        $vertical = self::DIRECTORY[$key][4];
        $ownerId = $this->ownerId($bid);
        $created = 0;

        if ((string) $b->engine === 'catalog') {
            if (!Service::find()->andWhere(['business_id' => $bid, 'is_active' => 1])->exists()) {
                $this->stdout("  skip {$b->slug}: no active services for orders\n");
                return;
            }
            $orders = $this->reviewableOrders($bid, $need);
            for ($j = count($orders); $j < $need; $j++) {
                $reviewer = $this->reviewer($existing + $j);
                $o = $this->insertOrder($b, $reviewer, Order::STATUS_DELIVERED, 3 + ($j * 5) % 38);
                if ($o !== null) {
                    $orders[] = $o;
                }
            }
            foreach ($orders as $i => $o) {
                $k = $existing + $i;
                $reviewer = (int) $o->consumer_id > 0 ? $this->consumerById((int) $o->consumer_id) : $this->reviewer($k);
                if ($reviewer === null) {
                    continue;
                }
                if ((int) $o->consumer_id !== (int) $reviewer->id) {
                    Yii::$app->db->createCommand()->update(Order::tableName(), ['consumer_id' => (int) $reviewer->id], ['id' => (int) $o->id])->execute();
                }
                $serviceId = (new Query())->select('service_id')->from(OrderItem::tableName())
                    ->where(['order_id' => (int) $o->id])->andWhere(['not', ['service_id' => null]])
                    ->orderBy(['id' => SORT_ASC])->scalar();
                $this->insertReview($b, $reviewer, $k, $vertical, $ownerId, [
                    'order_id' => (int) $o->id,
                    'service_id' => $serviceId !== false && $serviceId !== null ? (int) $serviceId : null,
                ], (int) $o->created_at);
                $created++;
            }
        } else {
            $appts = $this->reviewableAppointments($bid, $need);
            for ($j = count($appts); $j < $need; $j++) {
                $reviewer = $this->reviewer($existing + $j);
                $a = $this->insertPastAppointment($b, $reviewer, 3 + $j * 2);
                if ($a !== null) {
                    $appts[] = $a;
                }
            }
            foreach ($appts as $i => $a) {
                $k = $existing + $i;
                $reviewer = (int) $a->consumer_id > 0 ? $this->consumerById((int) $a->consumer_id) : $this->reviewer($k);
                if ($reviewer === null) {
                    continue;
                }
                if ((int) $a->consumer_id !== (int) $reviewer->id) {
                    Yii::$app->db->createCommand()->update(Appointment::tableName(), ['consumer_id' => (int) $reviewer->id], ['id' => (int) $a->id])->execute();
                }
                $this->insertReview($b, $reviewer, $k, $vertical, $ownerId, [
                    'appointment_id' => (int) $a->id,
                    'staff_id' => (int) $a->staff_id,
                    'service_id' => (int) $a->service_id,
                ], $this->utcTs((string) $a->ends_at));
                $created++;
            }
        }
        $this->stdout("  {$b->slug}: +{$created} reviews (target {$target})\n");
    }

    private function seedAziza(): void
    {
        $aziza = $this->consumers['+998900000001'] ?? null;
        if ($aziza === null) {
            return;
        }
        $this->stdout("-- Aziza (+998900000001)\n");
        $barber = $this->biz['shox-barber'] ?? null;
        $tort = $this->biz['aziza-tortlari'] ?? null;
        $clinic = $this->biz['sanatrix'] ?? null;

        $clients = [];
        foreach ([$barber, $tort, $clinic] as $b) {
            if ($b !== null) {
                $clients[(int) $b->id] = $this->client($b, $aziza);
            }
        }

        // Loyalty balances.
        foreach ([[$barber, 120, 1500000], [$tort, 40, 500000]] as [$b, $points, $cashback]) {
            if ($b === null || empty($clients[(int) $b->id])) {
                continue;
            }
            $acc = LoyaltyAccount::find()->andWhere(['business_id' => (int) $b->id, 'client_id' => $clients[(int) $b->id]])->one();
            if ($acc === null) {
                $acc = new LoyaltyAccount();
                $acc->business_id = (int) $b->id;
                $acc->client_id = $clients[(int) $b->id];
            }
            $acc->points = $points;
            $acc->cashback_tiyin = $cashback;
            $acc->save(false);
        }

        if ($barber !== null) {
            $bid = (int) $barber->id;
            // 3 past completed visits: the 2 oldest reviewed, the newest not (can_review).
            $done = Appointment::find()
                ->andWhere(['business_id' => $bid, 'consumer_id' => (int) $aziza->id, 'status' => Appointment::STATUS_COMPLETED])
                ->count();
            foreach ([26, 15, 5] as $n => $daysAgo) {
                if ($n >= (int) $done) {
                    $this->insertPastAppointment($barber, $aziza, $daysAgo);
                }
            }
            $visits = Appointment::find()
                ->andWhere(['business_id' => $bid, 'consumer_id' => (int) $aziza->id, 'status' => Appointment::STATUS_COMPLETED])
                ->orderBy(['starts_at' => SORT_ASC])
                ->limit(3)
                ->all();
            $texts = [[5, "Usta juda e'tiborli, soch ajoyib chiqdi!"], [4, 'Yaxshi xizmat, faqat biroz kutdim.']];
            foreach (array_slice($visits, 0, 2) as $i => $a) {
                if (Review::find()->andWhere(['appointment_id' => (int) $a->id])->exists()) {
                    continue;
                }
                $created = min(time() - 600, $this->utcTs((string) $a->ends_at) + 3 * 3600);
                Yii::$app->db->createCommand()->insert(Review::tableName(), [
                    'business_id' => $bid,
                    'consumer_id' => (int) $aziza->id,
                    'appointment_id' => (int) $a->id,
                    'staff_id' => (int) $a->staff_id,
                    'service_id' => (int) $a->service_id,
                    'author_name' => Review::maskName($aziza->name),
                    'rating' => $texts[$i][0],
                    'comment' => $texts[$i][1],
                    'status' => Review::STATUS_PUBLISHED,
                    'created_at' => $created,
                    'updated_at' => $created,
                ])->execute();
            }

            // 1 upcoming pending booking at the first offered slot within 7 days.
            $hasUpcoming = Appointment::find()
                ->andWhere(['business_id' => $bid, 'consumer_id' => (int) $aziza->id])
                ->andWhere(['status' => [Appointment::STATUS_PENDING, Appointment::STATUS_CONFIRMED, Appointment::STATUS_ARRIVED]])
                ->andWhere(['>=', 'starts_at', gmdate('Y-m-d H:i:s')])
                ->exists();
            if (!$hasUpcoming) {
                $this->insertUpcomingSlot($barber, $aziza, $clients[$bid] ?? null);
            }
            $this->favorite($aziza, $barber);
        }

        if ($tort !== null) {
            $tid = (int) $tort->id;
            $hasDelivered = (new Query())->from(['o' => Order::tableName()])
                ->leftJoin(['r' => Review::tableName()], 'r.order_id = o.id')
                ->where(['o.business_id' => $tid, 'o.consumer_id' => (int) $aziza->id, 'o.status' => Order::STATUS_DELIVERED, 'r.id' => null])
                ->exists();
            if (!$hasDelivered) {
                $this->insertOrder($tort, $aziza, Order::STATUS_DELIVERED, 9);
            }
            $hasNew = Order::find()->andWhere(['business_id' => $tid, 'consumer_id' => (int) $aziza->id, 'status' => Order::STATUS_NEW])->exists();
            if (!$hasNew) {
                $this->insertOrder($tort, $aziza, Order::STATUS_NEW, 0);
            }
            $this->favorite($aziza, $tort);
        }
    }

    private function seedBobur(): void
    {
        $bobur = $this->consumers['+998900000002'] ?? null;
        $hall = $this->biz['serenada'] ?? null;
        if ($bobur === null || $hall === null) {
            return;
        }
        $this->stdout("-- Bobur (+998900000002)\n");
        $bid = (int) $hall->id;
        $this->favorite($bobur, $hall);

        $hasUpcoming = Appointment::find()
            ->andWhere(['business_id' => $bid, 'consumer_id' => (int) $bobur->id])
            ->andWhere(['not in', 'status', Appointment::RELEASED_STATUSES])
            ->andWhere(['>=', 'starts_at', gmdate('Y-m-d H:i:s')])
            ->exists();
        if ($hasUpcoming) {
            return;
        }
        $staff = $this->firstStaff($bid);
        $service = $this->firstService($bid, true);
        if ($staff === null || $service === null) {
            $this->stdout("  skip rental booking: no active staff/service\n");
            return;
        }
        $tz = $this->tz($hall);
        $utc = new DateTimeZone('UTC');
        $today = (new DateTimeImmutable('now', $tz))->setTime(0, 0);
        for ($d = 30; $d <= 150; $d++) {
            $day = $today->modify('+' . $d . ' days');
            $start = $day->setTime(18, 0)->setTimezone($utc)->format('Y-m-d H:i:s');
            $end = $day->setTime(23, 0)->setTimezone($utc)->format('Y-m-d H:i:s');
            if ($this->overlaps($bid, null, $start, $end)) {
                continue;
            }
            $a = new Appointment();
            $a->business_id = $bid;
            $a->staff_id = (int) $staff->id;
            $a->service_id = (int) $service->id;
            $a->client_id = $this->client($hall, $bobur);
            $a->consumer_id = (int) $bobur->id;
            $a->guests = 150;
            $a->starts_at = $start;
            $a->ends_at = $end;
            $a->status = Appointment::STATUS_PENDING;
            $a->source = Appointment::SOURCE_APP;
            $a->deposit_tiyin = $service->deposit_tiyin !== null ? (int) $service->deposit_tiyin : null;
            $a->paid = false;
            $a->notes = 'Kechqurun · 150 mehmon · 15 stol';
            $a->save(false);
            $this->stdout('  + rental booking ' . $day->format('Y-m-d') . " evening\n");
            return;
        }
        $this->stdout("  skip rental booking: no free evening found\n");
    }

    private function seedDilnoza(): void
    {
        // Intentionally empty account (first-run UX); just make sure it exists.
        if (isset($this->consumers['+998900000003'])) {
            $this->stdout("-- Dilnoza (+998900000003): empty account\n");
        }
    }

    private function summary(): void
    {
        $this->stdout("\n-- businesses\n");
        $this->stdout(sprintf("  %-16s %-8s %6s %6s\n", 'slug', 'engine', 'avg', 'count'));
        foreach ($this->biz as $b) {
            $b->refresh();
            $this->stdout(sprintf("  %-16s %-8s %6.2f %6d\n", $b->slug, (string) ($b->engine ?: 'slot'), (float) $b->rating_avg, (int) $b->rating_count));
        }
        $this->stdout("\n-- demo consumers (OTP " . (string) (Yii::$app->params['consumer.otp.demo_code'] ?? '1111') . ")\n");
        $this->stdout(sprintf("  %-14s %-18s %5s %6s %7s %5s\n", 'phone', 'name', 'appts', 'orders', 'reviews', 'favs'));
        foreach (self::DEMO as [$phone]) {
            $c = $this->consumers[$phone] ?? null;
            if ($c === null) {
                continue;
            }
            $id = (int) $c->id;
            $this->stdout(sprintf(
                "  %-14s %-18s %5d %6d %7d %5d\n",
                $phone,
                (string) $c->name,
                (int) (new Query())->from(Appointment::tableName())->where(['consumer_id' => $id])->count(),
                (int) (new Query())->from(Order::tableName())->where(['consumer_id' => $id])->count(),
                (int) (new Query())->from(Review::tableName())->where(['consumer_id' => $id])->count(),
                (int) (new Query())->from(ConsumerFavorite::tableName())->where(['consumer_id' => $id])->count()
            ));
        }
    }

    // ---------------------------------------------------------------- helpers

    private function reviewer(int $k): ConsumerUser
    {
        [$phone] = self::REVIEWERS[$k % count(self::REVIEWERS)];
        return $this->consumers[$phone];
    }

    private function consumerById(int $id): ?ConsumerUser
    {
        foreach ($this->consumers as $c) {
            if ((int) $c->id === $id) {
                return $c;
            }
        }
        return ConsumerUser::findOne($id);
    }

    /** @return string[] */
    private function demoPhones(): array
    {
        return array_map(static fn (array $d) => $d[0], self::DEMO);
    }

    private function ownerId(int $businessId): ?int
    {
        $id = BusinessUser::find()
            ->select(['user_id'])
            ->andWhere(['business_id' => $businessId, 'role' => Business::ROLE_OWNER])
            ->orderBy(['id' => SORT_ASC])
            ->scalar();
        return $id !== false && $id !== null ? (int) $id : null;
    }

    /** @return Appointment[] completed, unclaimed, unreviewed, not a demo phone's */
    private function reviewableAppointments(int $bid, int $limit): array
    {
        return Appointment::find()
            ->alias('a')
            ->leftJoin(['r' => Review::tableName()], 'r.appointment_id = a.id')
            ->leftJoin(['c' => '{{%clients}}'], 'c.id = a.client_id')
            ->andWhere(['a.business_id' => $bid, 'a.status' => Appointment::STATUS_COMPLETED, 'a.consumer_id' => null, 'r.id' => null])
            ->andWhere(['<', 'a.ends_at', gmdate('Y-m-d H:i:s')])
            ->andWhere(['or', ['c.phone' => null], ['not in', 'c.phone', $this->demoPhones()]])
            ->orderBy(['a.ends_at' => SORT_DESC, 'a.id' => SORT_DESC])
            ->limit($limit)
            ->all();
    }

    /** @return Order[] delivered, unclaimed, unreviewed, not a demo phone's */
    private function reviewableOrders(int $bid, int $limit): array
    {
        return Order::find()
            ->alias('o')
            ->leftJoin(['r' => Review::tableName()], 'r.order_id = o.id')
            ->andWhere(['o.business_id' => $bid, 'o.status' => Order::STATUS_DELIVERED, 'o.consumer_id' => null, 'r.id' => null])
            ->andWhere(['or', ['o.customer_phone' => null], ['not in', 'o.customer_phone', $this->demoPhones()]])
            ->orderBy(['o.created_at' => SORT_DESC, 'o.id' => SORT_DESC])
            ->limit($limit)
            ->all();
    }

    private function insertReview(Business $b, ConsumerUser $reviewer, int $k, string $vertical, ?int $ownerId, array $refs, int $baseTs): void
    {
        $rating = self::RATINGS[$k % count(self::RATINGS)];
        $pool = self::COMMENTS[$vertical][$rating >= 4 ? 'high' : 'mid'];
        $comment = $pool[((int) $b->id * 3 + $k) % count($pool)];
        $now = time();
        $created = min($now - 600, $baseTs + ((($k * 7) % 48) + 1) * 3600);

        $row = [
            'business_id' => (int) $b->id,
            'consumer_id' => (int) $reviewer->id,
            'appointment_id' => $refs['appointment_id'] ?? null,
            'order_id' => $refs['order_id'] ?? null,
            'staff_id' => $refs['staff_id'] ?? null,
            'service_id' => $refs['service_id'] ?? null,
            'author_name' => Review::maskName($reviewer->name),
            'rating' => $rating,
            'comment' => $comment,
            'status' => Review::STATUS_PUBLISHED,
            'reply' => null,
            'replied_at' => null,
            'replied_by' => null,
            'created_at' => $created,
            'updated_at' => $created,
        ];
        // ~40% get an owner reply.
        if ($ownerId !== null && in_array($k % 5, [0, 2], true)) {
            $row['reply'] = $rating >= 4
                ? self::REPLIES_POSITIVE[$k % count(self::REPLIES_POSITIVE)]
                : self::REPLY_MID;
            $row['replied_at'] = min($now - 60, $created + (3 + $k % 18) * 3600);
            $row['replied_by'] = $ownerId;
            $row['updated_at'] = $row['replied_at'];
        }
        Yii::$app->db->createCommand()->insert(Review::tableName(), $row)->execute();
    }

    /**
     * Insert a completed visit around $daysAgo days back (local daytime), free of
     * overlaps (per staff; per business for rental). Returns null if none fits.
     */
    private function insertPastAppointment(Business $b, ConsumerUser $consumer, int $daysAgo): ?Appointment
    {
        $bid = (int) $b->id;
        $staff = $this->firstStaff($bid);
        $service = $this->firstService($bid, true) ?? $this->firstService($bid, false);
        if ($staff === null || $service === null) {
            $this->stdout("  skip past visit for {$b->slug}: no active staff/service\n");
            return null;
        }
        $rental = (string) $b->engine === 'rental';
        $tz = $this->tz($b);
        $utc = new DateTimeZone('UTC');
        $today = (new DateTimeImmutable('now', $tz))->setTime(0, 0);
        $duration = max(15, (int) $service->duration_min);

        for ($try = 0; $try < 40; $try++) {
            $day = $today->modify('-' . ($daysAgo + intdiv($try, 4)) . ' days');
            if ($rental) {
                $morning = ($try % 2) === 0;
                $start = $day->setTime($morning ? 10 : 18, 0);
                $end = $day->setTime($morning ? 16 : 23, 0);
            } else {
                $start = $day->setTime(10 + (($daysAgo + $try * 3) % 8), ($try % 2) * 30);
                $end = $start->modify('+' . $duration . ' minutes');
            }
            $startStr = $start->setTimezone($utc)->format('Y-m-d H:i:s');
            $endStr = $end->setTimezone($utc)->format('Y-m-d H:i:s');
            if ($this->overlaps($bid, $rental ? null : (int) $staff->id, $startStr, $endStr)) {
                continue;
            }

            $a = new Appointment();
            $a->business_id = $bid;
            $a->staff_id = (int) $staff->id;
            $a->service_id = (int) $service->id;
            $a->client_id = $this->client($b, $consumer);
            $a->consumer_id = (int) $consumer->id;
            $a->starts_at = $startStr;
            $a->ends_at = $endStr;
            $a->status = Appointment::STATUS_COMPLETED;
            $a->source = Appointment::SOURCE_APP;
            $a->deposit_tiyin = null;
            $a->paid = false;
            if ($rental) {
                $guests = 120 + ($daysAgo * 10) % 180;
                $a->guests = $guests;
                $a->notes = (($try % 2) === 0 ? 'Ertalab' : 'Kechqurun') . ' · ' . $guests . ' mehmon · ' . (int) ceil($guests / 10) . ' stol';
            }
            $a->save(false);
            $ts = $start->getTimestamp() - 2 * 86400;
            Yii::$app->db->createCommand()->update(Appointment::tableName(), ['created_at' => $ts, 'updated_at' => $end->getTimestamp()], ['id' => (int) $a->id])->execute();
            $a->refresh();
            return $a;
        }
        return null;
    }

    private function insertUpcomingSlot(Business $b, ConsumerUser $consumer, ?int $clientId): void
    {
        $bid = (int) $b->id;
        $staff = $this->firstStaff($bid);
        $service = $this->firstService($bid, true);
        if ($staff === null || $service === null) {
            $this->stdout("  skip upcoming booking: no active staff/bookable service\n");
            return;
        }
        $tz = $this->tz($b);
        $today = new DateTimeImmutable('now', $tz);
        $availability = new AvailabilityService();
        for ($d = 0; $d <= 7; $d++) {
            $date = $today->modify('+' . $d . ' days')->format('Y-m-d');
            $slots = $availability->slots($staff, $date, (int) $service->id)['slots'];
            if ($slots === []) {
                continue;
            }
            $slot = $slots[0];
            $a = new Appointment();
            $a->business_id = $bid;
            $a->staff_id = (int) $staff->id;
            $a->service_id = (int) $service->id;
            $a->client_id = $clientId ?? $this->client($b, $consumer);
            $a->consumer_id = (int) $consumer->id;
            $a->starts_at = $slot['start_utc'];
            $a->ends_at = $slot['end_utc'];
            $a->status = Appointment::STATUS_PENDING;
            $a->source = Appointment::SOURCE_APP;
            $a->deposit_tiyin = $service->deposit_tiyin !== null ? (int) $service->deposit_tiyin : null;
            $a->paid = false;
            $a->save(false);
            $this->stdout("  + upcoming {$b->slug} {$date} {$slot['start_local']}\n");
            return;
        }
        $this->stdout("  skip upcoming booking: no free slot in 7 days\n");
    }

    /** Insert an app order with 1-2 active menu items, backdated $daysAgo days. */
    private function insertOrder(Business $b, ConsumerUser $consumer, string $status, int $daysAgo): ?Order
    {
        $bid = (int) $b->id;
        $services = Service::find()
            ->andWhere(['business_id' => $bid, 'is_active' => 1])
            ->orderBy(['id' => SORT_ASC])
            ->all();
        if ($services === []) {
            return null;
        }
        $n = count($services);
        $first = $services[($daysAgo * 7 + (int) $consumer->id) % $n];
        $lines = [[$first, 1 + $daysAgo % 2]];
        if ($n > 1 && $daysAgo % 3 === 0) {
            $second = $services[($daysAgo * 7 + (int) $consumer->id + 1) % $n];
            if ((int) $second->id !== (int) $first->id) {
                $lines[] = [$second, 1];
            }
        }

        $ts = time() - $daysAgo * 86400 - (($daysAgo * 37) % 600) * 60;
        $total = 0;
        foreach ($lines as [$svc, $qty]) {
            $total += (int) $svc->price_tiyin * $qty;
        }
        $o = new Order();
        $o->business_id = $bid;
        $o->client_id = $this->client($b, $consumer);
        $o->consumer_id = (int) $consumer->id;
        $o->customer_name = (string) $consumer->name;
        $o->customer_phone = (string) $consumer->phone;
        $o->status = $status;
        $o->total_tiyin = $total;
        $o->source = 'app';
        $o->save(false);
        foreach ($lines as [$svc, $qty]) {
            $line = new OrderItem();
            $line->order_id = (int) $o->id;
            $line->business_id = $bid;
            $line->service_id = (int) $svc->id;
            $line->name = (string) $svc->name;
            $line->price_tiyin = (int) $svc->price_tiyin;
            $line->qty = $qty;
            $line->save(false);
        }
        $db = Yii::$app->db;
        $db->createCommand()->update(Order::tableName(), ['created_at' => $ts, 'updated_at' => $ts + 3 * 3600], ['id' => (int) $o->id])->execute();
        $db->createCommand()->update(OrderItem::tableName(), ['created_at' => $ts], ['order_id' => (int) $o->id])->execute();
        $o->refresh();
        return $o;
    }

    private function client(Business $b, ConsumerUser $consumer): ?int
    {
        return (new BookingService())->upsertClient(
            (int) $b->id,
            ['phone' => (string) $consumer->phone, 'name' => null],
            (string) $consumer->name
        );
    }

    private function favorite(ConsumerUser $consumer, Business $b): void
    {
        $exists = ConsumerFavorite::find()->where(['consumer_id' => (int) $consumer->id, 'business_id' => (int) $b->id])->exists();
        if (!$exists) {
            $f = new ConsumerFavorite();
            $f->consumer_id = (int) $consumer->id;
            $f->business_id = (int) $b->id;
            $f->save(false);
        }
    }

    private function firstStaff(int $bid): ?Staff
    {
        return Staff::find()->andWhere(['business_id' => $bid, 'is_active' => 1])->orderBy(['id' => SORT_ASC])->one();
    }

    private function firstService(int $bid, bool $bookableOnly): ?Service
    {
        $q = Service::find()->andWhere(['business_id' => $bid, 'is_active' => 1]);
        if ($bookableOnly) {
            $q->andWhere(['online_bookable' => 1]);
        }
        return $q->orderBy(['id' => SORT_ASC])->one();
    }

    /** Live overlap: per staff when $staffId given, else business-wide. */
    private function overlaps(int $bid, ?int $staffId, string $start, string $end): bool
    {
        $q = Appointment::find()
            ->andWhere(['business_id' => $bid])
            ->andWhere(['not in', 'status', Appointment::RELEASED_STATUSES])
            ->andWhere(['<', 'starts_at', $end])
            ->andWhere(['>', 'ends_at', $start]);
        if ($staffId !== null) {
            $q->andWhere(['staff_id' => $staffId]);
        }
        return $q->exists();
    }

    private function tz(Business $b): DateTimeZone
    {
        return new DateTimeZone(BookingService::businessTimezone($b));
    }

    private function utcTs(string $utc): int
    {
        try {
            return (new DateTimeImmutable($utc, new DateTimeZone('UTC')))->getTimestamp();
        } catch (\Throwable $e) {
            return time() - 86400;
        }
    }
}
