<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * A saved recipient (name + phone) belonging to a dashboard account (user_id).
 * Used to pick numbers when composing a message. Phone is unique per account.
 *
 * @property int $id
 * @property int $user_id
 * @property string $name
 * @property string $phone
 * @property string|null $note
 * @property int $created_at
 * @property int $updated_at
 */
class SmsContact extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%sms_contacts}}';
    }

    public function behaviors(): array
    {
        return [TimestampBehavior::class];
    }

    public function rules(): array
    {
        return [
            [['user_id', 'name', 'phone'], 'required'],
            [['user_id'], 'integer'],
            [['name'], 'string', 'max' => 120],
            [['phone'], 'string', 'max' => 32],
            [['note'], 'string', 'max' => 255],
            [['phone'], 'unique', 'targetAttribute' => ['user_id', 'phone'], 'message' => 'Bu raqam allaqachon qo\'shilgan.'],
        ];
    }

    public function fields(): array
    {
        return ['id', 'name', 'phone', 'note', 'created_at'];
    }
}
