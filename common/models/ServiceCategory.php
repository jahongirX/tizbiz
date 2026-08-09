<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\db\ActiveQuery;

/**
 * Optional grouping of services within a business. Tenant-scoped, no timestamps.
 *
 * @property int $id
 * @property int $business_id
 * @property string $name
 * @property int $sort
 */
class ServiceCategory extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%service_categories}}';
    }

    public static function isTenantScoped(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            [['name'], 'required'],
            [['name'], 'string', 'max' => 96],
            [['business_id', 'sort'], 'integer'],
            [['sort'], 'default', 'value' => 0],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'name' => 'Nomi',
            'sort' => 'Tartib',
        ];
    }

    public function getServices(): ActiveQuery
    {
        return $this->hasMany(Service::class, ['category_id' => 'id']);
    }
}
