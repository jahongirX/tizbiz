<?php

namespace common\helpers;

/**
 * Phone number normalization for Uzbekistan. Users type numbers many ways
 * (+998 90 123 45 67, 998901234567, 901234567, with spaces/dashes); we store
 * and compare them in one canonical E.164 form: +998 followed by the 9-digit
 * subscriber number. This keeps login lookups and unique checks consistent.
 */
class Phone
{
    /**
     * @return string|null canonical "+998XXXXXXXXX", or null when there aren't
     *                     enough digits to form a valid UZ number.
     */
    public static function normalize(?string $phone): ?string
    {
        if ($phone === null) {
            return null;
        }
        $digits = preg_replace('/\D+/', '', $phone) ?? '';
        if (strlen($digits) < 9) {
            return null;
        }
        // Take the last 9 digits as the local subscriber number.
        return '+998' . substr($digits, -9);
    }
}
