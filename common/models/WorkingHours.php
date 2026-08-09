<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\db\ActiveQuery;

/**
 * Weekly availability template per staff member. NOT tenant-scoped (no
 * business_id column); isolation is enforced via the parent staff row.
 * weekday: ISO-8601, 1 = Monday … 7 = Sunday. Times are local (business tz).
 *
 * @property int $id
 * @property int $staff_id
 * @property int $weekday
 * @property string $start_time
 * @property string $end_time
 */
class WorkingHours extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%working_hours}}';
    }

    public function rules(): array
    {
        return [
            [['staff_id', 'weekday', 'start_time', 'end_time'], 'required'],
            [['staff_id', 'weekday'], 'integer'],
            [['weekday'], 'integer', 'min' => 1, 'max' => 7],
            [['start_time', 'end_time'], 'string'],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'weekday' => 'Hafta kuni',
            'start_time' => 'Boshlanishi',
            'end_time' => 'Tugashi',
        ];
    }

    public function getStaff(): ActiveQuery
    {
        return $this->hasOne(Staff::class, ['id' => 'staff_id']);
    }
}
