<?php

namespace api\modules\inventory\controllers;

use common\models\Product;
use common\models\StockMovement;
use common\rest\Controller;
use Yii;
use yii\db\Expression;
use yii\web\NotFoundHttpException;

/**
 * Inventory products + stock ledger.
 *
 * Reads (index/view/movements/summary) are available to any authenticated
 * tenant member; writes (create/update/delete/stock) require owner/admin. All
 * rows are tenant-scoped automatically by {@see Product} / {@see StockMovement}
 * via the active business JWT. Money is in tiyin; quantities are integers.
 */
class ProductController extends Controller
{
    private const PAGE_SIZE = 20;
    private const MOVEMENTS_LIMIT = 50;

    /**
     * GET /v1/products?search=&low_stock=&page=&per_page=
     *
     * search matches name (LIKE). low_stock=1 keeps only products at or below
     * their reorder threshold (stock_qty <= low_stock).
     */
    public function actionIndex(): array
    {
        Yii::$app->tenant->require();

        $search = trim((string) Yii::$app->request->get('search', ''));
        $lowStock = (string) Yii::$app->request->get('low_stock', '') === '1';
        $page = max(1, (int) Yii::$app->request->get('page', 1));
        $perPage = min(100, max(1, (int) Yii::$app->request->get('per_page', self::PAGE_SIZE)));

        $query = Product::find();
        if ($search !== '') {
            $query->andWhere(['like', 'name', $search]);
        }
        if ($lowStock) {
            $query->andWhere(new Expression('stock_qty <= low_stock'));
        }

        $total = (int) (clone $query)->count();

        $rows = $query
            ->orderBy(['id' => SORT_DESC])
            ->offset(($page - 1) * $perPage)
            ->limit($perPage)
            ->all();

        return [
            'data' => $rows,
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'pages' => (int) ceil($total / max(1, $perPage)),
            ],
        ];
    }

    /**
     * GET /v1/products/<id>
     */
    public function actionView(int $id): Product
    {
        return $this->findProduct($id);
    }

    /**
     * POST /v1/products
     */
    public function actionCreate()
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = new Product();
        $model->load($this->body(), '');
        $model->business_id = Yii::$app->tenant->require();

        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $this->created($model);
    }

    /**
     * PATCH /v1/products/<id>
     */
    public function actionUpdate(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = $this->findProduct($id);
        $model->load($this->body(), '');
        // business_id is tenant-owned; never accept it from the body.
        $model->business_id = Yii::$app->tenant->require();

        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $model;
    }

    /**
     * DELETE /v1/products/<id>
     */
    public function actionDelete(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = $this->findProduct($id);
        $model->delete();

        Yii::$app->response->statusCode = 204;
        return null;
    }

    /**
     * POST /v1/products/<id>/stock {delta_qty:int (signed), type, reason?}
     *
     * In a single transaction: append an immutable StockMovement and adjust the
     * product's stock_qty by delta_qty. `adjust` may drive stock negative (e.g.
     * inventory corrections); `out`/`writeoff` that would push stock below zero
     * are rejected (422). Returns the updated product.
     */
    public function actionStock(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $businessId = Yii::$app->tenant->require();
        $product = $this->findProduct($id);

        $movement = new StockMovement();
        $movement->business_id = $businessId;
        $movement->product_id = $product->id;
        $movement->delta_qty = (int) $this->body('delta_qty', 0);
        $movement->type = (string) $this->body('type', '');
        $movement->reason = $this->body('reason');

        if (!$movement->validate()) {
            return $this->fail422($movement);
        }

        $newQty = (int) $product->stock_qty + $movement->delta_qty;

        if (in_array($movement->type, [StockMovement::TYPE_OUT, StockMovement::TYPE_WRITEOFF], true)
            && $newQty < 0
        ) {
            Yii::$app->response->statusCode = 422;
            return [[
                'field' => 'delta_qty',
                'message' => 'Zaxira manfiy bo\'lishi mumkin emas. Joriy zaxira: ' . (int) $product->stock_qty,
            ]];
        }

        $tx = Product::getDb()->beginTransaction();
        try {
            if (!$movement->save(false)) {
                $tx->rollBack();
                return $this->fail422($movement);
            }
            $product->stock_qty = $newQty;
            if (!$product->save(false, ['stock_qty', 'updated_at'])) {
                $tx->rollBack();
                return $this->fail422($product);
            }
            $tx->commit();
        } catch (\Throwable $e) {
            $tx->rollBack();
            throw $e;
        }

        return $product;
    }

    /**
     * GET /v1/products/<id>/movements
     * Recent ledger rows for a product, newest first.
     */
    public function actionMovements(int $id): array
    {
        $product = $this->findProduct($id);

        $rows = StockMovement::find()
            ->andWhere(['product_id' => $product->id])
            ->orderBy(['id' => SORT_DESC])
            ->limit(self::MOVEMENTS_LIMIT)
            ->all();

        return ['data' => $rows];
    }

    /**
     * GET /v1/products/summary
     * Tenant-wide inventory snapshot.
     */
    public function actionSummary(): array
    {
        Yii::$app->tenant->require();

        $total = (int) Product::find()->count();
        $lowStockCount = (int) Product::find()
            ->andWhere(new Expression('stock_qty <= low_stock'))
            ->count();
        $stockValue = (int) Product::find()
            ->select(new Expression('COALESCE(SUM(cost_tiyin * stock_qty), 0)'))
            ->scalar();

        return [
            'total' => $total,
            'low_stock_count' => $lowStockCount,
            'stock_value_tiyin' => $stockValue,
        ];
    }

    /**
     * Load a tenant-scoped product or 404. The base AR find() already restricts
     * to the active business, so cross-tenant ids naturally miss.
     */
    private function findProduct(int $id): Product
    {
        // Assert an active tenant so a JWT with tid=null gets 403, not an
        // unscoped cross-tenant read.
        Yii::$app->tenant->require();

        $product = Product::findOne(['id' => $id]);
        if ($product === null) {
            throw new NotFoundHttpException('Mahsulot topilmadi.');
        }
        return $product;
    }
}
