<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Membership of a user in a business carrying the per-tenant role.
 * Not tenant-scoped (auth/switch must read memberships across tenants).
 *
 * @property int $id
 * @property int $business_id
 * @property int $user_id
 * @property string $role
 * @property int $created_at
 *
 * @property-read User $user
 * @property-read Business $business
 */
class BusinessUser extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%business_user}}';
    }

    public function behaviors(): array
    {
        return [
            [
                'class' => TimestampBehavior::class,
                'updatedAtAttribute' => false,
            ],
        ];
    }

    public function rules(): array
    {
        return [
            [['business_id', 'user_id', 'role'], 'required'],
            [['business_id', 'user_id'], 'integer'],
            [['role'], 'in', 'range' => [Business::ROLE_OWNER, Business::ROLE_ADMIN, Business::ROLE_STAFF]],
            [['role'], 'string', 'max' => 32],
            [['business_id'], 'unique', 'targetAttribute' => ['business_id', 'user_id'], 'message' => 'This user is already a member of this business.'],
        ];
    }

    public function getUser(): ActiveQuery
    {
        return $this->hasOne(User::class, ['id' => 'user_id']);
    }

    public function getBusiness(): ActiveQuery
    {
        return $this->hasOne(Business::class, ['id' => 'business_id']);
    }
}
