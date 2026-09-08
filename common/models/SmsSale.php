<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * A manual subscription sale recorded by a superadmin (a lead/account bought a
 * tariff). Feeds the revenue reports. Amount is stored in so'm.
 *
 * @property int $id
 * @property int|null $lead_id
 * @property int|null $account_id
 * @property string|null $name
 * @property string|null $phone
 * @property string|null $tariff
 * @property int $amount
 * @property int $period_months
 * @property int|null $starts_at
 * @property int|null $ends_at
 * @property string|null $note
 * @property int $created_at
 * @property int $updated_at
 */
class SmsSale extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%sms_sales}}';
    }

    public function behaviors(): array
    {
        return [TimestampBehavior::class];
    }

    public function rules(): array
    {
        return [
            [['amount'], 'required'],
            [['lead_id', 'account_id', 'amount', 'period_months', 'starts_at', 'ends_at'], 'integer'],
            [['amount', 'period_months'], 'integer', 'min' => 0],
            [['name'], 'string', 'max' => 160],
            [['phone'], 'string', 'max' => 32],
            [['tariff'], 'string', 'max' => 20],
            [['note'], 'string', 'max' => 500],
            [['period_months'], 'default', 'value' => 12],
        ];
    }
}
