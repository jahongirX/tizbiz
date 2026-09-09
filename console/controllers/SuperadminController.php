<?php

namespace console\controllers;

use api\modules\sms\services\SmsDispatcher;
use common\helpers\Phone;
use common\models\SmsSale;
use common\models\User;
use Yii;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\helpers\Console;

/**
 * Bootstrap platform superadmins (there is no self-service for this role).
 *   php yii superadmin/grant  +998901234567
 *   php yii superadmin/revoke +998901234567
 *   php yii superadmin/list
 */
class SuperadminController extends Controller
{
    /**
     * Create (or update) a user and make them a superadmin in one step:
     *   php yii superadmin/create +998901234567 secretpass "Full Name"
     */
    public function actionCreate(string $phone, string $password, string $name = 'Superadmin'): int
    {
        $normalized = Phone::normalize($phone) ?? $phone;
        $user = User::findOne(['phone' => $normalized]) ?? new User();
        $user->phone = $normalized;
        $user->name = $name;
        $user->status = User::STATUS_ACTIVE;
        $user->is_superadmin = true;
        $user->setPassword($password);
        if (!$user->save()) {
            $this->stderr('Failed: ' . json_encode($user->getErrors()) . "\n", Console::FG_RED);
            return ExitCode::UNSPECIFIED_ERROR;
        }
        $this->stdout(sprintf("Superadmin ready: %s (id=%d)\n", $normalized, (int) $user->id), Console::FG_GREEN);
        return ExitCode::OK;
    }

    /**
     * Contract (sale) expiry reminders — run daily from cron:
     *   php yii superadmin/contract-reminders
     *
     * For every contract that has just crossed a 30/15/5/1-day-before-expiry
     * threshold (or has expired), it advances the reminder stage and — if an
     * admin notify channel is configured (params sms.admin.notify_user_id +
     * sms.admin.notify_phone) — texts the superadmin so they can renew/collect.
     * The dashboard shows the same list regardless, so this is a push on top.
     */
    public function actionContractReminders(): int
    {
        $notifyUserId = (int) (Yii::$app->params['sms.admin.notify_user_id'] ?? 0);
        $notifyPhone = trim((string) (Yii::$app->params['sms.admin.notify_phone'] ?? ''));
        $canPush = $notifyUserId > 0 && $notifyPhone !== '';

        $contracts = SmsSale::find()
            ->where(['not', ['ends_at' => null]])
            ->andWhere(['<=', 'ends_at', time() + 30 * 86400])
            ->all();

        $fired = 0;
        foreach ($contracts as $c) {
            $stage = $c->pendingStage();
            if ($stage === null) {
                continue;
            }
            $days = $c->daysLeft();
            $who = ($c->name ?: 'Mijoz') . ' (' . ($c->phone ?: '—') . ')';
            $when = date('d.m.Y', (int) $c->ends_at);
            $text = $stage === 0
                ? "TizBiz: {$who} — " . ucfirst((string) $c->tariff) . " shartnomasi TUGADI ({$when}). Yangilash kerak."
                : "TizBiz: {$who} — " . ucfirst((string) $c->tariff) . " shartnomasi {$days} kundan keyin tugaydi ({$when}). Uzaytirishni unutmang.";

            $pushed = true;
            if ($canPush) {
                try {
                    SmsDispatcher::send($notifyUserId, [$notifyPhone], $text);
                } catch (\Throwable $e) {
                    $pushed = false;
                    $this->stderr("  SMS xato ({$who}): {$e->getMessage()}\n", Console::FG_RED);
                }
            }
            $this->stdout(($canPush && $pushed ? '  ✓ ' : '  · ') . $text . "\n", $stage <= 5 ? Console::FG_RED : Console::FG_YELLOW);

            // Advance the stage only once the push (if any) succeeded, so a failed
            // SMS is retried on the next daily run instead of being lost.
            if ($pushed) {
                $c->reminder_stage = $stage;
                $c->last_reminded_at = time();
                $c->save(false, ['reminder_stage', 'last_reminded_at']);
                $fired++;
            }
        }

        $this->stdout(sprintf(
            "Shartnoma eslatmalari: %d ta ogohlantirish%s.\n",
            $fired,
            $canPush ? '' : ' (SMS kanali sozlanmagan — faqat dashboardda)'
        ), Console::FG_GREEN);
        return ExitCode::OK;
    }

    public function actionGrant(string $phone): int
    {
        return $this->setFlag($phone, true);
    }

    public function actionRevoke(string $phone): int
    {
        return $this->setFlag($phone, false);
    }

    public function actionList(): int
    {
        $admins = User::find()->where(['is_superadmin' => true])->all();
        if ($admins === []) {
            $this->stdout("No superadmins.\n", Console::FG_YELLOW);
            return ExitCode::OK;
        }
        foreach ($admins as $u) {
            $this->stdout(sprintf("  %s  %s\n", $u->phone, $u->name));
        }
        return ExitCode::OK;
    }

    private function setFlag(string $phone, bool $value): int
    {
        $normalized = Phone::normalize($phone) ?? $phone;
        $user = User::findOne(['phone' => $normalized]);
        if ($user === null) {
            $this->stderr("User not found: $normalized\n", Console::FG_RED);
            return ExitCode::DATAERR;
        }
        $user->is_superadmin = $value;
        $user->save(false, ['is_superadmin']);
        $this->stdout(
            sprintf("%s is %s superadmin.\n", $normalized, $value ? 'now' : 'no longer'),
            Console::FG_GREEN
        );
        return ExitCode::OK;
    }
}
