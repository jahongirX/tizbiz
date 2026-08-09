<?php

namespace api\modules\crm\controllers;

use common\models\ClientCategory;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * CRM client categories CRUD.
 *
 * Reads (index/view) are available to any authenticated tenant user; writes
 * (create/update/delete) require business_owner or business_admin. All rows are
 * tenant-scoped automatically by {@see ClientCategory} via the active business JWT.
 */
class ClientCategoryController extends Controller
{
    /**
     * GET /v1/client-categories
     * Tenant-scoped categories, ordered by sort then id.
     */
    public function actionIndex(): array
    {
        Yii::$app->tenant->require();

        $rows = ClientCategory::find()
            ->orderBy(['sort' => SORT_ASC, 'id' => SORT_ASC])
            ->all();

        $data = [];
        foreach ($rows as $c) {
            $data[] = [
                'id' => (int) $c->id,
                'name' => $c->name,
                'color' => $c->color,
                'sort' => (int) $c->sort,
            ];
        }

        return ['data' => $data];
    }

    /**
     * POST /v1/client-categories {name,color?,sort?}
     */
    public function actionCreate()
    {
        $this->requireRole('business_owner', 'business_admin');

        $category = new ClientCategory();
        $category->load($this->body(), '');
        $category->business_id = Yii::$app->tenant->require();

        if (!$category->save()) {
            return $this->fail422($category);
        }

        return $this->created($category);
    }

    /**
     * PATCH /v1/client-categories/<id>
     */
    public function actionUpdate(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $category = $this->findCategory($id);
        $category->load($this->body(), '');
        // business_id is immutable / tenant-owned; never accept it from the body.
        $category->business_id = Yii::$app->tenant->require();

        if (!$category->save()) {
            return $this->fail422($category);
        }

        return $category;
    }

    /**
     * DELETE /v1/client-categories/<id>
     */
    public function actionDelete(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $category = $this->findCategory($id);
        $category->delete();

        Yii::$app->response->statusCode = 204;
        // Return null so the Envelope early-returns and emits no body for 204.
        return null;
    }

    /**
     * Load a tenant-scoped category or 404. The base AR find() already restricts
     * to the active business, so cross-tenant ids naturally miss.
     */
    private function findCategory(int $id): ClientCategory
    {
        // Assert an active tenant so a JWT with tid=null gets 403, not an
        // unscoped cross-tenant read.
        Yii::$app->tenant->require();

        $category = ClientCategory::findOne(['id' => $id]);
        if ($category === null) {
            throw new NotFoundHttpException('Kategoriya topilmadi.');
        }
        return $category;
    }
}
