<?php

namespace common\engines;

use common\models\Business;
use yii\base\InvalidArgumentException;

/**
 * Maps a business's `engine` key to its engine class (strategy pattern). Adding
 * a new vertical = one line here + a new class implementing EngineInterface. No
 * per-business code, no touching other engines.
 */
class EngineFactory
{
    private const MAP = [
        'slot' => SlotEngine::class,       // barber / go'zallik saloni
        'medical' => MedicalEngine::class, // klinika / UZI / stomatologiya
        'catalog' => CatalogEngine::class, // kafe / restoran / tort (Phase 2 flow)
        'rental' => RentalEngine::class,   // kelin ko'ylak / kostyum ijarasi (Phase 3 flow)
    ];

    public const DEFAULT_KEY = 'slot';

    public static function make(Business $business): EngineInterface
    {
        $key = $business->engine ?: self::DEFAULT_KEY; // legacy/null -> current behaviour
        $class = self::MAP[$key] ?? null;
        if ($class === null) {
            throw new InvalidArgumentException("Noma'lum engine: {$key}");
        }
        return new $class();
    }

    /** @return string[] registered engine keys */
    public static function keys(): array
    {
        return array_keys(self::MAP);
    }
}
