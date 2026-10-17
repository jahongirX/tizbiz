<?php

namespace api\modules\directory\controllers;

use api\modules\consumer\components\ConsumerController;
use common\helpers\Categories;
use common\models\Business;
use common\models\ConsumerFavorite;
use common\models\Review;
use common\presenters\BusinessPresenter;
use common\presenters\ReviewPresenter;
use Yii;
use yii\db\ActiveQuery;
use yii\db\Expression;
use yii\db\Query;
use yii\web\BadRequestHttpException;
use yii\web\NotFoundHttpException;

/**
 * Public directory for the Bizcat consumer app. Only whitelisted presenter
 * payloads are returned (never the Business AR).
 *
 * GET /v1/directory/categories
 * GET /v1/directory/businesses?q=&category=&engine=&city=&sort=&page=&per_page=
 * GET /v1/directory/businesses/<slug>
 * GET /v1/directory/businesses/<slug>/reviews?rating=&page=&per_page=
 * GET /v1/directory/map?q=&category=&engine=&city=&bbox=minLng,minLat,maxLng,maxLat
 */
class DirectoryController extends ConsumerController
{
    private const SORTS = ['featured', 'rating', 'new', 'name'];

    /** Most pins one map request returns (the app asks again when the viewport moves). */
    private const MAP_LIMIT = 300;

    protected function authOptional(): array
    {
        return ['categories', 'index', 'view', 'reviews', 'map'];
    }

    public function actionCategories(): array
    {
        $counts = (new Query())
            ->select(['category', 'cnt' => 'COUNT(*)'])
            ->from(Business::tableName())
            ->where(['status' => Business::STATUS_ACTIVE, 'is_listed' => 1])
            ->groupBy('category')
            ->all(Yii::$app->db);
        $map = [];
        foreach ($counts as $r) {
            if ($r['category'] !== null) {
                $map[(string) $r['category']] = (int) $r['cnt'];
            }
        }
        return array_map(
            static fn (array $c) => $c + ['count' => $map[$c['key']] ?? 0],
            Categories::all()
        );
    }

    /**
     * A query parameter as a trimmed string. Array values (?q[]=x) are bad
     * input: 400, never a PHP "Array to string conversion" 500.
     */
    private static function strParam(string $name, string $default = ''): string
    {
        $v = Yii::$app->request->get($name, $default);
        if ($v === null) {
            return $default;
        }
        if (!is_string($v)) {
            throw new BadRequestHttpException("{$name} noto'g'ri.");
        }
        return trim($v);
    }

    public function actionIndex(): array
    {
        $sort = self::strParam('sort', 'featured');
        if ($sort === '') {
            $sort = 'featured';
        }
        if (!in_array($sort, self::SORTS, true)) {
            throw new BadRequestHttpException('Noto\'g\'ri saralash.');
        }

        $query = self::filteredQuery();
        $this->applySort($query, $sort);

        $consumer = $this->consumerOrNull();
        return $this->paginate($query, static function (array $businesses) use ($consumer): array {
            $prices = BusinessPresenter::priceFromMap($businesses);
            $favs = self::favoriteIds($consumer !== null ? (int) $consumer->id : null, $businesses);
            return array_map(static fn (Business $b) => BusinessPresenter::card($b, [
                'price_from_tiyin' => $prices[(int) $b->id] ?? null,
                'is_favorite' => isset($favs[(int) $b->id]),
            ]), $businesses);
        });
    }

    /**
     * Map pins: businesses with coordinates, optionally inside a viewport
     * (bbox=minLng,minLat,maxLng,maxLat), best rated first, at most MAP_LIMIT.
     * meta.truncated tells the app that more pins exist (zoom in).
     */
    public function actionMap(): array
    {
        $query = self::filteredQuery()
            ->andWhere(['not', ['lat' => null]])
            ->andWhere(['not', ['lng' => null]]);

        $bbox = self::strParam('bbox');
        if ($bbox !== '') {
            $parts = explode(',', $bbox);
            if (count($parts) !== 4 || array_filter($parts, static fn ($p) => !is_numeric(trim($p))) !== []) {
                throw new BadRequestHttpException('bbox noto\'g\'ri.');
            }
            [$minLng, $minLat, $maxLng, $maxLat] = array_map(static fn ($p) => (float) trim($p), $parts);
            if ($minLat > $maxLat || $minLat < -90 || $maxLat > 90 || $minLng < -180 || $maxLng > 180) {
                throw new BadRequestHttpException('bbox noto\'g\'ri.');
            }
            $query->andWhere(['between', 'lat', $minLat, $maxLat]);
            // A viewport across the antimeridian has minLng > maxLng.
            $query->andWhere($minLng <= $maxLng
                ? ['between', 'lng', $minLng, $maxLng]
                : ['or', ['>=', 'lng', $minLng], ['<=', 'lng', $maxLng]]);
        }

        $total = (int) (clone $query)->orderBy(null)->count();
        $this->applySort($query, 'rating');
        $businesses = $query->limit(self::MAP_LIMIT)->all();

        $consumer = $this->consumerOrNull();
        $prices = BusinessPresenter::priceFromMap($businesses);
        $favs = self::favoriteIds($consumer !== null ? (int) $consumer->id : null, $businesses);
        return [
            'data' => array_map(static fn (Business $b) => BusinessPresenter::card($b, [
                'price_from_tiyin' => $prices[(int) $b->id] ?? null,
                'is_favorite' => isset($favs[(int) $b->id]),
            ]), $businesses),
            'meta' => ['total' => $total, 'truncated' => $total > count($businesses)],
        ];
    }

    public function actionView(string $slug): array
    {
        $business = $this->findBusiness($slug);
        $consumer = $this->consumerOrNull();
        $isFavorite = isset(self::favoriteIds($consumer !== null ? (int) $consumer->id : null, [$business])[(int) $business->id]);

        $preview = Review::find()
            ->where(['business_id' => (int) $business->id, 'status' => Review::STATUS_PUBLISHED])
            ->with(['staff', 'service'])
            ->orderBy(['created_at' => SORT_DESC, 'id' => SORT_DESC])
            ->limit(3)
            ->all();

        return [
            'business' => BusinessPresenter::detail($business, ['is_favorite' => $isFavorite]),
            'rating' => Review::summary((int) $business->id),
            'reviews_preview' => array_map([ReviewPresenter::class, 'public'], $preview),
            'is_favorite' => $isFavorite,
        ];
    }

    public function actionReviews(string $slug): array
    {
        $business = $this->findBusiness($slug);
        $query = Review::find()
            ->where(['business_id' => (int) $business->id, 'status' => Review::STATUS_PUBLISHED])
            ->with(['staff', 'service'])
            ->orderBy(['created_at' => SORT_DESC, 'id' => SORT_DESC]);
        $rating = (int) Yii::$app->request->get('rating', 0);
        if ($rating >= 1 && $rating <= 5) {
            $query->andWhere(['rating' => $rating]);
        }

        return $this->paginate(
            $query,
            static fn (array $rows) => array_map([ReviewPresenter::class, 'public'], $rows),
            Review::summary((int) $business->id)
        );
    }

    /** Active business by slug (listed or not: deep links keep working). */
    private function findBusiness(string $slug): Business
    {
        $business = Business::find()
            ->andWhere(['slug' => $slug, 'status' => Business::STATUS_ACTIVE])
            ->one();
        if ($business === null) {
            throw new NotFoundHttpException('Biznes topilmadi.');
        }
        return $business;
    }

    /** Listed active businesses narrowed by the shared q/category/engine/city filters. */
    private static function filteredQuery(): ActiveQuery
    {
        $query = Business::find()
            ->andWhere(['status' => Business::STATUS_ACTIVE, 'is_listed' => 1]);

        $q = self::strParam('q');
        if ($q !== '') {
            $query->andWhere(['or',
                ['like', 'name', $q],
                ['like', 'tagline', $q],
                ['like', 'description', $q],
                ['like', 'address', $q],
            ]);
        }
        $category = self::strParam('category');
        if ($category !== '') {
            $query->andWhere(['category' => $category]);
        }
        $engine = self::strParam('engine');
        if ($engine !== '') {
            $query->andWhere($engine === 'slot'
                ? ['or', ['engine' => 'slot'], ['engine' => null]]
                : ['engine' => $engine]);
        }
        $city = self::strParam('city');
        if ($city !== '') {
            $query->andWhere(new Expression('LOWER(city) = :city', [':city' => mb_strtolower($city)]));
        }
        return $query;
    }

    private function applySort(ActiveQuery $query, string $sort): void
    {
        switch ($sort) {
            case 'rating':
                $query->orderBy(['rating_avg' => SORT_DESC, 'rating_count' => SORT_DESC, 'id' => SORT_DESC]);
                break;
            case 'new':
                $query->orderBy(['id' => SORT_DESC]);
                break;
            case 'name':
                $query->orderBy(['name' => SORT_ASC, 'id' => SORT_ASC]);
                break;
            default: // featured
                $now = (int) time();
                $query->orderBy([
                    new Expression('CASE WHEN featured_until > ' . $now . ' THEN 1 ELSE 0 END DESC'),
                    'rating_avg' => SORT_DESC,
                    'rating_count' => SORT_DESC,
                    'id' => SORT_DESC,
                ]);
        }
    }

    /**
     * @param Business[] $businesses
     * @return array<int, true> business ids the consumer saved
     */
    private static function favoriteIds(?int $consumerId, array $businesses): array
    {
        if ($consumerId === null || $businesses === []) {
            return [];
        }
        $ids = ConsumerFavorite::find()
            ->select(['business_id'])
            ->where([
                'consumer_id' => $consumerId,
                'business_id' => array_map(static fn (Business $b) => (int) $b->id, $businesses),
            ])
            ->column();
        return array_fill_keys(array_map('intval', $ids), true);
    }
}
