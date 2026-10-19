<?php

namespace common\models;

use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;
use yii\db\ActiveRecord;

/**
 * A branch (filial) of a business with its own address and map point.
 *
 * @property int $id
 * @property int $business_id
 * @property string $name
 * @property string|null $city
 * @property string|null $district
 * @property string|null $address
 * @property string|null $landmark
 * @property string|null $phone
 * @property string|null $hours e.g. "08:00-22:00"
 * @property string|null $lat decimal(10,7) as string from the driver
 * @property string|null $lng decimal(10,7) as string from the driver
 * @property int $sort
 * @property bool $is_active
 * @property int $created_at
 * @property int $updated_at
 * @property-read Business $business
 */
class BusinessBranch extends ActiveRecord
{
    public static function tableName(): string
    {
        return '{{%business_branches}}';
    }

    public function behaviors(): array
    {
        return [TimestampBehavior::class];
    }

    public function rules(): array
    {
        return [
            [['business_id', 'name'], 'required'],
            [['business_id', 'sort'], 'integer'],
            [['name'], 'string', 'max' => 128],
            [['city', 'district'], 'string', 'max' => 64],
            [['address', 'landmark'], 'string', 'max' => 255],
            [['phone'], 'string', 'max' => 32],
            [['hours'], 'string', 'max' => 64],
            [['lat'], 'number', 'min' => -90, 'max' => 90],
            [['lng'], 'number', 'min' => -180, 'max' => 180],
            [['is_active'], 'boolean'],
        ];
    }

    public function getBusiness(): ActiveQuery
    {
        return $this->hasOne(Business::class, ['id' => 'business_id']);
    }

    /**
     * Active branches of the given businesses, grouped by business id.
     *
     * @param int[] $businessIds
     * @return array<int, BusinessBranch[]>
     */
    public static function activeByBusiness(array $businessIds): array
    {
        if ($businessIds === []) {
            return [];
        }
        $out = [];
        $rows = self::find()
            ->where(['business_id' => $businessIds, 'is_active' => 1])
            ->orderBy(['sort' => SORT_ASC, 'id' => SORT_ASC])
            ->all();
        foreach ($rows as $b) {
            $out[(int) $b->business_id][] = $b;
        }
        return $out;
    }
}
