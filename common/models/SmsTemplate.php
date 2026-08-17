<?php

namespace common\models;

use common\db\ActiveRecord;
use yii\behaviors\TimestampBehavior;

/**
 * A reusable message text saved by a dashboard account (user_id) and picked when
 * composing a message.
 *
 * @property int $id
 * @property int $user_id
 * @property string $name
 * @property string $text
 * @property int $created_at
 * @property int $updated_at
 */
class SmsTemplate extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%sms_templates}}';
    }

    public function behaviors(): array
    {
        return [TimestampBehavior::class];
    }

    public function rules(): array
    {
        return [
            [['user_id', 'name', 'text'], 'required'],
            [['user_id'], 'integer'],
            [['text'], 'string'],
            [['name'], 'string', 'max' => 120],
        ];
    }

    public function fields(): array
    {
        return ['id', 'name', 'text', 'created_at', 'updated_at'];
    }
}
