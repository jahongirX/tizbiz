<?php

namespace console\controllers;

use api\modules\loyalty\services\AutoCategoryService;
use common\models\Business;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\helpers\Console;

/**
 * Loyalty maintenance jobs. Meant to run from cron.
 *
 * Runs without a tenant context, so every business is processed explicitly
 * (base AR applies no tenant scope when no tenant is active).
 */
class LoyaltyController extends Controller
{
    /**
     * Apply active auto-category rules for every business.
     *
     *   0 3 * * *  php /path/yii loyalty/apply-categories
     */
    /**
     * Award cashback for visits completed before the rule existed (or before the
     * handler was wired). Idempotent: LoyaltyService keys each earn by
     * appointment, so a second run adds nothing.
     *
     * Usage: php yii loyalty/backfill [slug]
     */
    public function actionBackfill(?string $slug = null): int
    {
        $query = \common\models\Appointment::find()
            ->where(['status' => \common\models\Appointment::STATUS_COMPLETED])
            ->andWhere(['not', ['client_id' => null]]);

        if ($slug !== null) {
            $business = \common\models\Business::findOne(['slug' => $slug]);
            if ($business === null) {
                $this->stderr("Business '{$slug}' not found.\n");
                return \yii\console\ExitCode::UNSPECIFIED_ERROR;
            }
            $query->andWhere(['business_id' => $business->id]);
        }

        $done = 0;
        foreach ($query->each(200) as $appt) {
            \api\modules\loyalty\services\LoyaltyService::onAppointmentCompleted(
                new \yii\base\Event(['sender' => $appt])
            );
            $done++;
        }

        $this->stdout(sprintf("Cashback replayed for %d completed visit(s).\n", $done));
        return \yii\console\ExitCode::OK;
    }

    public function actionApplyCategories(): int
    {
        $service = new AutoCategoryService();
        $businesses = Business::find()->all();

        $totalAdded = 0;
        $totalRemoved = 0;

        foreach ($businesses as $business) {
            try {
                $result = $service->apply((int) $business->id);
                $totalAdded += $result['added'];
                $totalRemoved += $result['removed'];
            } catch (\Throwable $e) {
                $this->stderr(sprintf(
                    "Business #%d failed: %s\n",
                    (int) $business->id,
                    $e->getMessage()
                ), Console::FG_RED);
            }
        }

        $this->stdout(sprintf(
            "Auto-categories applied across %d businesses: %d added, %d removed.\n",
            count($businesses),
            $totalAdded,
            $totalRemoved
        ), Console::FG_GREEN);

        return ExitCode::OK;
    }
}
