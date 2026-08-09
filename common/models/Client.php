<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * CRM contact, scoped to a business. Unique per (business, phone).
 *
 * @property int $id
 * @property int $business_id
 * @property string $name
 * @property string $phone
 * @property string|null $birthday
 * @property string|null $notes
 * @property array $tags
 * @property int $created_at
 * @property int $updated_at
 *
 * @property-read Appointment[] $appointments
 */
class Client extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%clients}}';
    }

    public static function isTenantScoped(): bool
    {
        return true;
    }

    public function behaviors(): array
    {
        return [
            TimestampBehavior::class,
        ];
    }

    public function rules(): array
    {
        return [
            [['name', 'phone'], 'required'],
            [['name'], 'string', 'max' => 128],
            [['phone'], 'string', 'max' => 32],
            [['phone'], 'unique', 'targetAttribute' => ['business_id', 'phone'], 'message' => 'Bu telefon raqam ushbu biznesda allaqachon mavjud.'],
            [['email'], 'email'],
            [['email'], 'string', 'max' => 128],
            [['birthday'], 'date', 'format' => 'php:Y-m-d'],
            [['notes'], 'string'],
            [['tags'], 'safe'],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'name' => 'Ism',
            'phone' => 'Telefon',
            'email' => 'Email',
            'birthday' => 'Tug\'ilgan kun',
            'notes' => 'Izohlar',
            'tags' => 'Teglar',
        ];
    }

    public function beforeValidate(): bool
    {
        if (!parent::beforeValidate()) {
            return false;
        }
        $normalized = \common\helpers\Phone::normalize((string) $this->phone);
        if ($normalized !== null) {
            $this->phone = $normalized;
        }
        return true;
    }

    /**
     * The `tags` column is JSON. Some drivers return it as a raw JSON string,
     * so normalize to a PHP array after loading.
     */
    public function afterFind(): void
    {
        parent::afterFind();
        if (is_string($this->tags)) {
            $decoded = json_decode($this->tags, true);
            $this->tags = is_array($decoded) ? $decoded : [];
        } elseif ($this->tags === null) {
            $this->tags = [];
        }
    }

    /**
     * Encode `tags` back to JSON before persisting so the column always holds
     * a valid JSON array regardless of driver behavior.
     */
    public function beforeSave($insert): bool
    {
        if (!parent::beforeSave($insert)) {
            return false;
        }
        $tags = $this->tags;
        if ($tags === null || $tags === '') {
            $tags = [];
        }
        if (is_array($tags)) {
            $this->tags = json_encode(array_values($tags), JSON_UNESCAPED_UNICODE);
        }
        return true;
    }

    /**
     * Keep the in-memory value as an array after a save (beforeSave stringified it).
     */
    public function afterSave($insert, $changedAttributes): void
    {
        parent::afterSave($insert, $changedAttributes);
        if (is_string($this->tags)) {
            $decoded = json_decode($this->tags, true);
            $this->tags = is_array($decoded) ? $decoded : [];
        }
    }

    public function getAppointments(): ActiveQuery
    {
        return $this->hasMany(Appointment::class, ['client_id' => 'id']);
    }

    public function getCategoryAssignments(): ActiveQuery
    {
        return $this->hasMany(ClientCategoryAssignment::class, ['client_id' => 'id']);
    }

    public function getCategories(): ActiveQuery
    {
        return $this->hasMany(ClientCategory::class, ['id' => 'category_id'])
            ->via('categoryAssignments');
    }
}
