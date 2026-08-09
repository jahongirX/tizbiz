<?php

namespace api\modules\loyalty\controllers;

use api\modules\loyalty\services\AutoCategoryService;
use common\models\AutoCategoryRule;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * CRUD for auto-category rules plus a manual "apply now" action. Reads are open
 * to any authed tenant user; writes and apply require owner/admin. All rows are
 * tenant-scoped automatically via the active business JWT.
 */
class AutoCategoryRuleController extends Controller
{
    /** GET /v1/loyalty/auto-category-rules — ordered by metric, then threshold. */
    public function actionIndex(): array
    {
        return AutoCategoryRule::find()
            ->orderBy(['metric' => SORT_ASC, 'threshold' => SORT_ASC])
            ->all();
    }

    /** GET /v1/loyalty/auto-category-rules/<id> */
    public function actionView(int $id): AutoCategoryRule
    {
        return $this->findRule($id);
    }

    /** POST /v1/loyalty/auto-category-rules */
    public function actionCreate()
    {
        $this->requireRole('business_owner', 'business_admin');

        $rule = new AutoCategoryRule();
        $rule->business_id = Yii::$app->tenant->require();
        $rule->load($this->body(), '');
        if (!$rule->save()) {
            return $this->fail422($rule);
        }
        return $this->created($rule);
    }

    /** PATCH /v1/loyalty/auto-category-rules/<id> */
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

    /** DELETE /v1/loyalty/auto-category-rules/<id> */
    public function actionDelete(int $id): void
    {
        $this->requireRole('business_owner', 'business_admin');

        $rule = $this->findRule($id);
        $rule->delete();
        Yii::$app->response->statusCode = 204;
    }

    /**
     * POST /v1/loyalty/auto-category-rules/apply — run all active auto-category
     * rules for the business now.
     *
     * @return array{added:int, removed:int}
     */
    public function actionApply(): array
    {
        $this->requireRole('business_owner', 'business_admin');

        $businessId = Yii::$app->tenant->require();
        return (new AutoCategoryService())->apply($businessId);
    }

    /** Load a rule scoped to the active business (auto tenant filter) or 404. */
    private function findRule(int $id): AutoCategoryRule
    {
        $rule = AutoCategoryRule::findOne(['id' => $id]);
        if ($rule === null) {
            throw new NotFoundHttpException('Avto-kategoriya qoidasi topilmadi.');
        }
        return $rule;
    }
}
