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
