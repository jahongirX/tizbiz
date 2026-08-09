<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Service provider inside a business (usta/shifokor/registratura). May or may
 * not have a login account (user_id). Tenant-scoped by business_id.
 *
 * @property int $id
 * @property int $business_id
 * @property int|null $user_id
 * @property string $name
 * @property string|null $specialization
 * @property bool $is_active
 * @property int $created_at
 * @property int $updated_at
 */
class Staff extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%staff}}';
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
            [['name'], 'required'],
            [['name'], 'string', 'max' => 128],
            [['specialization'], 'string', 'max' => 96],
            [['business_id', 'user_id'], 'integer'],
            [['commission_percent'], 'integer', 'min' => 0, 'max' => 100],
            [['commission_percent'], 'default', 'value' => 0],
            [['is_active'], 'boolean'],
            [['is_active'], 'default', 'value' => true],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'name' => 'Ism',
            'specialization' => 'Mutaxassislik',
            'commission_percent' => 'Komissiya (%)',
            'is_active' => 'Faol',
            'created_at' => 'Yaratilgan sana',
            'updated_at' => 'Yangilangan sana',
        ];
    }

    public function getBusiness(): ActiveQuery
    {
        return $this->hasOne(Business::class, ['id' => 'business_id']);
    }

    public function getWorkingHours(): ActiveQuery
    {
        return $this->hasMany(WorkingHours::class, ['staff_id' => 'id']);
    }

    public function getTimeOff(): ActiveQuery
    {
        return $this->hasMany(TimeOff::class, ['staff_id' => 'id']);
    }
}
