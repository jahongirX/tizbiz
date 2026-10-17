<?php

namespace common\models;

use common\db\ActiveRecord;
use Yii;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Service provider inside a business (usta/shifokor/registratura). May or may
 * not have a login account (user_id). Tenant-scoped by business_id.
 *
 * @property int $id
 * @property int $business_id
 * @property int|null $user_id login account; must be a business_user of business_id, unique per business
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
            [['user_id'], 'validateUserLink', 'skipOnEmpty' => true],
        ];
    }

    /**
     * A linked login (user_id) must be a member of this staff row's business,
     * and may be linked to at most one staff row of that business. A row that is
     * already linked to one account is never re-pointed to another (unlink first).
     */
    public function validateUserLink(string $attribute): void
    {
        if ($this->hasErrors($attribute)) {
            return;
        }
        $userId = (int) $this->$attribute;
        $old = $this->getOldAttribute($attribute);
        if (!$this->isNewRecord && $old !== null && $old !== '' && (int) $old !== $userId) {
            $this->addError($attribute, 'Bu xodim boshqa hisobga bog\'langan.');
            return;
        }
        $businessId = (int) ($this->business_id ?: (Yii::$app->has('tenant') ? Yii::$app->tenant->getId() : 0));
        if ($userId <= 0 || $businessId <= 0) {
            $this->addError($attribute, 'Bu foydalanuvchi ushbu biznes a\'zosi emas.');
            return;
        }

        $isMember = BusinessUser::find()
            ->where(['business_id' => $businessId, 'user_id' => $userId])
            ->exists();
        if (!$isMember) {
            $this->addError($attribute, 'Bu foydalanuvchi ushbu biznes a\'zosi emas.');
            return;
        }

        $taken = static::find()
            ->andWhere([static::tableName() . '.business_id' => $businessId, static::tableName() . '.user_id' => $userId])
            ->andFilterWhere(['<>', static::tableName() . '.id', $this->id])
            ->exists();
        if ($taken) {
            $this->addError($attribute, 'Bu foydalanuvchi boshqa xodimga bog\'langan.');
        }
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
