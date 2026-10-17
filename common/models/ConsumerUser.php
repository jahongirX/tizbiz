<?php

namespace common\models;

use common\components\Jwt;
use common\helpers\Phone;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;
use yii\db\ActiveRecord;
use yii\web\IdentityInterface;

/**
 * Bizcat consumer account (phone + OTP login). NOT tenant-scoped and separate
 * from {@see User}: consumer tokens carry typ=consumer and are only accepted by
 * the consumer user component ({@see \common\components\ConsumerAuth}).
 *
 * @property int $id
 * @property string $phone canonical +998XXXXXXXXX; "deleted-<id>" after deletion
 * @property string|null $name
 * @property string|null $birthday Y-m-d
 * @property string|null $gender male|female
 * @property string|null $city
 * @property string $locale uz|ru
 * @property int $status 10 active, 0 blocked/deleted
 * @property int|null $last_login_at
 * @property int|null $deleted_at
 * @property int $created_at
 * @property int $updated_at
 *
 * @property-read ConsumerFavorite[] $favorites
 */
class ConsumerUser extends ActiveRecord implements IdentityInterface
{
    public const STATUS_BLOCKED = 0;
    public const STATUS_ACTIVE = 10;

    public const GENDERS = ['male', 'female'];
    public const LOCALES = ['uz', 'ru'];

    public static function tableName(): string
    {
        return '{{%consumer_users}}';
    }

    public function behaviors(): array
    {
        return [TimestampBehavior::class];
    }

    public function rules(): array
    {
        return [
            [['phone'], 'required'],
            [['phone'], 'string', 'max' => 32],
            [['phone'], 'unique'],
            [['name'], 'string', 'max' => 128],
            [['birthday'], 'date', 'format' => 'php:Y-m-d', 'message' => 'Sana YYYY-MM-DD formatida bo\'lishi kerak.'],
            [['gender'], 'in', 'range' => self::GENDERS, 'message' => 'Jins male yoki female bo\'lishi kerak.'],
            [['city'], 'string', 'max' => 64],
            [['locale'], 'in', 'range' => self::LOCALES, 'message' => 'Til uz yoki ru bo\'lishi kerak.'],
            [['locale'], 'default', 'value' => 'uz'],
            [['status'], 'in', 'range' => [self::STATUS_BLOCKED, self::STATUS_ACTIVE]],
            [['status'], 'default', 'value' => self::STATUS_ACTIVE],
            [['!last_login_at', '!deleted_at'], 'integer'],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'phone' => 'Telefon',
            'name' => 'Ism',
            'birthday' => 'Tug\'ilgan kun',
            'gender' => 'Jins',
            'city' => 'Shahar',
            'locale' => 'Til',
            'status' => 'Holat',
        ];
    }

    public function beforeValidate(): bool
    {
        if (!parent::beforeValidate()) {
            return false;
        }
        $phone = (string) $this->phone;
        if (strncmp($phone, 'deleted-', 8) !== 0) {
            $normalized = Phone::normalize($phone);
            if ($normalized !== null) {
                $this->phone = $normalized;
            }
        }
        return true;
    }

    public function fields(): array
    {
        return [
            'id' => fn () => (int) $this->id,
            'phone',
            'name',
            'birthday',
            'gender',
            'city',
            'locale',
            'created_at' => fn () => (int) $this->created_at,
        ];
    }

    public function isUsable(): bool
    {
        return (int) $this->status === self::STATUS_ACTIVE && $this->deleted_at === null;
    }

    public function getFavorites(): ActiveQuery
    {
        return $this->hasMany(ConsumerFavorite::class, ['consumer_id' => 'id']);
    }

    // --- IdentityInterface ---

    public static function findIdentity($id): ?self
    {
        return static::find()
            ->where(['id' => (int) $id, 'status' => self::STATUS_ACTIVE])
            ->andWhere(['deleted_at' => null])
            ->one();
    }

    /** Accepts only typ=consumer tokens of an active, non-deleted account. */
    public static function findIdentityByAccessToken($token, $type = null): ?self
    {
        $payload = Jwt::parse((string) $token);
        if ($payload === null || empty($payload['sub'])) {
            return null;
        }
        if (Jwt::typ($payload) !== Jwt::TYP_CONSUMER) {
            return null;
        }
        return static::findIdentity((int) $payload['sub']);
    }

    public function getId(): int
    {
        return (int) $this->id;
    }

    public function getAuthKey(): ?string
    {
        return null;
    }

    public function validateAuthKey($authKey): bool
    {
        return false;
    }
}
