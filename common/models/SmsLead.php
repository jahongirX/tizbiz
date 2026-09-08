<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * An application left from the sms.tizbiz.uz landing form (no login needed).
 * Managed as a mini-CRM in the superadmin cabinet.
 *
 * @property int $id
 * @property string|null $name
 * @property string $phone
 * @property string|null $business
 * @property string|null $tariff
 * @property string|null $note
 * @property string $status
 * @property string|null $source
 * @property int $created_at
 * @property int $updated_at
 */
class SmsLead extends ActiveRecord
{
    public const STATUSES = ['new', 'contacted', 'won', 'lost'];

    public static function tableName(): string
    {
        return '{{%sms_leads}}';
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
            [['name', 'business'], 'string', 'max' => 160],
            [['tariff', 'status', 'source'], 'string', 'max' => 40],
            [['note'], 'string', 'max' => 500],
            [['status'], 'in', 'range' => self::STATUSES],
            [['status'], 'default', 'value' => 'new'],
            [['source'], 'default', 'value' => 'landing'],
        ];
    }
}
