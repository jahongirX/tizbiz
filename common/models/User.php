<?php

namespace common\models;

use common\components\Jwt;
use Yii;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveRecord;
use yii\web\IdentityInterface;

/**
 * User (platform account). One user may belong to several businesses through
 * {@see BusinessUser} with a per-tenant role. Authentication is stateless (JWT).
 *
 * @property int $id
 * @property string $phone
 * @property string $name
 * @property string $password_hash
 * @property int $status
 * @property int $created_at
 * @property int $updated_at
 */
class User extends ActiveRecord implements IdentityInterface
{
    public const STATUS_INACTIVE = 0;
    public const STATUS_ACTIVE = 10;

    /** Active tenant id resolved from the JWT for the current request. */
    public ?int $activeTenantId = null;

    /** Role held in the active tenant, resolved from the JWT. */
    public ?string $activeRole = null;

    public static function tableName(): string
    {
        return '{{%users}}';
    }

    public function behaviors(): array
    {
        return [
            TimestampBehavior::class,
        ];
    }

    public function beforeValidate(): bool
    {
        if (!parent::beforeValidate()) {
            return false;
        }
        $normalized = \common\helpers\Phone::normalize((string) $this->phone);
        if ($normalized !== null) {
            $this->phone = $normalized;
        }
        return true;
    }

    /** Never expose the password hash in API responses. */
    public function fields(): array
    {
        $fields = parent::fields();
        unset($fields['password_hash']);
        return $fields;
    }

    public function rules(): array
    {
        return [
            [['phone', 'name'], 'required'],
            [['phone'], 'string', 'max' => 32],
            [['phone'], 'unique'],
            [['name'], 'string', 'max' => 128],
            [['status'], 'in', 'range' => [self::STATUS_INACTIVE, self::STATUS_ACTIVE]],
            [['status'], 'default', 'value' => self::STATUS_ACTIVE],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'phone' => 'Telefon',
            'name' => 'Ism',
            'password_hash' => 'Parol',
            'status' => 'Holat',
            'created_at' => 'Yaratilgan sana',
            'updated_at' => 'Yangilangan sana',
        ];
    }

    // --- IdentityInterface ---

    public static function findIdentity($id): ?self
    {
        return static::findOne(['id' => $id, 'status' => self::STATUS_ACTIVE]);
    }

    /**
     * @param string $token the raw JWT
     */
    public static function findIdentityByAccessToken($token, $type = null): ?self
    {
        $payload = Jwt::parse((string) $token);
        if ($payload === null || empty($payload['sub'])) {
            return null;
        }
        $user = static::findIdentity((int) $payload['sub']);
        if ($user !== null) {
            $user->activeTenantId = isset($payload['tid']) && $payload['tid'] !== null ? (int) $payload['tid'] : null;
            $user->activeRole = isset($payload['role']) && $payload['role'] !== null ? (string) $payload['role'] : null;
        }
        return $user;
    }

    public function getId(): int
    {
        return (int) $this->id;
    }

    public function getAuthKey(): ?string
    {
        return null; // sessions disabled; JWT is self-contained
    }

    public function validateAuthKey($authKey): bool
    {
        return false;
    }

    // --- Password helpers ---

    public function setPassword(string $password): void
    {
        $this->password_hash = Yii::$app->security->generatePasswordHash($password);
    }

    public function validatePassword(string $password): bool
    {
        if (!Yii::$app->security->validatePassword($password, $this->password_hash)) {
            return false;
        }
        // Self-heal: if the stored hash uses a heavier cost than configured
        // (e.g. an old cost-13 hash that verifies slowly), transparently re-hash
        // it to the current cost on a successful login.
        $cost = (int) Yii::$app->security->passwordHashCost;
        if (is_string($this->password_hash)
            && password_needs_rehash($this->password_hash, PASSWORD_BCRYPT, ['cost' => $cost])) {
            $this->setPassword($password);
            $this->save(false, ['password_hash']);
        }
        return true;
    }
}
