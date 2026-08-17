<?php

namespace console\controllers;

use common\models\Appointment;
use yii\base\Event;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\helpers\Console;

/**
 * Housekeeping for appointments. Meant to run from cron every few minutes:
 *
 *   * /5 * * * *  php /path/yii appointment/auto-complete
 *
 * A client who is already in the chair (status "arrived") is finished when the
 * service time is up — nobody goes back to the computer to press a button. Only
 * "arrived" is swept: a booking still marked pending/confirmed means the shop
 * never registered the client, so completing it would invent revenue.
 *
 * Runs without a tenant context, so every business is covered (the base AR
 * applies no tenant scope when no tenant is active).
 */
class AppointmentController extends Controller
{
    /**
     * @param int $graceMin minutes to wait past the end time before finishing,
     *                      so a master who runs a few minutes over is not cut off.
     */
    public function actionAutoComplete(int $graceMin = 0): int
    {
        if ($graceMin < 0) {
            $this->stderr("graceMin must be >= 0\n", Console::FG_RED);
            return ExitCode::USAGE;
        }

        $cutoff = (new \DateTime('now', new \DateTimeZone('UTC')))
            ->modify("-{$graceMin} minutes")
            ->format('Y-m-d H:i:s');

        $due = Appointment::find()
            ->where(['status' => Appointment::STATUS_ARRIVED])
            ->andWhere(['<=', 'ends_at', $cutoff])
            ->all();

        $done = 0;
        foreach ($due as $appt) {
            $appt->status = Appointment::STATUS_COMPLETED;
            if (!$appt->save()) {
                $this->stderr(sprintf(
                    "  #%d skipped: %s\n",
                    $appt->id,
                    json_encode($appt->getErrors(), JSON_UNESCAPED_UNICODE)
                ), Console::FG_YELLOW);
                continue;
            }
            // Same event the API fires, so cashback is awarded either way.
            \Yii::$app->trigger('appointmentCompleted', new Event(['sender' => $appt]));
            $done++;
        }

        $this->stdout(sprintf("Auto-completed %d of %d due appointment(s).\n", $done, count($due)));

        return ExitCode::OK;
    }
}
