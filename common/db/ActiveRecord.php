<?php

namespace common\db;

use Yii;
use yii\db\ActiveRecord as BaseActiveRecord;

/**
 * Base Active Record with automatic multi-tenant isolation.
 *
 * Models that own a `business_id` column override {@see isTenantScoped()} to
 * return true. When a tenant is active (a business JWT is present), all queries
 * are filtered by it and new rows get `business_id` set automatically. Without
 * an active tenant (webhooks, superadmin, console) no scoping is applied.
 */
class ActiveRecord extends BaseActiveRecord
{
    /** Override in tenant-owned models that have a direct `business_id`. */
    public static function isTenantScoped(): bool
    {
        return false;
    }

    private static function activeTenantId(): ?int
    {
        if (!Yii::$app->has('tenant')) {
            return null;
        }
        return Yii::$app->tenant->getId();
    }

    public static function find()
    {
        $query = parent::find();
        if (static::isTenantScoped()) {
            $tenantId = self::activeTenantId();
            if ($tenantId !== null) {
                $query->andWhere([static::tableName() . '.business_id' => $tenantId]);
            }
        }
        return $query;
    }

    public function beforeSave($insert)
    {
        if (!parent::beforeSave($insert)) {
            return false;
        }
        if ($insert && static::isTenantScoped() && $this->hasAttribute('business_id') && empty($this->getAttribute('business_id'))) {
            $tenantId = self::activeTenantId();
            if ($tenantId !== null) {
                $this->setAttribute('business_id', $tenantId);
            }
        }
        return true;
    }
}
