<?php

namespace common\helpers;

/**
 * Directory category catalog shown in Bizcat (key = businesses.category).
 * Order matters: it is the order of the category chips in the app.
 */
final class Categories
{
    private const ALL = [
        ['key' => 'barber', 'label' => "Barber / Go'zallik saloni", 'label_ru' => 'Барбершоп / Салон красоты', 'engine' => 'slot', 'icon' => 'scissors'],
        ['key' => 'cafe', 'label' => 'Kafe / Tortlar', 'label_ru' => 'Кафе / Торты', 'engine' => 'catalog', 'icon' => 'cake'],
        ['key' => 'restaurant', 'label' => 'Restoran', 'label_ru' => 'Ресторан', 'engine' => 'catalog', 'icon' => 'utensils'],
        ['key' => 'clinic', 'label' => 'Klinika / Tibbiyot', 'label_ru' => 'Клиника / Медицина', 'engine' => 'medical', 'icon' => 'stethoscope'],
        ['key' => 'rental', 'label' => "To'yxona / Ijara", 'label_ru' => 'Тойхона / Прокат', 'engine' => 'rental', 'icon' => 'rings'],
    ];

    /** @return array<int, array{key:string,label:string,label_ru:string,engine:string,icon:string}> */
    public static function all(): array
    {
        return self::ALL;
    }

    /** @return string[] */
    public static function keys(): array
    {
        return array_column(self::ALL, 'key');
    }

    /** The booking engine of a category ('slot' when unknown). */
    public static function engine(?string $key): string
    {
        foreach (self::ALL as $c) {
            if ($c['key'] === $key) {
                return $c['engine'];
            }
        }
        return 'slot';
    }

    public static function label(?string $key): ?string
    {
        if ($key === null || $key === '') {
            return null;
        }
        foreach (self::ALL as $c) {
            if ($c['key'] === $key) {
                return $c['label'];
            }
        }
        return null;
    }
}
