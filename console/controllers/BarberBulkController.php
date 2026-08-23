<?php

namespace console\controllers;

use api\modules\finance\services\SaleService;
use api\modules\loyalty\services\LoyaltyService;
use common\models\Appointment;
use common\models\AppointmentItem;
use common\models\Business;
use common\models\Client;
use common\models\ClientCategory;
use common\models\ClientCategoryAssignment;
use common\models\Service;
use common\models\Staff;
use common\models\SubscriptionType;
use common\models\TimeOff;
use common\models\Transaction;
use Yii;
use yii\base\Event;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\helpers\Console;

/**
 * Fills a barbershop with enough history to demo every screen: a client base
 * with segments, months of appointments across all masters (including combined
 * "soch + soqol" visits), the money each finished visit earned, cashback, a few
 * online deposits, subscription types and a master's day off.
 *
 * Usage: php yii barber-bulk/generate [slug] [pastDays] [futureDays]
 *
 * Deterministic (seeded RNG), so a re-run against a fresh database produces the
 * same shop. Existing appointments are left alone; it only adds.
 */
class BarberBulkController extends Controller
{
    private const FIRST = [
        'Aziz', 'Sardor', 'Jasur', 'Bekzod', 'Otabek', 'Doniyor', 'Shohruh', 'Ulug‘bek',
        'Javohir', 'Sanjar', 'Islom', 'Diyor', 'Akmal', 'Farrux', 'Kamron', 'Rustam',
        'Temur', 'Nodir', 'Alisher', 'Bobur', 'Sherzod', 'Umid', 'Ravshan', 'Zafar',
        'Murod', 'Behruz', 'Elyor', 'Xurshid', 'Ilhom', 'Mirzo',
    ];
    private const LAST = [
        'Karimov', 'Aliyev', 'Toshpulatov', 'Rahimov', 'Yo‘ldoshev', 'Ergashev',
        'Nazarov', 'Sattorov', 'Qodirov', 'Tursunov', 'Sobirov', 'Xolmatov',
        'Jo‘rayev', 'Mahmudov', 'Ismoilov', 'Nurmatov',
    ];
    private const NOTES = [
        'Mashinka #2, yon tomonlar kalta', 'Fade, tepasi uzun qoladi', null,
        'Soqolni ustara bilan', 'Mashinka #1, juda kalta', null,
        'Bolasi bilan keladi', 'Doim shanba kuni keladi', 'Gel ishlatmaydi',
        'Kofe bilan kutadi', null, 'Qaychi bilan, mashinkasiz',
    ];

    /** Deterministic pseudo-randomness: same seed -> same demo shop. */
    private int $seed = 20260821;

    private function rand(int $max): int
    {
        $this->seed = ($this->seed * 1103515245 + 12345) & 0x7FFFFFFF;
        // Take the high bits: an LCG's low bits have a very short period, which
        // made rare outcomes (a 1-in-20 no-show) never come up.
        return $max > 0 ? (int) (($this->seed >> 16) % $max) : 0;
    }

    private function pick(array $list)
    {
        return $list[$this->rand(count($list))];
    }

    public function actionGenerate(string $slug = 'jalolbek', int $pastDays = 75, int $futureDays = 12): int
    {
        $business = Business::findOne(['slug' => $slug]);
        if ($business === null) {
            $this->stderr("Business '{$slug}' not found.\n", Console::FG_RED);
            return ExitCode::UNSPECIFIED_ERROR;
        }
        $bid = (int) $business->id;

        $masters = Staff::find()->where(['business_id' => $bid, 'is_active' => 1])->orderBy(['id' => SORT_ASC])->all();
        $services = Service::find()->where(['business_id' => $bid, 'is_active' => 1])->orderBy(['id' => SORT_ASC])->all();
        if ($masters === [] || $services === []) {
            $this->stderr("Run seed/barber first (no masters or services).\n", Console::FG_RED);
            return ExitCode::UNSPECIFIED_ERROR;
        }

        // Money and cashback are produced by the same handlers the app uses, so
        // seeded history matches what a real day would have written.
        Yii::$app->on('appointmentCompleted', [LoyaltyService::class, 'onAppointmentCompleted']);
        Yii::$app->on('appointmentCompleted', [SaleService::class, 'onAppointmentCompleted']);

        $clients = $this->clients($bid);
        $categories = $this->categories($bid);
        $this->subscriptions($bid);
        $this->timeOff($masters);

        [$made, $completed] = $this->appointments($bid, $masters, $services, $clients, $pastDays, $futureDays);
        $this->deposits($bid);
        $this->assignCategories($bid, $categories);

        $this->stdout(sprintf(
            "Bulk seed for '%s': %d clients, %d appointments (%d completed), categories + subscriptions + time off.\n",
            $slug,
            count($clients),
            $made,
            $completed
        ));
        return ExitCode::OK;
    }

    /** @return Client[] */
    private function clients(int $bid): array
    {
        $existing = Client::find()->where(['business_id' => $bid])->all();
        $target = 34;
        $i = 0;
        while (count($existing) < $target && $i < 200) {
            $i++;
            $phone = '+9989012' . str_pad((string) (30000 + $i), 5, '0', STR_PAD_LEFT);
            if (Client::find()->where(['business_id' => $bid, 'phone' => $phone])->exists()) {
                continue;
            }
            $client = new Client([
                'business_id' => $bid,
                'name' => $this->pick(self::FIRST) . ' ' . $this->pick(self::LAST),
                'phone' => $phone,
                'notes' => $this->pick(self::NOTES),
                'tags' => [],
            ]);
            $client->save(false);
            $existing[] = $client;
        }
        return $existing;
    }

    /** @return ClientCategory[] */
    private function categories(int $bid): array
    {
        $defs = [['VIP', '#f59e0b', 0], ['Doimiy', '#22c55e', 1], ['Yangi', '#3b82f6', 2]];
        $out = [];
        foreach ($defs as [$name, $color, $sort]) {
            $cat = ClientCategory::findOne(['business_id' => $bid, 'name' => $name]);
            if ($cat === null) {
                $cat = new ClientCategory([
                    'business_id' => $bid, 'name' => $name, 'color' => $color, 'sort' => $sort,
                ]);
                $cat->save(false);
            }
            $out[$name] = $cat;
        }
        return $out;
    }

    private function subscriptions(int $bid): void
    {
        $defs = [
            ['10 ta soch olish', 10, 40000000, 180],
            ['4 ta soqol olish', 4, 10000000, 90],
        ];
        foreach ($defs as [$name, $visits, $price, $days]) {
            if (SubscriptionType::find()->where(['business_id' => $bid, 'name' => $name])->exists()) {
                continue;
            }
            (new SubscriptionType([
                'business_id' => $bid, 'name' => $name, 'visits' => $visits,
                'price_tiyin' => $price, 'valid_days' => $days, 'is_active' => 1,
            ]))->save(false);
        }
    }

    /** One master takes a day off next week, so the schedule is not uniform. */
    private function timeOff(array $masters): void
    {
        $date = gmdate('Y-m-d', time() + 6 * 86400);
        $staffId = (int) $masters[0]->id;
        if (TimeOff::find()->where(['staff_id' => $staffId, 'date' => $date])->exists()) {
            return;
        }
        (new TimeOff([
            'staff_id' => $staffId, 'date' => $date,
            'start_time' => null, 'end_time' => null, 'reason' => 'Dam olish kuni',
        ]))->save(false);
    }

    /** @return array{0:int,1:int} [created, completed] */
    private function appointments(int $bid, array $masters, array $services, array $clients, int $pastDays, int $futureDays): array
    {
        $made = 0;
        $completed = 0;
        $now = time();

        for ($d = -$pastDays; $d <= $futureDays; $d++) {
            $dayTs = $now + $d * 86400;
            $weekday = (int) gmdate('N', $dayTs);
            if ($weekday === 7) {
                continue; // shop is closed on Sunday
            }
            // Saturdays are the busy day; mid-week is quieter.
            $count = $weekday === 6 ? 7 + $this->rand(4) : 4 + $this->rand(4);

            for ($n = 0; $n < $count; $n++) {
                $master = $masters[$this->rand(count($masters))];
                $service = $services[$this->rand(count($services))];
                $client = $clients[$this->rand(count($clients))];

                // 09:00-19:00 local (04:00-14:00 UTC) on a 30-minute grid.
                $slot = $this->rand(20);
                $startTs = strtotime(gmdate('Y-m-d', $dayTs) . ' 04:00:00 UTC') + $slot * 1800;
                $duration = (int) $service->duration_min;

                // Every fourth visit adds a second service (soch + soqol).
                $extra = null;
                if ($this->rand(4) === 0) {
                    $candidate = $services[$this->rand(count($services))];
                    if ((int) $candidate->id !== (int) $service->id) {
                        $extra = $candidate;
                        $duration += (int) $candidate->duration_min;
                    }
                }

                $endTs = $startTs + $duration * 60;
                $startStr = gmdate('Y-m-d H:i:s', $startTs);
                $endStr = gmdate('Y-m-d H:i:s', $endTs);

                // Never double-book a master.
                $clash = Appointment::find()
                    ->where(['staff_id' => $master->id])
                    ->andWhere(['not in', 'status', Appointment::RELEASED_STATUSES])
                    ->andWhere(['<', 'starts_at', $endStr])
                    ->andWhere(['>', 'ends_at', $startStr])
                    ->exists();
                if ($clash) {
                    continue;
                }

                $status = $this->statusFor($startTs, $now);
                $appt = new Appointment([
                    'business_id' => $bid,
                    'client_id' => $client->id,
                    'staff_id' => $master->id,
                    'service_id' => $service->id,
                    'starts_at' => $startStr,
                    'ends_at' => $endStr,
                    'status' => $status,
                    'source' => $this->rand(3) === 0 ? Appointment::SOURCE_LINK : Appointment::SOURCE_ADMIN,
                    'deposit_tiyin' => $service->deposit_tiyin !== null ? (int) $service->deposit_tiyin : null,
                ]);
                $appt->save(false);
                $made++;

                if ($extra !== null) {
                    (new AppointmentItem([
                        'business_id' => $bid,
                        'appointment_id' => (int) $appt->id,
                        'kind' => AppointmentItem::KIND_SERVICE,
                        'ref_id' => (int) $extra->id,
                        'name' => (string) $extra->name,
                        'qty' => 1,
                        'price_tiyin' => (int) $extra->price_tiyin,
                    ]))->save(false);
                }

                if ($status === Appointment::STATUS_COMPLETED) {
                    Yii::$app->trigger('appointmentCompleted', new Event(['sender' => $appt]));
                    $completed++;
                }
            }
        }

        return [$made, $completed];
    }

    /** Past visits are mostly done, with the usual share of no-shows. */
    private function statusFor(int $startTs, int $now): string
    {
        if ($startTs > $now) {
            return $this->rand(5) === 0 ? Appointment::STATUS_PENDING : Appointment::STATUS_CONFIRMED;
        }
        $roll = $this->rand(20);
        if ($roll === 0) {
            return Appointment::STATUS_NO_SHOW;
        }
        if ($roll === 1) {
            return Appointment::STATUS_CANCELED;
        }
        return Appointment::STATUS_COMPLETED;
    }

    /** A few visits were prepaid online, so Moliya is not cash-only. */
    private function deposits(int $bid): void
    {
        $withDeposit = Appointment::find()
            ->where(['business_id' => $bid, 'status' => Appointment::STATUS_CONFIRMED])
            ->andWhere(['>', 'deposit_tiyin', 0])
            ->limit(6)
            ->all();

        foreach ($withDeposit as $appt) {
            $key = 'seed:deposit:' . $appt->id;
            if (Transaction::find()->where(['idempotency_key' => $key])->exists()) {
                continue;
            }
            (new Transaction([
                'business_id' => $bid,
                'appointment_id' => (int) $appt->id,
                'provider' => $this->rand(2) === 0 ? Transaction::PROVIDER_PAYME : Transaction::PROVIDER_CLICK,
                'type' => Transaction::TYPE_DEPOSIT,
                'status' => Transaction::STATUS_PAID,
                'amount_tiyin' => (int) $appt->deposit_tiyin,
                'idempotency_key' => $key,
            ]))->save(false);
        }
    }

    /** Segment the base the way the shop would: by how often someone comes. */
    private function assignCategories(int $bid, array $categories): void
    {
        $clients = Client::find()->where(['business_id' => $bid])->all();
        foreach ($clients as $client) {
            $visits = (int) Appointment::find()
                ->where(['client_id' => $client->id, 'status' => Appointment::STATUS_COMPLETED])
                ->count();

            $name = $visits >= 8 ? 'VIP' : ($visits >= 3 ? 'Doimiy' : 'Yangi');
            $cat = $categories[$name] ?? null;
            if ($cat === null) {
                continue;
            }
            $exists = ClientCategoryAssignment::find()
                ->where(['client_id' => $client->id, 'category_id' => $cat->id])
                ->exists();
            if (!$exists) {
                (new ClientCategoryAssignment([
                    'client_id' => (int) $client->id,
                    'category_id' => (int) $cat->id,
                ]))->save(false);
            }
        }
    }
}
