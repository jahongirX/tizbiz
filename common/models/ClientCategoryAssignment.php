<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Pivot: client <-> client_category. Scoped implicitly through its client and
 * category (both tenant-owned); not directly tenant-scoped.
 *
 * @property int $id
 * @property int $client_id
 * @property int $category_id
 * @property int $created_at
 */
class ClientCategoryAssignment extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%client_category_assignment}}';
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
            [['client_id', 'category_id'], 'required'],
            [['client_id', 'category_id'], 'integer'],
            [['client_id'], 'unique', 'targetAttribute' => ['client_id', 'category_id'], 'message' => 'Mijoz bu kategoriyada allaqachon mavjud.'],
        ];
    }

    public function getClient(): ActiveQuery
    {
        return $this->hasOne(Client::class, ['id' => 'client_id']);
    }

    public function getCategory(): ActiveQuery
    {
        return $this->hasOne(ClientCategory::class, ['id' => 'category_id']);
    }
}
