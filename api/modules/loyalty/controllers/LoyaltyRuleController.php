<?php

namespace api\modules\loyalty\controllers;

use common\models\LoyaltyRule;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * CRUD for loyalty rules (typically a single active rule per business).
 * Reads are open to any authed user; writes require owner/admin.
 */
class LoyaltyRuleController extends Controller
{
    /** GET /v1/loyalty/rules — all rules for the active business. */
    public function actionIndex(): array
    {
        return LoyaltyRule::find()
            ->orderBy(['id' => SORT_DESC])
            ->all();
    }

    /** GET /v1/loyalty/rules/<id> */
    public function actionView(int $id): LoyaltyRule
    {
        return $this->findRule($id);
    }

    /** POST /v1/loyalty/rules */
    public function actionCreate()
    {
        $this->requireRole('business_owner', 'business_admin');

        $rule = new LoyaltyRule();
        $rule->business_id = Yii::$app->tenant->require();
        $rule->load($this->body(), '');
        if (!$rule->save()) {
            return $this->fail422($rule);
        }
        return $this->created($rule);
    }

    /** PUT /v1/loyalty/rules/<id> */
    public function actionUpdate(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $rule = $this->findRule($id);
        $rule->load($this->body(), '');
        if (!$rule->save()) {
            return $this->fail422($rule);
        }
        return $rule;
    }

    /** DELETE /v1/loyalty/rules/<id> */
    public function actionDelete(int $id): void
    {
        $this->requireRole('business_owner', 'business_admin');

        $rule = $this->findRule($id);
        $rule->delete();
        Yii::$app->response->statusCode = 204;
    }

    /** Load a rule scoped to the active business (auto tenant filter) or 404. */
    private function findRule(int $id): LoyaltyRule
    {
        $rule = LoyaltyRule::findOne(['id' => $id]);
        if ($rule === null) {
            throw new NotFoundHttpException('Loyallik qoidasi topilmadi.');
        }
        return $rule;
    }
}
