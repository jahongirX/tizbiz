<?php

namespace api\modules\crm\controllers;

use common\models\Business;
use common\models\Review;
use common\presenters\ReviewPresenter;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * Consumer reviews of the active business (owner/admin only).
 *
 * GET  /v1/reviews?rating=&has_reply=0|1&page=&per_page=   any status, newest first
 * POST /v1/reviews/<id>/reply {"reply": "..."}             set / overwrite the reply
 */
class ReviewController extends Controller
{
    public function actionIndex(): array
    {
        $this->requireRole(Business::ROLE_OWNER, Business::ROLE_ADMIN);
        $businessId = Yii::$app->tenant->require();
        $req = Yii::$app->request;

        $query = Review::find(); // tenant-scoped
        $rating = (int) $req->get('rating', 0);
        if ($rating >= 1 && $rating <= 5) {
            $query->andWhere(['rating' => $rating]);
        }
        $hasReply = (string) $req->get('has_reply', '');
        if ($hasReply === '1') {
            $query->andWhere(['not', ['reply' => null]]);
        } elseif ($hasReply === '0') {
            $query->andWhere(['reply' => null]);
        }

        $page = max(1, (int) $req->get('page', 1));
        $perPage = min(50, max(1, (int) $req->get('per_page', 20)));
        $total = (int) (clone $query)->count();
        $rows = $query
            ->with(['staff', 'service'])
            ->orderBy(['created_at' => SORT_DESC, 'id' => SORT_DESC])
            ->offset(($page - 1) * $perPage)
            ->limit($perPage)
            ->all();

        $summary = Review::summary($businessId);
        return [
            'data' => array_map([ReviewPresenter::class, 'business'], $rows),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'pages' => (int) ceil($total / $perPage),
                'avg' => $summary['avg'],
                'count' => $summary['count'],
                'distribution' => $summary['distribution'],
            ],
        ];
    }

    public function actionReply(int $id)
    {
        $this->requireRole(Business::ROLE_OWNER, Business::ROLE_ADMIN);
        Yii::$app->tenant->require();

        $review = Review::findOne($id); // tenant-scoped
        if ($review === null) {
            throw new NotFoundHttpException('Sharh topilmadi.');
        }

        $reply = $this->body('reply');
        $reply = is_string($reply) ? trim($reply) : '';
        if ($reply === '') {
            $review->addError('reply', 'Javob bo\'sh bo\'lmasligi kerak.');
            return $this->fail422($review);
        }
        $review->reply = $reply;
        $review->replied_at = time();
        $review->replied_by = (int) $this->currentUser()->id;
        if (!$review->save(true, ['reply', 'replied_at', 'replied_by', 'updated_at'])) {
            return $this->fail422($review);
        }
        return ReviewPresenter::business($review);
    }
}
