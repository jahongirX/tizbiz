<?php

namespace common\models;

use common\db\ActiveRecord;
use Yii;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;
use yii\db\Query;

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
    /** Seconds a resolved membership role stays cached (see {@see activeRole()}). */
    public const ROLE_CACHE_TTL = 60;

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

    public function afterSave($insert, $changedAttributes)
    {
        parent::afterSave($insert, $changedAttributes);
        self::forgetRole((int) $this->business_id, (int) $this->user_id);
        // A membership moved to another business/user: bust the old key too.
        $oldBusiness = $changedAttributes['business_id'] ?? null;
        $oldUser = $changedAttributes['user_id'] ?? null;
        if (!$insert && ($oldBusiness !== null || $oldUser !== null)) {
            self::forgetRole((int) ($oldBusiness ?? $this->business_id), (int) ($oldUser ?? $this->user_id));
        }
    }

    public function afterDelete()
    {
        parent::afterDelete();
        self::forgetRole((int) $this->business_id, (int) $this->user_id);
    }

    /**
     * Role of $userId in $businessId if the membership exists AND the business
     * is active (status = 10), else null. Cached ROLE_CACHE_TTL seconds under
     * "bu-role:{businessId}:{userId}" ('' is stored for "no membership").
     */
    public static function activeRole(int $userId, int $businessId): ?string
    {
        $cache = Yii::$app->has('cache') ? Yii::$app->cache : null;
        $key = self::roleCacheKey($businessId, $userId);
        if ($cache !== null) {
            $cached = $cache->get($key);
            if (is_string($cached)) {
                return $cached === '' ? null : $cached;
            }
        }

        $role = (new Query())
            ->select(['bu.role'])
            ->from(['bu' => self::tableName()])
            ->innerJoin(['b' => Business::tableName()], 'b.id = bu.business_id')
            ->where([
                'bu.business_id' => $businessId,
                'bu.user_id' => $userId,
                'b.status' => Business::STATUS_ACTIVE,
            ])
            ->scalar();
        $role = is_string($role) && $role !== '' ? $role : null;

        if ($cache !== null) {
            $cache->set($key, $role ?? '', self::ROLE_CACHE_TTL);
        }
        return $role;
    }

    /** Drop the cached role of $userId in $businessId (membership changed). */
    public static function forgetRole(int $businessId, int $userId): void
    {
        if (Yii::$app->has('cache')) {
            Yii::$app->cache->delete(self::roleCacheKey($businessId, $userId));
        }
    }

    private static function roleCacheKey(int $businessId, int $userId): string
    {
        return "bu-role:{$businessId}:{$userId}";
    }
}
