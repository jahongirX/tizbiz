<?php

namespace console\controllers;

use api\modules\notify\services\NotificationService;
use common\models\Appointment;
use common\models\Business;
use common\models\Notification;
use common\models\TelegramLink;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\helpers\Console;

/**
 * Sends appointment reminders. Meant to run from cron, e.g. every 15 minutes:
 *
 *   * /15 * * * *  php /path/yii reminder/send 24
 *
 * Finds appointments starting within the next N hours (default 24) whose status
 * is pending/confirmed and which do NOT already have a 'reminder' notification,
 * then queues + dispatches one reminder per appointment (Telegram if the client
 * has a verified link, otherwise SMS).
 *
 * Runs without a tenant context, so appointments across all businesses are
 * scanned (base AR applies no tenant scope when no tenant is active).
 */
class ReminderController extends Controller
{
    /**
     * @param int $hoursAhead look-ahead window in hours.
     */
    public function actionSend(int $hoursAhead = 24): int
    {
        if ($hoursAhead < 1) {
            $this->stderr("hoursAhead must be >= 1\n", Console::FG_RED);
            return ExitCode::USAGE;
        }

        $now = new \DateTime('now', new \DateTimeZone('UTC'));
        $cutoff = (clone $now)->modify("+{$hoursAhead} hours");
        $nowStr = $now->format('Y-m-d H:i:s');
        $cutoffStr = $cutoff->format('Y-m-d H:i:s');

        $appointments = Appointment::find()
            ->where(['status' => ['pending', 'confirmed']])
            ->andWhere(['>=', 'starts_at', $nowStr])
            ->andWhere(['<=', 'starts_at', $cutoffStr])
            ->orderBy(['starts_at' => SORT_ASC])
            ->all();

        $alreadyReminded = $this->remindedAppointmentIds($now->getTimestamp(), $hoursAhead);

        $sent = 0;
        $failed = 0;
        $skipped = 0;

        foreach ($appointments as $appt) {
            $apptId = (int) $appt->id;

            if (isset($alreadyReminded[$apptId])) {
                $skipped++;
                continue;
            }
            $clientId = $appt->client_id !== null ? (int) $appt->client_id : null;
            if ($clientId === null) {
                // No client to notify (e.g. walk-in placeholder).
                $skipped++;
                continue;
            }

            $channel = $this->hasVerifiedTelegram($clientId)
                ? Notification::CHANNEL_TELEGRAM
                : Notification::CHANNEL_SMS;

            $tz = $this->businessTimezone((int) $appt->business_id);

            $payload = [
                'appointment_id' => $apptId,
                'starts_at' => (string) $appt->starts_at,
                'starts_at_local' => $this->toLocal((string) $appt->starts_at, $tz),
            ];

            $n = NotificationService::queue((int) $appt->business_id, $clientId, $channel, 'reminder', $payload);
            if ($n->getIsNewRecord()) {
                // queue() failed to persist.
                $failed++;
                continue;
            }

            if (NotificationService::dispatch($n)) {
                $sent++;
            } else {
                $failed++;
            }
        }

        $this->stdout(sprintf(
            "Reminders: %d sent, %d failed, %d skipped (%d candidates in next %dh).\n",
            $sent,
            $failed,
            $skipped,
            count($appointments),
            $hoursAhead
        ), Console::FG_GREEN);

        return ExitCode::OK;
    }

    /**
     * Set of appointment ids that already have a 'reminder' notification. Bounded
     * by created_at so the scan stays cheap: a reminder for an appointment within
     * the window was queued no earlier than one window-length ago (plus a day of
     * slack).
     *
     * @return array<int, true>
     */
    private function remindedAppointmentIds(int $nowTs, int $hoursAhead): array
    {
        $since = $nowTs - ($hoursAhead * 3600) - 86400;

        $rows = Notification::find()
            ->select(['payload'])
            ->where(['template' => 'reminder'])
            ->andWhere(['status' => Notification::STATUS_SENT])
            ->andWhere(['>=', 'created_at', $since])
            ->asArray()
            ->all();

        $ids = [];
        foreach ($rows as $row) {
            $payload = $row['payload'] ?? null;
            if (is_string($payload)) {
                $payload = json_decode($payload, true);
            }
            if (is_array($payload) && isset($payload['appointment_id'])) {
                $ids[(int) $payload['appointment_id']] = true;
            }
        }
        return $ids;
    }

    private function hasVerifiedTelegram(int $clientId): bool
    {
        return TelegramLink::find()
            ->where(['client_id' => $clientId])
            ->andWhere(['not', ['verified_at' => null]])
            ->exists();
    }

    /**
     * Resolve a business's display timezone, falling back to Asia/Tashkent when
     * unset or the business row is missing.
     */
    private function businessTimezone(int $businessId): string
    {
        $business = Business::findOne($businessId);
        $tz = $business !== null ? (string) $business->timezone : '';
        return $tz !== '' ? $tz : 'Asia/Tashkent';
    }

    /** Format a UTC datetime string in the given display timezone. */
    private function toLocal(string $utc, string $timezone = 'Asia/Tashkent'): string
    {
        try {
            $dt = new \DateTime($utc, new \DateTimeZone('UTC'));
            $dt->setTimezone(new \DateTimeZone($timezone));
            return $dt->format('Y-m-d H:i');
        } catch (\Throwable $e) {
            return $utc;
        }
    }
}
