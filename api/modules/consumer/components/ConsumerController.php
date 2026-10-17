<?php

namespace api\modules\consumer\components;

use common\components\ConsumerAuth;
use common\models\ConsumerUser;
use common\rest\Controller;
use Yii;
use yii\db\ActiveQuery;
use yii\filters\auth\HttpBearerAuth;
use yii\web\UnauthorizedHttpException;

/**
 * Base for consumer-facing controllers (consumer + directory modules).
 *
 * Swaps the Bearer authenticator onto the `consumerUser` component, so only
 * typ=consumer tokens authenticate. `Yii::$app->user` stays empty, hence the
 * tenant context stays null: every query here must filter explicitly by
 * consumer_id / business_id.
 */
abstract class ConsumerController extends Controller
{
    public function behaviors(): array
    {
        $behaviors = parent::behaviors();
        $behaviors['authenticator'] = [
            'class' => HttpBearerAuth::class,
            'user' => ConsumerAuth::userComponent(),
            'optional' => $this->authOptional(),
        ];
        return $behaviors;
    }

    /** The authenticated consumer, or 401. */
    protected function consumer(): ConsumerUser
    {
        $consumer = ConsumerAuth::current();
        if ($consumer === null) {
            throw new UnauthorizedHttpException('Your request was made with invalid credentials.');
        }
        return $consumer;
    }

    /** The authenticated consumer, or null for anonymous callers. */
    protected function consumerOrNull(): ?ConsumerUser
    {
        return ConsumerAuth::current();
    }

    /** @return array{0:int, 1:int} [page, per_page] from the query string (per_page 1..50). */
    protected function pageParams(int $defaultPerPage = 20): array
    {
        $req = Yii::$app->request;
        $page = max(1, (int) $req->get('page', 1));
        $perPage = min(50, max(1, (int) $req->get('per_page', $defaultPerPage)));
        return [$page, $perPage];
    }

    /**
     * Run a paginated query and wrap it in {data, meta}.
     *
     * @param callable $map fn(array $models): array — turns the page's models into items
     */
    protected function paginate(ActiveQuery $query, callable $map, array $extraMeta = []): array
    {
        [$page, $perPage] = $this->pageParams();
        $total = (int) (clone $query)->orderBy(null)->count();
        $models = $query->offset(($page - 1) * $perPage)->limit($perPage)->all();
        return [
            'data' => $map($models),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'pages' => (int) ceil($total / $perPage),
            ] + $extraMeta,
        ];
    }

    /** Mark the response 204 No Content (the Envelope emits no body for null). */
    protected function noContent()
    {
        Yii::$app->response->statusCode = 204;
        return null;
    }
}
