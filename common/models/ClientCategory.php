<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * A client label/category (VIP, Loyal, Doimiy…), managed per business.
 *
 * @property int $id
 * @property int $business_id
 * @property string $name
 * @property string $color
 * @property int $sort
 * @property int $created_at
 * @property int $updated_at
 */
class ClientCategory extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%client_categories}}';
    }

    public static function isTenantScoped(): bool
    {
        return true;
    }

    public function behaviors(): array
    {
        return [TimestampBehavior::class];
    }

    public function rules(): array
    {
        return [
            [['name'], 'required'],
            [['name'], 'string', 'max' => 64],
            [['color'], 'string', 'max' => 16],
            [['color'], 'match', 'pattern' => '/^#[0-9a-fA-F]{3,8}$/', 'message' => 'Rang HEX formatida bo\'lishi kerak.'],
            [['color'], 'default', 'value' => '#6b7280'],
            [['sort'], 'integer'],
            [['sort'], 'default', 'value' => 0],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'name' => 'Nomi',
            'color' => 'Rang',
            'sort' => 'Tartib',
        ];
    }

    public function getAssignments(): ActiveQuery
    {
        return $this->hasMany(ClientCategoryAssignment::class, ['category_id' => 'id']);
    }

    public function getClients(): ActiveQuery
    {
        return $this->hasMany(Client::class, ['id' => 'client_id'])
            ->via('assignments');
    }
}
