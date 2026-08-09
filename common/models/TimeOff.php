<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\db\ActiveQuery;

/**
 * Days off / breaks that override the weekly template. A null start/end means
 * the whole day is blocked. NOT tenant-scoped (isolation via parent staff row).
 *
 * @property int $id
 * @property int $staff_id
 * @property string $date
 * @property string|null $start_time
 * @property string|null $end_time
 * @property string|null $reason
 */
class TimeOff extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%time_off}}';
    }

    public function rules(): array
    {
        return [
            [['staff_id', 'date'], 'required'],
            [['staff_id'], 'integer'],
            [['date', 'start_time', 'end_time'], 'string'],
            [['reason'], 'string', 'max' => 160],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'date' => 'Sana',
            'start_time' => 'Boshlanishi',
            'end_time' => 'Tugashi',
            'reason' => 'Sabab',
        ];
    }

    public function getStaff(): ActiveQuery
    {
        return $this->hasOne(Staff::class, ['id' => 'staff_id']);
    }
}
