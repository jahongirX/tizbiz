<?php

namespace common\models;

use common\db\ActiveRecord;
use Yii;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveQuery;
use yii\db\Query;

/**
 * Consumer review of a completed appointment or a delivered order. Tenant-scoped
 * by business_id (business side lists/replies within its tenant; consumer
 * endpoints run without a tenant and filter by consumer_id explicitly).
 *
 * businesses.rating_avg / rating_count are cached aggregates over published
 * reviews and are recomputed after every save/delete.
 *
 * @property int $id
 * @property int $business_id
 * @property int|null $consumer_id
 * @property int|null $appointment_id
 * @property int|null $order_id
 * @property int|null $staff_id
 * @property int|null $service_id
 * @property string $author_name
 * @property int $rating
 * @property string|null $comment
 * @property string $status
 * @property string|null $reply
 * @property int|null $replied_at
 * @property int|null $replied_by
 * @property int $created_at
 * @property int $updated_at
 *
 * @property-read Business $business
 * @property-read Staff|null $staff
 * @property-read Service|null $service
 */
class Review extends ActiveRecord
{
    public const STATUS_PUBLISHED = 'published';
    public const STATUS_HIDDEN = 'hidden';
    public const STATUSES = [self::STATUS_PUBLISHED, self::STATUS_HIDDEN];

    /** author_name for reviews of a deleted consumer account. */
    public const DELETED_AUTHOR = "O'chirilgan foydalanuvchi";

    public static function tableName(): string
    {
        return '{{%reviews}}';
    }

    public static function isTenantScoped(): bool
    {
        return true;
    }

    public function behaviors(): array
    {
        return [TimestampBehavior::class];
    }

    public function rules(): array
    {
        return [
            [['business_id', 'author_name', 'rating'], 'required'],
            [['business_id', 'consumer_id', 'appointment_id', 'order_id', 'staff_id', 'service_id', 'replied_at', 'replied_by'], 'integer'],
            [['rating'], 'integer', 'min' => 1, 'max' => 5, 'message' => 'Baho 1 dan 5 gacha bo\'lishi kerak.',
                'tooSmall' => 'Baho 1 dan 5 gacha bo\'lishi kerak.', 'tooBig' => 'Baho 1 dan 5 gacha bo\'lishi kerak.'],
            [['comment'], 'string', 'max' => 1000, 'tooLong' => 'Sharh 1000 belgidan oshmasligi kerak.'],
            [['reply'], 'string', 'min' => 1, 'max' => 1000, 'tooShort' => 'Javob bo\'sh bo\'lmasligi kerak.',
                'tooLong' => 'Javob 1000 belgidan oshmasligi kerak.'],
            [['author_name'], 'string', 'max' => 64],
            [['status'], 'in', 'range' => self::STATUSES],
            [['status'], 'default', 'value' => self::STATUS_PUBLISHED],
        ];
    }

    public function attributeLabels(): array
    {
        return [
            'rating' => 'Baho',
            'comment' => 'Sharh',
            'reply' => 'Javob',
            'status' => 'Holat',
            'author_name' => 'Muallif',
        ];
    }

    public function getBusiness(): ActiveQuery
    {
        return $this->hasOne(Business::class, ['id' => 'business_id']);
    }

    public function getStaff(): ActiveQuery
    {
        return $this->hasOne(Staff::class, ['id' => 'staff_id']);
    }

    public function getService(): ActiveQuery
    {
        return $this->hasOne(Service::class, ['id' => 'service_id']);
    }

    public function getConsumer(): ActiveQuery
    {
        return $this->hasOne(ConsumerUser::class, ['id' => 'consumer_id']);
    }

    public function afterSave($insert, $changedAttributes): void
    {
        parent::afterSave($insert, $changedAttributes);
        if ($insert || array_key_exists('rating', $changedAttributes)
            || array_key_exists('status', $changedAttributes)
            || array_key_exists('business_id', $changedAttributes)) {
            self::recomputeBusinessRating((int) $this->business_id);
        }
    }

    public function afterDelete(): void
    {
        parent::afterDelete();
        self::recomputeBusinessRating((int) $this->business_id);
    }

    /**
     * Refresh businesses.rating_avg (ROUND(AVG, 2)) and rating_count over the
     * business's published reviews. Uses plain queries (no tenant scope).
     */
    public static function recomputeBusinessRating(int $businessId): void
    {
        if ($businessId <= 0) {
            return;
        }
        $row = (new Query())
            ->select(['cnt' => 'COUNT(*)', 'avg' => 'AVG(rating)'])
            ->from(self::tableName())
            ->where(['business_id' => $businessId, 'status' => self::STATUS_PUBLISHED])
            ->one(Yii::$app->db);
        $count = (int) ($row['cnt'] ?? 0);
        $avg = $count > 0 ? round((float) $row['avg'], 2) : 0.0;
        Yii::$app->db->createCommand()->update(
            Business::tableName(),
            ['rating_avg' => $avg, 'rating_count' => $count],
            ['id' => $businessId]
        )->execute();
    }

    /**
     * Rating distribution {"1":n,..,"5":n} and avg/count for a business over
     * published reviews, or (with $publishedOnly=false) over every status.
     *
     * @return array{avg: float, count: int, distribution: array<string,int>}
     */
    public static function summary(int $businessId, bool $publishedOnly = true): array
    {
        $q = (new Query())
            ->select(['rating', 'cnt' => 'COUNT(*)'])
            ->from(self::tableName())
            ->where(['business_id' => $businessId])
            ->groupBy('rating');
        if ($publishedOnly) {
            $q->andWhere(['status' => self::STATUS_PUBLISHED]);
        }
        $dist = ['1' => 0, '2' => 0, '3' => 0, '4' => 0, '5' => 0];
        $count = 0;
        $sum = 0;
        foreach ($q->all(Yii::$app->db) as $r) {
            $rating = (int) $r['rating'];
            $n = (int) $r['cnt'];
            if ($rating >= 1 && $rating <= 5) {
                $dist[(string) $rating] = $n;
                $count += $n;
                $sum += $rating * $n;
            }
        }
        return [
            'avg' => $count > 0 ? round($sum / $count, 2) : 0.0,
            'count' => $count,
            'distribution' => $dist,
        ];
    }

    /** "Aziza Karimova" -> "Aziza K."; "Aziza" -> "Aziza"; empty -> "Mijoz". */
    public static function maskName(?string $name): string
    {
        $parts = preg_split('/\s+/u', trim((string) $name), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        if ($parts === []) {
            return 'Mijoz';
        }
        $first = $parts[0];
        if (count($parts) === 1) {
            return mb_substr($first, 0, 64);
        }
        $last = $parts[count($parts) - 1];
        return mb_substr($first . ' ' . mb_strtoupper(mb_substr($last, 0, 1)) . '.', 0, 64);
    }
}
