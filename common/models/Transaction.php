<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * Payment record: deposits, refunds and platform float. Money in TIYIN (1/100 so'm).
 *
 * provider: payme/click; type: deposit/refund/float;
 * status: created/pending/paid/canceled/refunded.
 * external_id holds the PSP transaction id (Payme tx id / Click click_trans_id).
 * idempotency_key (unique) guards duplicate deposit init and webhook processing.
 *
 * @property int $id
 * @property int $business_id
 * @property int|null $appointment_id
 * @property string $provider
 * @property int $amount_tiyin
 * @property string $type
 * @property string $status
 * @property string|null $external_id
 * @property string|null $idempotency_key
 * @property int $created_at
 * @property int $updated_at
 *
 * @property-read Appointment|null $appointment
 */
class Transaction extends ActiveRecord
{
    public const STATUS_CREATED = 'created';
    public const STATUS_PENDING = 'pending';
    public const STATUS_PAID = 'paid';
    public const STATUS_CANCELED = 'canceled';
    public const STATUS_REFUNDED = 'refunded';

    /** Money taken in the shop for a finished visit (not an online payment). */
    public const TYPE_SALE = 'sale';
    public const TYPE_DEPOSIT = 'deposit';
    public const TYPE_REFUND = 'refund';
    public const TYPE_FLOAT = 'float';

    /** Paid in person; the shop is the "provider". */
    public const PROVIDER_CASH = 'cash';
    public const PROVIDER_PAYME = 'payme';
    public const PROVIDER_CLICK = 'click';

    public static function tableName(): string
    {
        return '{{%transactions}}';
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
            [['business_id', 'provider', 'amount_tiyin', 'type', 'status'], 'required'],
            [['business_id', 'appointment_id', 'amount_tiyin'], 'integer'],
            [['provider'], 'in', 'range' => [self::PROVIDER_CASH, self::PROVIDER_PAYME, self::PROVIDER_CLICK]],
            [['type'], 'in', 'range' => [self::TYPE_SALE, self::TYPE_DEPOSIT, self::TYPE_REFUND, self::TYPE_FLOAT]],
            [['status'], 'in', 'range' => [
                self::STATUS_CREATED,
                self::STATUS_PENDING,
                self::STATUS_PAID,
                self::STATUS_CANCELED,
                self::STATUS_REFUNDED,
            ]],
            [['status'], 'default', 'value' => self::STATUS_CREATED],
            [['external_id'], 'string', 'max' => 128],
            [['idempotency_key'], 'string', 'max' => 64],
            [['idempotency_key'], 'unique'],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'appointment_id' => 'Bron',
            'provider' => 'To\'lov tizimi',
            'amount_tiyin' => 'Summa',
            'type' => 'Turi',
            'status' => 'Holat',
            'external_id' => 'Tashqi ID',
            'idempotency_key' => 'Idempotentlik kaliti',
            'created_at' => 'Yaratilgan sana',
            'updated_at' => 'Yangilangan sana',
        ];
    }

    public function getAppointment()
    {
        return $this->hasOne(Appointment::class, ['id' => 'appointment_id']);
    }

    /**
     * A paid deposit confirms its booking: mark the linked appointment paid and,
     * if still pending, confirmed. Called from the PSP gateways on a paid transition.
     */
    public function markAppointmentPaid(): void
    {
        if ($this->type !== self::TYPE_DEPOSIT || empty($this->appointment_id)) {
            return;
        }
        $appointment = $this->appointment;
        if ($appointment === null) {
            return;
        }
        $changed = false;
        if (!$appointment->paid) {
            $appointment->paid = 1;
            $changed = true;
        }
        if ($appointment->status === Appointment::STATUS_PENDING) {
            $appointment->status = Appointment::STATUS_CONFIRMED;
            $changed = true;
        }
        if ($changed) {
            $appointment->save(false);
        }
    }

    /**
     * Public-safe serialization. Hides idempotency_key, external_id and
     * business_id so the public deposit response leaks nothing sensitive.
     */
    public function fields(): array
    {
        return [
            'id',
            'provider',
            'amount_tiyin',
            'type',
            'status',
            'appointment_id',
            'created_at',
        ];
    }
}
