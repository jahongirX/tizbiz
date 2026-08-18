<?php

namespace console\controllers;

use common\helpers\Phone;
use common\models\User;
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
