<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Business — the tenant itself. Not tenant-scoped (it defines the tenant).
 *
 * @property int $id
 * @property string $name
 * @property string $slug
 * @property string|null $phone
 * @property string|null $category
 * @property string $tariff
 * @property string $timezone
 * @property int $status
 * @property array|null $features
 * @property int|null $staff_count
 * @property int|null $branches_count
 * @property string|null $telegram_bot_token
 * @property string|null $telegram_bot_username
 * @property string|null $logo
 * @property string|null $cover
 * @property string|null $brand_color
 * @property string|null $brand_color_2
 * @property string|null $tagline
 * @property int $created_at
 * @property int $updated_at
 *
 * @property-read BusinessUser[] $businessUsers
 * @property-read Staff[] $staff
 * @property-read Service[] $services
 */
class Business extends ActiveRecord
{
    public const STATUS_INACTIVE = 0;
    public const STATUS_ACTIVE = 10;

    public const ROLE_OWNER = 'business_owner';
    public const ROLE_ADMIN = 'business_admin';
    public const ROLE_STAFF = 'staff';

    public const TARIFFS = ['free', 'start', 'standard', 'clinic'];

    public static function tableName(): string
    {
        return '{{%businesses}}';
    }

    public function behaviors(): array
    {
        return [
            TimestampBehavior::class,
            // features is a JSON column (per-business feature flags, stage 7).
            [
                'class' => \common\behaviors\JsonAttributeBehavior::class,
                'attributes' => ['features'],
            ],
        ];
    }

    public function rules(): array
    {
        return [
            [['name', 'slug'], 'required'],
            [['name'], 'string', 'max' => 160],
            [['slug'], 'string', 'max' => 80],
            [['slug'], 'match', 'pattern' => '/^[a-z0-9-]+$/', 'message' => 'Slug may only contain lowercase letters, digits and hyphens.'],
            [['slug'], 'unique'],
            [['phone'], 'string', 'max' => 32],
            [['category'], 'string', 'max' => 48],
            [['tariff'], 'in', 'range' => self::TARIFFS],
            [['tariff'], 'default', 'value' => 'free'],
            [['timezone'], 'string', 'max' => 48],
            [['timezone'], 'default', 'value' => 'Asia/Tashkent'],
            [['status'], 'in', 'range' => [self::STATUS_INACTIVE, self::STATUS_ACTIVE]],
            [['status'], 'default', 'value' => self::STATUS_ACTIVE],
            [['online_booking_enabled'], 'boolean'],
            [['online_booking_enabled'], 'default', 'value' => true],
            [['booking_lead_min', 'booking_horizon_days'], 'integer', 'min' => 0],
            [['booking_lead_min'], 'default', 'value' => 0],
            [['booking_horizon_days'], 'default', 'value' => 30],
            [['engine'], 'string', 'max' => 24],
            [['engine'], 'default', 'value' => \common\engines\EngineFactory::DEFAULT_KEY],
            [['engine'], 'in', 'range' => \common\engines\EngineFactory::keys(), 'message' => 'Noma\'lum yo\'nalish.'],
            [['staff_count', 'branches_count'], 'integer', 'min' => 0, 'max' => 100000],
            [['telegram_bot_token'], 'string', 'max' => 80],
            [['telegram_bot_username'], 'string', 'max' => 64],
            [['telegram_bot_token'], 'match', 'pattern' => '/^\d{6,}:[A-Za-z0-9_-]{20,}$/', 'message' => 'Bot token formati noto\'g\'ri.', 'skipOnEmpty' => true],
            [['tagline'], 'string', 'max' => 160],
            [['logo', 'cover'], 'string', 'max' => 500],
            [['brand_color', 'brand_color_2'], 'string', 'max' => 9],
            [['brand_color', 'brand_color_2'], 'match', 'pattern' => '/^#[0-9a-fA-F]{6}$/', 'message' => 'Rang #RRGGBB formatida bo\'lishi kerak.', 'skipOnEmpty' => true],
            [['features'], 'safe'],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'name' => 'Nomi',
            'slug' => 'Manzil (slug)',
            'phone' => 'Telefon',
            'category' => 'Kategoriya',
            'tariff' => 'Tarif',
            'timezone' => 'Vaqt mintaqasi',
            'status' => 'Holat',
            'online_booking_enabled' => 'Onlayn yozuv yoqilgan',
            'booking_lead_min' => 'Minimal oldindan (daq)',
            'booking_horizon_days' => 'Necha kun oldin (maks)',
            'engine' => 'Dvigatel (yo\'nalish)',
            'staff_count' => 'Xodimlar soni',
            'branches_count' => 'Filiallar soni',
            'telegram_bot_token' => 'Telegram bot token',
            'telegram_bot_username' => 'Telegram bot foydalanuvchi nomi',
            'logo' => 'Logotip',
            'cover' => 'Fon rasmi',
            'brand_color' => 'Asosiy rang',
            'brand_color_2' => 'Qo\'shimcha rang',
            'tagline' => 'Sarlavha ostidagi matn',
            'created_at' => 'Yaratilgan sana',
            'updated_at' => 'Yangilangan sana',
        ];
    }

    public function getBusinessUsers(): ActiveQuery
    {
        return $this->hasMany(BusinessUser::class, ['business_id' => 'id']);
    }

    public function getStaff(): ActiveQuery
    {
        return $this->hasMany(Staff::class, ['business_id' => 'id']);
    }

    public function getServices(): ActiveQuery
    {
        return $this->hasMany(Service::class, ['business_id' => 'id']);
    }

    /** Resolve this business's pluggable engine (vertical). */
    public function engine(): \common\engines\EngineInterface
    {
        return \common\engines\EngineFactory::make($this);
    }

    /**
     * Per-business feature flag (stage 7). Returns $default when the flag is
     * unset, so a business created before the flag existed keeps its original
     * behaviour and new behaviour stays reversible (flag off -> old flow).
     */
    public function hasFeature(string $key, bool $default = false): bool
    {
        $features = is_array($this->features) ? $this->features : [];
        return array_key_exists($key, $features) ? (bool) $features[$key] : $default;
    }
}
