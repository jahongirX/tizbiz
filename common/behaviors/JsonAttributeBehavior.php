<?php

namespace common\behaviors;

use yii\base\Behavior;
use yii\db\ActiveRecord;

/**
 * Transparently maps JSON columns to PHP arrays. Some drivers (notably SQLite)
 * do not typecast an array bound to a JSON column and would raise
 * "Array to string conversion", and reads come back as raw JSON strings. This
 * behavior encodes arrays to JSON before persisting and decodes them back after
 * find/save, so model code always sees a plain array (or null).
 *
 * Usage:
 *   ['class' => JsonAttributeBehavior::class, 'attributes' => ['payload']]
 */
class JsonAttributeBehavior extends Behavior
{
    /** @var string[] attributes stored as JSON in the DB. */
    public array $attributes = [];

    public function events(): array
    {
        return [
            ActiveRecord::EVENT_AFTER_FIND => 'decode',
            ActiveRecord::EVENT_BEFORE_INSERT => 'encode',
            ActiveRecord::EVENT_BEFORE_UPDATE => 'encode',
            ActiveRecord::EVENT_AFTER_INSERT => 'decode',
            ActiveRecord::EVENT_AFTER_UPDATE => 'decode',
        ];
    }

    public function decode(): void
    {
        foreach ($this->attributes as $attribute) {
            $value = $this->owner->$attribute;
            if (is_string($value)) {
                $decoded = json_decode($value, true);
                $this->owner->$attribute = is_array($decoded) ? $decoded : null;
            }
        }
    }

    public function encode(): void
    {
        foreach ($this->attributes as $attribute) {
            $value = $this->owner->$attribute;
            if (is_array($value)) {
                $this->owner->$attribute = json_encode($value, JSON_UNESCAPED_UNICODE);
            }
        }
    }
}
