<?php

namespace console\controllers;

use common\helpers\Categories;
use common\models\Business;
use common\models\BusinessBranch;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\helpers\Console;
use yii\helpers\Json;

/**
 * Directory listings that are not (yet) TizBiz customers, and business branches.
 *
 *   yii listing/import @runtime/osm.json osm     upsert unclaimed listings from a JSON file
 *   yii listing/branches aziza-tortlari b.json   replace a business's branches from a JSON file
 *   yii listing/demo-termiz                      move the demo businesses to Termiz
 *
 * Imported listings are unclaimed: listed in Bizcat with their public info (name,
 * address, phone, map point) but with online booking off and no mini-site, until
 * the owner connects the business. A re-import updates the same rows (matched on
 * source + source_ref) and never touches a listing an owner has claimed.
 */
class ListingController extends Controller
{
    private const SOURCES = ['osm', 'web'];

    /**
     * @param string $file JSON array of {ref, name, category, address?, district?, city?,
     *                     phone?, lat?, lng?, hours?, website?, instagram?}
     */
    public function actionImport(string $file, string $source = 'osm'): int
    {
        if (!in_array($source, self::SOURCES, true)) {
            $this->stderr("source must be one of: " . implode(', ', self::SOURCES) . "\n", Console::FG_RED);
            return ExitCode::USAGE;
        }
        $rows = $this->readJson($file);
        if ($rows === null) {
            return ExitCode::DATAERR;
        }

        $created = $updated = $skipped = 0;
        foreach ($rows as $i => $row) {
            $ref = trim((string) ($row['ref'] ?? ''));
            $name = trim((string) ($row['name'] ?? ''));
            $category = (string) ($row['category'] ?? '');
            if ($ref === '' || $name === '' || !in_array($category, Categories::keys(), true)) {
                $this->stderr("row {$i}: needs ref, name and a known category; skipped\n", Console::FG_YELLOW);
                $skipped++;
                continue;
            }

            $b = Business::findOne(['source' => $source, 'source_ref' => $ref]);
            if ($b !== null && $b->is_claimed) {
                $skipped++; // the owner manages it now
                continue;
            }
            $isNew = $b === null;
            if ($isNew) {
                $b = new Business();
                $b->slug = $this->uniqueSlug($name);
                $b->source = $source;
                $b->source_ref = $ref;
                $b->is_claimed = false;
                $b->status = Business::STATUS_ACTIVE;
                $b->tariff = 'free';
            }
            $b->name = mb_substr($name, 0, 160);
            $b->category = $category;
            $b->engine = Categories::engine($category);
            $b->is_listed = true;
            $b->online_booking_enabled = false;
            $b->city = $this->str($row['city'] ?? null, 64) ?? 'Termiz';
            $b->district = $this->str($row['district'] ?? null, 64);
            $b->address = $this->str($row['address'] ?? null, 255);
            $b->phone = $this->str($row['phone'] ?? null, 32);
            $b->lat = isset($row['lat']) && is_numeric($row['lat']) ? (string) $row['lat'] : null;
            $b->lng = isset($row['lng']) && is_numeric($row['lng']) ? (string) $row['lng'] : null;
            $b->description = $this->description($row, $source);

            if (!$b->save()) {
                $this->stderr("row {$i} ({$name}): " . Json::encode($b->getFirstErrors()) . "\n", Console::FG_RED);
                $skipped++;
                continue;
            }
            $isNew ? $created++ : $updated++;
        }

        $this->stdout("created {$created}, updated {$updated}, skipped {$skipped}\n", Console::FG_GREEN);
        return ExitCode::OK;
    }

    /**
     * Replaces the active branches of a business.
     *
     * @param string $file JSON array of {name, city?, district?, address?, landmark?, phone?, hours?, lat?, lng?}
     */
    public function actionBranches(string $slug, string $file): int
    {
        $business = Business::findOne(['slug' => $slug]);
        if ($business === null) {
            $this->stderr("business {$slug} not found\n", Console::FG_RED);
            return ExitCode::DATAERR;
        }
        $rows = $this->readJson($file);
        if ($rows === null) {
            return ExitCode::DATAERR;
        }

        $tx = BusinessBranch::getDb()->beginTransaction();
        try {
            BusinessBranch::deleteAll(['business_id' => (int) $business->id]);
            foreach (array_values($rows) as $i => $row) {
                $br = new BusinessBranch([
                    'business_id' => (int) $business->id,
                    'name' => $this->str($row['name'] ?? null, 128) ?? ($business->name . ' #' . ($i + 1)),
                    'city' => $this->str($row['city'] ?? null, 64),
                    'district' => $this->str($row['district'] ?? null, 64),
                    'address' => $this->str($row['address'] ?? null, 255),
                    'landmark' => $this->str($row['landmark'] ?? null, 255),
                    'phone' => $this->str($row['phone'] ?? null, 32),
                    'hours' => $this->str($row['hours'] ?? null, 64),
                    'lat' => isset($row['lat']) && is_numeric($row['lat']) ? (string) $row['lat'] : null,
                    'lng' => isset($row['lng']) && is_numeric($row['lng']) ? (string) $row['lng'] : null,
                    'sort' => $i,
                    'is_active' => true,
                ]);
                if (!$br->save()) {
                    throw new \RuntimeException("branch {$i}: " . Json::encode($br->getFirstErrors()));
                }
            }
            $business->branches_count = count($rows);
            $business->save(false, ['branches_count']);
            $tx->commit();
        } catch (\Throwable $e) {
            $tx->rollBack();
            $this->stderr($e->getMessage() . "\n", Console::FG_RED);
            return ExitCode::DATAERR;
        }

        $this->stdout("{$slug}: " . count($rows) . " branches\n", Console::FG_GREEN);
        return ExitCode::OK;
    }

    /** Moves the demo businesses to Termiz (address, district, map point). Idempotent. */
    public function actionDemoTermiz(): int
    {
        $places = [
            'shox-barber' => ['Termiz shahri', "Termiz, At-Termiziy ko'chasi 18", 37.2398, 67.2829],
            'sanatrix' => ['Termiz shahri', "Termiz, Alisher Navoiy ko'chasi 52", 37.2352, 67.2905],
            'restoran' => ['Termiz shahri', "Termiz, Sharof Rashidov ko'chasi 41", 37.2286, 67.2745],
            'serenada' => ['Termiz shahri', "Termiz, Islom Karimov ko'chasi 210", 37.2461, 67.3021],
            'aziza-tortlari' => ['Termiz shahri', "Termiz, Al-Hakim at-Termiziy ko'chasi 23G", 37.242058, 67.281788],
        ];
        foreach ($places as $slug => [$district, $address, $lat, $lng]) {
            $n = Business::updateAll([
                'city' => 'Termiz',
                'district' => $district,
                'address' => $address,
                'lat' => $lat,
                'lng' => $lng,
                'map_url' => null,
            ], ['slug' => $slug]);
            $this->stdout(str_pad($slug, 16) . ($n ? "moved to Termiz\n" : "not found\n"));
        }
        return ExitCode::OK;
    }

    /** @return array<int, array<string, mixed>>|null */
    private function readJson(string $file): ?array
    {
        $path = \Yii::getAlias($file);
        if (!is_file($path)) {
            $this->stderr("file not found: {$path}\n", Console::FG_RED);
            return null;
        }
        $rows = Json::decode((string) file_get_contents($path));
        if (!is_array($rows) || !array_is_list($rows)) {
            $this->stderr("expected a JSON array\n", Console::FG_RED);
            return null;
        }
        return $rows;
    }

    private function str(mixed $v, int $max): ?string
    {
        if (!is_string($v) && !is_numeric($v)) {
            return null;
        }
        $t = trim((string) $v);
        return $t === '' ? null : mb_substr($t, 0, $max);
    }

    /** Opening hours and links, plus where the listing came from. */
    private function description(array $row, string $source): string
    {
        $lines = [];
        if (($h = $this->str($row['hours'] ?? null, 120)) !== null) {
            $lines[] = 'Ish vaqti: ' . $h;
        }
        if (($w = $this->str($row['website'] ?? null, 200)) !== null) {
            $lines[] = 'Sayt: ' . $w;
        }
        if (($ig = $this->str($row['instagram'] ?? null, 120)) !== null) {
            $lines[] = 'Instagram: ' . $ig;
        }
        $lines[] = $source === 'osm'
            ? "Ma'lumotlar OpenStreetMap'dan olingan (© OpenStreetMap hissadorlari). Biznes hali Bizcat'ga ulanmagan."
            : "Ma'lumotlar ochiq manbalardan olingan. Biznes hali Bizcat'ga ulanmagan.";
        return implode("\n", $lines);
    }

    private function uniqueSlug(string $name): string
    {
        $base = $this->slugify($name);
        if (strlen($base) < 3) {
            $base = 'biznes';
        }
        $base = substr($base, 0, 60);
        $slug = $base;
        if (Business::find()->where(['slug' => $slug])->exists()) {
            $slug = $base . '-termiz';
        }
        for ($n = 2; Business::find()->where(['slug' => $slug])->exists(); $n++) {
            $slug = $base . '-termiz-' . $n;
        }
        return $slug;
    }

    private function slugify(string $s): string
    {
        static $map = [
            'а' => 'a', 'б' => 'b', 'в' => 'v', 'г' => 'g', 'д' => 'd', 'е' => 'e', 'ё' => 'yo', 'ж' => 'j',
            'з' => 'z', 'и' => 'i', 'й' => 'y', 'к' => 'k', 'л' => 'l', 'м' => 'm', 'н' => 'n', 'о' => 'o',
            'п' => 'p', 'р' => 'r', 'с' => 's', 'т' => 't', 'у' => 'u', 'ф' => 'f', 'х' => 'x', 'ц' => 'ts',
            'ч' => 'ch', 'ш' => 'sh', 'щ' => 'sh', 'ъ' => '', 'ы' => 'i', 'ь' => '', 'э' => 'e', 'ю' => 'yu',
            'я' => 'ya', 'ў' => 'o', 'қ' => 'q', 'ғ' => 'g', 'ҳ' => 'h',
        ];
        $s = mb_strtolower($s);
        $s = strtr($s, $map);
        $s = str_replace(["o'", "g'", "o‘", "g‘", "o’", "g’", 'ʻ', '‘', '’', "'", '`'], ['o', 'g', 'o', 'g', 'o', 'g', '', '', '', '', ''], $s);
        $s = (string) preg_replace('/[^a-z0-9]+/', '-', $s);
        return trim((string) preg_replace('/-+/', '-', $s), '-');
    }
}
