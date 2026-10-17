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
     * Strict: accepts exactly 9 local digits, or 12 digits starting with 998
     * (spaces, dashes, brackets and a leading "+" are ignored). Anything else —
     * foreign numbers, extra or missing digits — returns null, so callers that
     * fall back to the raw input (`normalize($x) ?? $x`) can never turn a foreign
     * number into a real UZ one.
     *
     * @return string|null canonical "+998XXXXXXXXX", or null when the input is
     *                     not a UZ number.
     */
    public static function normalize(?string $phone): ?string
    {
        if ($phone === null) {
            return null;
        }
        $digits = preg_replace('/\D+/', '', $phone) ?? '';
        $len = strlen($digits);
        if ($len === 9 || ($len === 12 && strncmp($digits, '998', 3) === 0)) {
            return '+998' . substr($digits, -9);
        }
        return null;
    }
}
