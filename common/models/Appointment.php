<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;

/**
 * Booking. Times stored as UTC DATETIME ('Y-m-d H:i:s'), shown in the business
 * timezone. Money in tiyin. Tenant-scoped by business_id.
 *
 * @property int $id
 * @property int $business_id
 * @property int|null $client_id
 * @property int|null $consumer_id Bizcat consumer who booked (or was back-linked by phone)
 * @property int|null $guests
 * @property string|null $notes
 * @property int $staff_id
 * @property int $service_id
 * @property string $starts_at
 * @property string $ends_at
 * @property string $status
 * @property string $source
 * @property int|null $deposit_tiyin
 * @property bool $paid
 * @property int $created_at
 * @property int $updated_at
 */
class Appointment extends ActiveRecord
{
    public const STATUS_PENDING = 'pending';
    public const STATUS_CONFIRMED = 'confirmed';
    public const STATUS_ARRIVED = 'arrived';
    public const STATUS_COMPLETED = 'completed';
    public const STATUS_NO_SHOW = 'no_show';
    public const STATUS_CANCELED = 'canceled';

    public const SOURCE_ADMIN = 'admin';
    public const SOURCE_LINK = 'link';
    public const SOURCE_TELEGRAM = 'telegram';
    public const SOURCE_APP = 'app';

    public const SOURCES = [self::SOURCE_ADMIN, self::SOURCE_LINK, self::SOURCE_TELEGRAM, self::SOURCE_APP];

    /** All valid statuses. */
    public const STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_CONFIRMED,
        self::STATUS_ARRIVED,
        self::STATUS_COMPLETED,
        self::STATUS_NO_SHOW,
        self::STATUS_CANCELED,
    ];

    /** Statuses that free up the slot (do not block overlapping bookings). */
    public const RELEASED_STATUSES = [
        self::STATUS_CANCELED,
        self::STATUS_NO_SHOW,
    ];

    public static function tableName(): string
    {
        return '{{%appointments}}';
    }

    public static function isTenantScoped(): bool
    {
        return true;
    }

    public function behaviors(): array
    {
        return [
            TimestampBehavior::class,
        ];
    }

    public function rules(): array
    {
        return [
            [['staff_id', 'service_id', 'starts_at', 'ends_at'], 'required'],
            [['business_id', 'client_id', 'consumer_id', 'staff_id', 'service_id', 'deposit_tiyin', 'guests'], 'integer'],
            [['guests'], 'integer', 'min' => 1],
            [['starts_at', 'ends_at'], 'string'],
            [['status'], 'in', 'range' => self::STATUSES],
            [['status'], 'default', 'value' => self::STATUS_PENDING],
            [['source'], 'in', 'range' => self::SOURCES],
            [['source'], 'default', 'value' => self::SOURCE_ADMIN],
            [['deposit_tiyin'], 'integer', 'min' => 0],
            [['paid'], 'boolean'],
            [['paid'], 'default', 'value' => false],
            [['notes'], 'string'],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'client_id' => 'Mijoz',
            'staff_id' => 'Xodim',
            'service_id' => 'Xizmat',
            'guests' => 'Mehmonlar soni',
            'starts_at' => 'Boshlanish vaqti',
            'ends_at' => 'Tugash vaqti',
            'status' => 'Holat',
            'source' => 'Manba',
            'deposit_tiyin' => 'Oldindan to\'lov',
            'paid' => 'To\'langan',
            'notes' => 'Izoh',
            'created_at' => 'Yaratilgan sana',
            'updated_at' => 'Yangilangan sana',
        ];
    }

    /**
     * Re-read one appointment with SELECT ... FOR UPDATE (call inside a
     * transaction). Returns the latest committed row, locked until commit, so a
     * read-check-write status change cannot overwrite a concurrent one.
     */
    public static function lockForUpdate(int $id): ?self
    {
        return static::findBySql('SELECT * FROM ' . static::tableName() . ' WHERE id = :id FOR UPDATE', [':id' => $id])->one();
    }

    /**
     * When a booking is released (canceled / no_show), deposit transactions that
     * no PSP holds yet (status created) are canceled, so Payme/Click reject them.
     */
    public function afterSave($insert, $changedAttributes)
    {
        parent::afterSave($insert, $changedAttributes);
        if (!$insert && array_key_exists('status', $changedAttributes)
            && in_array((string) $this->status, self::RELEASED_STATUSES, true)) {
            Transaction::updateAll(
                ['status' => Transaction::STATUS_CANCELED, 'updated_at' => time()],
                ['appointment_id' => (int) $this->id, 'type' => Transaction::TYPE_DEPOSIT, 'status' => Transaction::STATUS_CREATED]
            );
        }
    }

    public function getStaff(): ActiveQuery
    {
        return $this->hasOne(Staff::class, ['id' => 'staff_id']);
    }

    public function getService(): ActiveQuery
    {
        return $this->hasOne(Service::class, ['id' => 'service_id']);
    }

    public function getClient(): ActiveQuery
    {
        return $this->hasOne(Client::class, ['id' => 'client_id']);
    }

    public function getConsumer(): ActiveQuery
    {
        return $this->hasOne(ConsumerUser::class, ['id' => 'consumer_id']);
    }

    public function getBusiness(): ActiveQuery
    {
        return $this->hasOne(Business::class, ['id' => 'business_id']);
    }

    public function getItems(): ActiveQuery
    {
        return $this->hasMany(AppointmentItem::class, ['appointment_id' => 'id']);
    }

    /**
     * Expose the related names alongside the raw ids so the calendar/list can
     * render blocks without extra lookups. Relations are eager-loaded by the
     * controller to avoid N+1.
     */
    public function fields(): array
    {
        // Every column, not just the populated ones: a freshly inserted model
        // would otherwise omit null columns (consumer_id, guests, notes).
        $columns = $this->attributes();
        $fields = array_combine($columns, $columns);
        $fields['client_name'] = fn (self $m) => $m->client?->name;
        $fields['client_phone'] = fn (self $m) => $m->client?->phone;
        $fields['service_name'] = fn (self $m) => $m->service?->name;
        $fields['service_duration'] = fn (self $m) => $m->service ? (int) $m->service->duration_min : null;
        $fields['staff_name'] = fn (self $m) => $m->staff?->name;
        $fields['items'] = fn (self $m) => $m->items;
        return $fields;
    }
}
