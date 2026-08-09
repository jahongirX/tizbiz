<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Gift certificate. Money in tiyin.
 *
 * @property int $id
 * @property int $business_id
 * @property string $code
 * @property string $name
 * @property int $value_tiyin
 * @property int $balance_tiyin
 * @property int|null $client_id
 * @property string $status
 * @property string|null $expires_at
 * @property int $created_at
 * @property int $updated_at
 */
class Certificate extends ActiveRecord
{
    public const STATUS_ACTIVE = 'active';
    public const STATUS_USED = 'used';
    public const STATUS_VOID = 'void';

    public static function tableName(): string
    {
        return '{{%certificates}}';
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
            [['code'], 'required'],
            [['code'], 'string', 'max' => 40],
            [['code'], 'unique', 'targetAttribute' => ['business_id', 'code'], 'message' => 'Bu kod allaqachon mavjud.'],
            [['name'], 'string', 'max' => 120],
            [['value_tiyin', 'balance_tiyin'], 'integer', 'min' => 0],
            [['client_id'], 'integer'],
            [['status'], 'in', 'range' => [self::STATUS_ACTIVE, self::STATUS_USED, self::STATUS_VOID]],
            [['status'], 'default', 'value' => self::STATUS_ACTIVE],
            [['expires_at'], 'date', 'format' => 'php:Y-m-d'],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'code' => 'Kod',
            'name' => 'Nomi',
            'value_tiyin' => 'Nominal',
            'balance_tiyin' => 'Qoldiq',
            'client_id' => 'Mijoz',
            'status' => 'Holat',
            'expires_at' => 'Amal muddati',
        ];
    }

    public function getClient(): ActiveQuery
    {
        return $this->hasOne(Client::class, ['id' => 'client_id']);
    }
}
