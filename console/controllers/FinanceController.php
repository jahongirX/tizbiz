<?php

namespace console\controllers;

use api\modules\finance\services\SaleService;
use common\models\Appointment;
use common\models\Business;
use common\models\Transaction;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\helpers\Console;

/**
 * Finance housekeeping.
 *
 * Usage: php yii finance/backfill-sales [slug]   (omit slug for every business)
 *
 * Appointments completed before in-shop sales were recorded have no ledger row,
 * so Moliya under-reports their day. This writes the missing ones; the sale
 * service is idempotent, so running it twice changes nothing.
 */
class FinanceController extends Controller
{
    public function actionBackfillSales(?string $slug = null): int
    {
        $query = Appointment::find()->where(['status' => Appointment::STATUS_COMPLETED]);

        if ($slug !== null) {
            $business = Business::findOne(['slug' => $slug]);
            if ($business === null) {
                $this->stderr("Business '{$slug}' not found.\n", Console::FG_RED);
                return ExitCode::UNSPECIFIED_ERROR;
            }
            $query->andWhere(['business_id' => $business->id]);
        }

        $written = 0;
        $skipped = 0;
        foreach ($query->each(200) as $appt) {
            $key = 'sale:appointment:' . $appt->id;
            if (Transaction::find()->where(['idempotency_key' => $key])->exists()) {
                $skipped++;
                continue;
            }
            SaleService::record($appt) !== null ? $written++ : $skipped++;
        }

        $this->stdout(sprintf("Sales ledger: %d written, %d already present or not billable.\n", $written, $skipped));
        return ExitCode::OK;
    }
}
