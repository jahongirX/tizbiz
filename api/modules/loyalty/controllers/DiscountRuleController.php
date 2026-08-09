<?php

namespace api\modules\loyalty\controllers;

use common\models\DiscountRule;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * CRUD for tiered discount rules. Reads are open to any authed tenant user;
 * writes require owner/admin. All rows are tenant-scoped automatically via the
 * active business JWT.
 */
class DiscountRuleController extends Controller
{
    /** GET /v1/loyalty/discount-rules — ordered by metric, then threshold. */
    public function actionIndex(): array
    {
        return DiscountRule::find()
            ->orderBy(['metric' => SORT_ASC, 'threshold' => SORT_ASC])
            ->all();
    }

    /** GET /v1/loyalty/discount-rules/<id> */
    public function actionView(int $id): DiscountRule
    {
        return $this->findRule($id);
    }

    /** POST /v1/loyalty/discount-rules */
    public function actionCreate()
    {
        $this->requireRole('business_owner', 'business_admin');

        $rule = new DiscountRule();
        $rule->business_id = Yii::$app->tenant->require();
        $rule->load($this->body(), '');
        if (!$rule->save()) {
            return $this->fail422($rule);
        }
        return $this->created($rule);
    }

    /** PATCH /v1/loyalty/discount-rules/<id> */
    public function actionUpdate(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $rule = $this->findRule($id);
        $rule->load($this->body(), '');
        // business_id is tenant-owned; never accept it from the body.
        $rule->business_id = Yii::$app->tenant->require();
        if (!$rule->save()) {
            return $this->fail422($rule);
        }
        return $rule;
    }

    /** DELETE /v1/loyalty/discount-rules/<id> */
    public function actionDelete(int $id): void
    {
        $this->requireRole('business_owner', 'business_admin');

        $rule = $this->findRule($id);
        $rule->delete();
        Yii::$app->response->statusCode = 204;
    }

    /** Load a rule scoped to the active business (auto tenant filter) or 404. */
    private function findRule(int $id): DiscountRule
    {
        $rule = DiscountRule::findOne(['id' => $id]);
        if ($rule === null) {
            throw new NotFoundHttpException('Chegirma qoidasi topilmadi.');
        }
        return $rule;
    }
}
