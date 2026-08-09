<?php

namespace api\modules\loyalty\services;

use common\models\Appointment;
use common\models\AutoCategoryRule;
use common\models\Client;
use common\models\ClientCategory;
use common\models\ClientCategoryAssignment;
use common\models\Service;
use common\models\Transaction;
use Yii;
use yii\db\Query;

/**
 * Auto-category engine: evaluates every active {@see AutoCategoryRule} for a
 * business against per-client aggregates and adds/removes category assignments.
 *
 * Per-client metrics (all money in tiyin, integers):
 *   - sold          SUM of completed appointments' service price_tiyin
 *   - paid          SUM of paid deposit transactions' amount_tiyin
 *   - visits        COUNT of completed appointments
 *   - inactive_days days since the last completed appointment
 *                   (clients with no completed visit are treated as very inactive)
 *
 * Metrics are computed in one grouped query mirroring the CRM client base.
 */
class AutoCategoryService
{
    /**
     * A client that never completed an appointment is "infinitely" inactive.
     * A large finite sentinel keeps threshold comparisons simple and always
     * makes such clients match any inactive_days rule.
     */
    private const NEVER_ACTIVE_DAYS = 100000;

    /**
     * Run all active auto-category rules for a business.
     *
     * @return array{added:int, removed:int} count of assignment rows created/deleted.
     */
    public function apply(int $businessId): array
    {
        $rules = AutoCategoryRule::find()
            ->where(['business_id' => $businessId, 'active' => true])
            ->all();

        if (empty($rules)) {
            return ['added' => 0, 'removed' => 0];
        }

        $metrics = $this->clientMetrics($businessId);
        if (empty($metrics)) {
            return ['added' => 0, 'removed' => 0];
        }

        // Restrict rules to categories that actually belong to this business, so a
        // stale category_id can never touch another tenant's data.
        $validCategoryIds = ClientCategory::find()
            ->select('id')
            ->where(['business_id' => $businessId])
            ->column();
        $validCategoryIds = array_map('intval', $validCategoryIds);

        $added = 0;
        $removed = 0;

        $tx = Yii::$app->db->beginTransaction();
        try {
            foreach ($rules as $rule) {
                $categoryId = (int) $rule->category_id;
                if (!in_array($categoryId, $validCategoryIds, true)) {
                    continue;
                }

                foreach ($metrics as $clientId => $m) {
                    $value = $this->metricValue($rule->metric, $m);
                    if ($value < (int) $rule->threshold) {
                        continue;
                    }

                    if ($rule->action === AutoCategoryRule::ACTION_REMOVE) {
                        $removed += $this->removeAssignment((int) $clientId, $categoryId);
                    } else {
                        $added += $this->addAssignment((int) $clientId, $categoryId);
                    }
                }
            }

            $tx->commit();
        } catch (\Throwable $e) {
            $tx->rollBack();
            throw $e;
        }

        return ['added' => $added, 'removed' => $removed];
    }

    /**
     * Per-client aggregates for a business, keyed by client id.
     *
     * @return array<int, array{sold:int, paid:int, visits:int, inactive_days:int}>
     */
    private function clientMetrics(int $businessId): array
    {
        // Quote status/type literals rather than binding named params so the
        // aggregate expressions carry no dangling bound variables. All values are
        // controlled enum constants, never user input.
        $done = Yii::$app->db->quoteValue(Appointment::STATUS_COMPLETED);
        $deposit = Yii::$app->db->quoteValue(Transaction::TYPE_DEPOSIT);
        $paidStatus = Yii::$app->db->quoteValue(Transaction::STATUS_PAID);

        $visitsExpr = "COUNT(DISTINCT CASE WHEN a.status = $done THEN a.id END)";
        $soldExpr = "COALESCE(SUM(CASE WHEN a.status = $done THEN s.price_tiyin ELSE 0 END), 0)";
        $paidExpr = "COALESCE(SUM(CASE WHEN t.id IS NOT NULL THEN t.amount_tiyin ELSE 0 END), 0)";
        $lastExpr = "MAX(CASE WHEN a.status = $done THEN a.starts_at END)";

        $rows = (new Query())
            ->select([
                'client_id' => 'c.id',
                'sold' => $soldExpr,
                'paid' => $paidExpr,
                'visits' => $visitsExpr,
                'last_visit' => $lastExpr,
            ])
            ->from(['c' => Client::tableName()])
            ->leftJoin(['a' => Appointment::tableName()], 'a.client_id = c.id')
            ->leftJoin(['s' => Service::tableName()], 's.id = a.service_id')
            ->leftJoin(
                ['t' => Transaction::tableName()],
                "t.appointment_id = a.id AND t.type = $deposit AND t.status = $paidStatus"
            )
            ->where(['c.business_id' => $businessId])
            ->groupBy('c.id')
            ->all();

        $now = time();
        $metrics = [];
        foreach ($rows as $r) {
            $clientId = (int) $r['client_id'];
            $lastVisit = $r['last_visit'] ?? null;

            $inactiveDays = self::NEVER_ACTIVE_DAYS;
            if ($lastVisit !== null && $lastVisit !== '') {
                $ts = strtotime((string) $lastVisit . ' UTC');
                if ($ts !== false) {
                    $inactiveDays = (int) floor(($now - $ts) / 86400);
                    if ($inactiveDays < 0) {
                        $inactiveDays = 0;
                    }
                }
            }

            $metrics[$clientId] = [
                'sold' => (int) $r['sold'],
                'paid' => (int) $r['paid'],
                'visits' => (int) $r['visits'],
                'inactive_days' => $inactiveDays,
            ];
        }

        return $metrics;
    }

    /** Resolve the metric value for a rule from a client's aggregate row. */
    private function metricValue(string $metric, array $m): int
    {
        switch ($metric) {
            case AutoCategoryRule::METRIC_SOLD:
                return (int) $m['sold'];
            case AutoCategoryRule::METRIC_PAID:
                return (int) $m['paid'];
            case AutoCategoryRule::METRIC_VISITS:
                return (int) $m['visits'];
            case AutoCategoryRule::METRIC_INACTIVE:
                return (int) $m['inactive_days'];
            default:
                return 0;
        }
    }

    /** Ensure an assignment exists; returns 1 if a new row was created, else 0. */
    private function addAssignment(int $clientId, int $categoryId): int
    {
        $exists = ClientCategoryAssignment::find()
            ->where(['client_id' => $clientId, 'category_id' => $categoryId])
            ->exists();
        if ($exists) {
            return 0;
        }

        $assignment = new ClientCategoryAssignment();
        $assignment->client_id = $clientId;
        $assignment->category_id = $categoryId;

        return $assignment->save() ? 1 : 0;
    }

    /** Delete an assignment if present; returns the number of rows removed (0/1). */
    private function removeAssignment(int $clientId, int $categoryId): int
    {
        return (int) ClientCategoryAssignment::deleteAll([
            'client_id' => $clientId,
            'category_id' => $categoryId,
        ]);
    }
}
