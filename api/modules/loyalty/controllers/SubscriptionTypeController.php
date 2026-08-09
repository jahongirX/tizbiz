<?php

namespace api\modules\loyalty\controllers;

use common\models\SubscriptionType;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * CRUD for subscription / pass types (Abonement turlari). Reads are open to any
 * authed tenant user; writes require owner/admin. All rows are tenant-scoped
 * automatically via the active business JWT.
 */
class SubscriptionTypeController extends Controller
{
    /** GET /v1/subscription-types — newest first. */
    public function actionIndex(): array
    {
        return SubscriptionType::find()
            ->orderBy(['id' => SORT_DESC])
            ->all();
    }

    /** GET /v1/subscription-types/<id> */
    public function actionView(int $id): SubscriptionType
    {
        return $this->findType($id);
    }

    /** POST /v1/subscription-types */
    public function actionCreate()
    {
        $this->requireRole('business_owner', 'business_admin');

        $type = new SubscriptionType();
        $type->business_id = Yii::$app->tenant->require();
        $type->load($this->body(), '');
        if (!$type->save()) {
            return $this->fail422($type);
        }
        return $this->created($type);
    }

    /** PATCH /v1/subscription-types/<id> */
    public function actionUpdate(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $type = $this->findType($id);
        $type->load($this->body(), '');
        // business_id is tenant-owned; never accept it from the body.
        $type->business_id = Yii::$app->tenant->require();
        if (!$type->save()) {
            return $this->fail422($type);
        }
        return $type;
    }

    /** DELETE /v1/subscription-types/<id> */
    public function actionDelete(int $id): void
    {
        $this->requireRole('business_owner', 'business_admin');

        $type = $this->findType($id);
        $type->delete();
        Yii::$app->response->statusCode = 204;
    }

    /** Load a type scoped to the active business (auto tenant filter) or 404. */
    private function findType(int $id): SubscriptionType
    {
        Yii::$app->tenant->require();

        $type = SubscriptionType::findOne(['id' => $id]);
        if ($type === null) {
            throw new NotFoundHttpException('Abonement turi topilmadi.');
        }
        return $type;
    }
}
