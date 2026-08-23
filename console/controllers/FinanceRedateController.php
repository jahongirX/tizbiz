<?php

namespace console\controllers;

use common\models\Appointment;
use common\models\Business;
use common\models\Transaction;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\helpers\Console;

/**
 * Re-dates in-shop sale rows to the visit they belong to.
 *
 * Rows written by a backfill (or a seeded demo) carry the day the script ran,
 * so every month of income lands on one date and the finance range filter stops
 * meaning anything. New sales are dated correctly at write time; this is for the
 * ones already stored.
 *
 * Usage: php yii finance-redate/run [slug]
 */
class FinanceRedateController extends Controller
{
    public function actionRun(?string $slug = null): int
    {
        $query = Transaction::find()->where(['type' => Transaction::TYPE_SALE]);

        if ($slug !== null) {
            $business = Business::findOne(['slug' => $slug]);
            if ($business === null) {
                $this->stderr("Business '{$slug}' not found.\n", Console::FG_RED);
                return ExitCode::UNSPECIFIED_ERROR;
            }
            $query->andWhere(['business_id' => $business->id]);
        }

        $moved = 0;
        foreach ($query->each(200) as $tx) {
            $appt = $tx->appointment_id ? Appointment::findOne((int) $tx->appointment_id) : null;
            if ($appt === null) {
                continue;
            }
            $earnedAt = strtotime((string) $appt->ends_at . ' UTC');
            if ($earnedAt === false || $earnedAt <= 0 || (int) $tx->created_at === $earnedAt) {
                continue;
            }
            $tx->updateAttributes(['created_at' => $earnedAt]);
            $moved++;
        }

        $this->stdout(sprintf("Re-dated %d sale row(s) to their visit.\n", $moved));
        return ExitCode::OK;
    }
}
