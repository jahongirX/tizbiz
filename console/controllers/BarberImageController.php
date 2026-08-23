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
            $file = $this->avatar($this->initials($staff->name), $this->hue($i), $i);
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
            $file = $this->serviceTile($service->name, $this->hue($i + 3), $i);
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

    /**
     * A drawn portrait rather than initials: head, hair and shoulders on a
     * coloured ground. The variant (hairstyle, beard, moustache) is picked from
     * the index, so masters stay recognisably different from each other.
     */
    private function avatar(string $initials, int $hue, int $variant)
    {
        $size = 320;
        $img = imagecreatetruecolor($size, $size);
        imageantialias($img, true);
        $this->gradient($img, $size, $size, $hue);

        $skin = imagecolorallocate($img, 236, 199, 168);
        $skinShade = imagecolorallocate($img, 214, 173, 141);
        $hair = imagecolorallocate($img, 42, 34, 30);
        $shirt = imagecolorallocate($img, 250, 250, 250);
        $ring = imagecolorallocatealpha($img, 255, 255, 255, 105);

        $cx = $size / 2;

        // Shoulders first, so the head overlaps them.
        imagefilledellipse($img, (int) $cx, 322, 250, 190, $shirt);
        // Collar notch.
        imagefilledellipse($img, (int) $cx, 232, 74, 54, $skinShade);

        // Head.
        imagefilledellipse($img, (int) $cx, 168, 146, 168, $skin);
        // Ears.
        imagefilledellipse($img, (int) $cx - 74, 172, 26, 34, $skinShade);
        imagefilledellipse($img, (int) $cx + 74, 172, 26, 34, $skinShade);

        // Hair always starts as a cap that follows the skull, then the face is
        // drawn back over it — that keeps every style attached to the head.
        $style = $variant % 3;
        imagefilledellipse($img, (int) $cx, 150, 152, 176, $hair);
        if ($style === 1) {
            // Flat top: square off the crown inside the skull's width.
            imagefilledrectangle($img, (int) $cx - 76, 74, (int) $cx + 76, 120, $hair);
        }
        if ($style === 2) {
            // Side part: the face sits slightly right, leaving a thicker fringe.
            imagefilledellipse($img, (int) $cx + 12, 178, 132, 152, $skin);
        } else {
            imagefilledellipse($img, (int) $cx, 178, 138, 152, $skin);
        }

        // Beard on every other master; a moustache on the rest.
        if ($variant % 2 === 0) {
            imagefilledellipse($img, (int) $cx, 206, 128, 104, $hair);
            imagefilledellipse($img, (int) $cx, 182, 100, 78, $skin);
            imagefilledrectangle($img, (int) $cx - 20, 196, (int) $cx + 20, 202, $hair);
        } else {
            imagefilledrectangle($img, (int) $cx - 24, 196, (int) $cx + 24, 203, $hair);
            imagefilledellipse($img, (int) $cx, 218, 26, 12, $skinShade);
        }

        // Eyes.
        imagefilledellipse($img, (int) $cx - 28, 172, 13, 15, $hair);
        imagefilledellipse($img, (int) $cx + 28, 172, 13, 15, $hair);

        // Framing ring, same as before.
        imagesetthickness($img, 4);
        imageellipse($img, (int) $cx, (int) $cx, $size - 26, $size - 26, $ring);

        return $img;
    }

    /** Wide tile: gradient, a drawn pair of scissors, and the service name. */
    private function serviceTile(string $name, int $hue, int $variant)
    {
        $w = 480;
        $h = 320;
        $img = imagecreatetruecolor($w, $h);
        $this->gradient($img, $w, $h, $hue);

        $ink = imagecolorallocatealpha($img, 255, 255, 255, 40);
        // Three marks so a menu is not a wall of identical scissors.
        $this->glyph($img, $ink, $variant % 3);

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

    /** 0 = scissors, 1 = straight razor, 2 = comb. */
    private function glyph($img, int $ink, int $kind): void
    {
        if ($kind === 0) {
            imagesetthickness($img, 7);
            imageline($img, 170, 84, 316, 236, $ink);
            imageline($img, 310, 84, 164, 236, $ink);
            imagesetthickness($img, 6);
            imageellipse($img, 160, 244, 40, 40, $ink);
            imageellipse($img, 320, 244, 40, 40, $ink);
            return;
        }

        if ($kind === 1) {
            // Blade folded out of its handle.
            imagesetthickness($img, 7);
            imageline($img, 150, 200, 262, 96, $ink);
            imageline($img, 262, 96, 292, 118, $ink);
            imageline($img, 292, 118, 178, 222, $ink);
            imageline($img, 178, 222, 150, 200, $ink);
            imagesetthickness($img, 9);
            imageline($img, 168, 236, 300, 236, $ink);
            return;
        }

        // Comb: a spine with teeth.
        imagesetthickness($img, 9);
        imageline($img, 152, 128, 328, 128, $ink);
        imagesetthickness($img, 6);
        for ($x = 160; $x <= 320; $x += 20) {
            imageline($img, $x, 132, $x, 214, $ink);
        }
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
