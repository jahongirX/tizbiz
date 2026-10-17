<?php

namespace common\models;

use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;
use yii\db\ActiveRecord;

/**
 * A business a consumer saved. Unique per (consumer, business). Not tenant-scoped.
 *
 * @property int $id
 * @property int $consumer_id
 * @property int $business_id
 * @property int $created_at
 *
 * @property-read Business $business
 */
class ConsumerFavorite extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%consumer_favorites}}';
    }

    public function behaviors(): array
    {
        return [
            ['class' => TimestampBehavior::class, 'updatedAtAttribute' => false],
        ];
    }

    public function rules(): array
    {
        return [
            [['consumer_id', 'business_id'], 'required'],
            [['consumer_id', 'business_id'], 'integer'],
        ];
    }

    public function getBusiness(): ActiveQuery
    {
        return $this->hasOne(Business::class, ['id' => 'business_id']);
    }

    public function getConsumer(): ActiveQuery
    {
        return $this->hasOne(ConsumerUser::class, ['id' => 'consumer_id']);
    }
}
