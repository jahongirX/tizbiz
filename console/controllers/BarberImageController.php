<?php

namespace console\controllers;

use common\models\Business;
use common\models\Service;
use common\models\Staff;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\helpers\Console;
use yii\helpers\FileHelper;

/**
 * Generates placeholder artwork for a barbershop's masters and services, so a
 * demo shop does not show empty avatars and blank service cards. Drawn locally
 * with GD (no stock photos, nothing fetched), written into the API's uploads
 * directory exactly where POST /v1/uploads would put them.
 *
 * Usage: php yii barber-image/generate [slug] [baseUrl]
 * Only fills rows that have no image yet; re-running is safe.
 */
class BarberImageController extends Controller
{
    /** A master's disc and a service tile share this palette, one hue each. */
    private const FONT_CANDIDATES = [
        '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
        '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/Library/Fonts/Arial Bold.ttf',
    ];

    public bool $force = false;
    /** 'all' | 'masters' | 'services' */
    public string $only = 'all';

    public function options($actionID): array
    {
        return array_merge(parent::options($actionID), ['force', 'only']);
    }

    public function optionAliases(): array
    {
        return array_merge(parent::optionAliases(), ['f' => 'force']);
    }

    public function actionGenerate(string $slug = 'jalolbek', string $baseUrl = 'http://127.0.0.1:8899'): int
    {
        $business = Business::findOne(['slug' => $slug]);
        if ($business === null) {
            $this->stderr("Business '{$slug}' not found.\n", Console::FG_RED);
            return ExitCode::UNSPECIFIED_ERROR;
        }
        if (!function_exists('imagecreatetruecolor')) {
            $this->stderr("PHP GD is required.\n", Console::FG_RED);
            return ExitCode::UNSPECIFIED_ERROR;
        }

        $sub = date('Ym');
        $dir = \Yii::getAlias('@api/web/uploads/' . $sub);
        FileHelper::createDirectory($dir, 0775);
        $baseUrl = rtrim($baseUrl, '/');

        $masters = 0;
        foreach (Staff::find()->where(['business_id' => $business->id])->orderBy(['id' => SORT_ASC])->all() as $i => $staff) {
            if ($this->only === 'services' || (!$this->force && $staff->avatar)) {
                continue;
            }
            $file = $this->avatar($this->initials($staff->name), $this->hue($i));
            $name = 'staff-' . $staff->id . '-' . bin2hex(random_bytes(4)) . '.png';
            imagepng($file, $dir . '/' . $name, 9);
            $staff->avatar = $baseUrl . '/uploads/' . $sub . '/' . $name;
            $staff->save(false, ['avatar', 'updated_at']);
            $masters++;
        }

        $services = 0;
        foreach (Service::find()->where(['business_id' => $business->id])->orderBy(['id' => SORT_ASC])->all() as $i => $service) {
            if ($this->only === 'masters' || (!$this->force && $service->image)) {
                continue;
            }
            $file = $this->serviceTile($service->name, $this->hue($i + 3));
            $name = 'service-' . $service->id . '-' . bin2hex(random_bytes(4)) . '.png';
            imagepng($file, $dir . '/' . $name, 9);
            $service->image = $baseUrl . '/uploads/' . $sub . '/' . $name;
            $service->save(false, ['image', 'updated_at']);
            $services++;
        }

        $this->stdout(sprintf("Generated %d master avatar(s) and %d service image(s) for '%s'.\n", $masters, $services, $slug));
        return ExitCode::OK;
    }

    /** Golden-angle rotation keeps neighbouring rows visually distinct. */
    private function hue(int $index): int
    {
        return (int) fmod(205 + $index * 137.5, 360);
    }

    private function initials(string $name): string
    {
        $parts = preg_split('/\s+/u', trim($name)) ?: [];
        $out = '';
        foreach (array_slice($parts, 0, 2) as $p) {
            $out .= mb_strtoupper(mb_substr($p, 0, 1));
        }
        return $out !== '' ? $out : '?';
    }

    private function font(): ?string
    {
        foreach (self::FONT_CANDIDATES as $path) {
            if (is_file($path)) {
                return $path;
            }
        }
        return null;
    }

    /** Round-ish portrait: a soft vertical gradient with the initials on top. */
    private function avatar(string $initials, int $hue)
    {
        $size = 320;
        $img = imagecreatetruecolor($size, $size);
        $this->gradient($img, $size, $size, $hue);

        // A faint ring keeps the disc from melting into a dark page.
        $ring = imagecolorallocatealpha($img, 255, 255, 255, 100);
        imagesetthickness($img, 4);
        imageellipse($img, $size / 2, $size / 2, $size - 26, $size - 26, $ring);

        $white = imagecolorallocate($img, 255, 255, 255);
        $font = $this->font();
        if ($font !== null) {
            $fs = 108;
            $box = imagettfbbox($fs, 0, $font, $initials);
            $w = $box[2] - $box[0];
            $h = $box[1] - $box[7];
            imagettftext($img, $fs, 0, (int) (($size - $w) / 2), (int) (($size + $h) / 2), $white, $font, $initials);
        } else {
            imagestring($img, 5, (int) ($size / 2 - 20), (int) ($size / 2 - 8), $initials, $white);
        }
        return $img;
    }

    /** Wide tile: gradient, a drawn pair of scissors, and the service name. */
    private function serviceTile(string $name, int $hue)
    {
        $w = 480;
        $h = 320;
        $img = imagecreatetruecolor($w, $h);
        $this->gradient($img, $w, $h, $hue);

        $ink = imagecolorallocatealpha($img, 255, 255, 255, 40);
        imagesetthickness($img, 7);
        // Blades crossing, then the two finger holes: a scissors silhouette.
        imageline($img, 170, 84, 316, 236, $ink);
        imageline($img, 310, 84, 164, 236, $ink);
        imagesetthickness($img, 6);
        imageellipse($img, 160, 244, 40, 40, $ink);
        imageellipse($img, 320, 244, 40, 40, $ink);

        $font = $this->font();
        $white = imagecolorallocate($img, 255, 255, 255);
        if ($font !== null) {
            $label = mb_strimwidth($name, 0, 26, '…', 'UTF-8');
            $fs = 22;
            $box = imagettfbbox($fs, 0, $font, $label);
            $tw = $box[2] - $box[0];
            imagettftext($img, $fs, 0, (int) (($w - $tw) / 2), $h - 34, $white, $font, $label);
        }
        return $img;
    }

    /** Vertical gradient from a light to a dark shade of one hue. */
    private function gradient($img, int $w, int $h, int $hue): void
    {
        for ($y = 0; $y < $h; $y++) {
            $t = $y / max(1, $h - 1);
            [$r, $g, $b] = $this->hsl($hue / 360, 0.42 - 0.06 * $t, 0.46 - 0.20 * $t);
            $c = imagecolorallocate($img, $r, $g, $b);
            imageline($img, 0, $y, $w, $y, $c);
        }
    }

    /** @return array{0:int,1:int,2:int} */
    private function hsl(float $h, float $s, float $l): array
    {
        if ($s <= 0) {
            $v = (int) round($l * 255);
            return [$v, $v, $v];
        }
        $q = $l < 0.5 ? $l * (1 + $s) : $l + $s - $l * $s;
        $p = 2 * $l - $q;
        return [
            (int) round($this->channel($p, $q, $h + 1 / 3) * 255),
            (int) round($this->channel($p, $q, $h) * 255),
            (int) round($this->channel($p, $q, $h - 1 / 3) * 255),
        ];
    }

    private function channel(float $p, float $q, float $t): float
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
}
