<?php

namespace console\controllers;

use common\helpers\Phone;
use common\models\Business;
use common\models\BusinessUser;
use common\models\Staff;
use common\models\User;
use Yii;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\helpers\Console;

/**
 * Demo staff logins for the TizBiz Biznes staff shell (docs/mobile/BACKEND-PLAN.md §6.1).
 *
 *   php yii seed-staff
 *
 * For each demo business (prod slug first, then the local alias) it links the
 * first N active staff rows to login accounts (password `secret123`), adding a
 * `staff` membership. Idempotent: re-running changes nothing that is already
 * linked; a staff row linked to a different user is left alone with a warning.
 */
class SeedStaffController extends Controller
{
    private const PASSWORD = 'secret123';

    /** slug aliases (prod, local) => login phones; phone i links staff row i. */
    private const PLAN = [
        [['shox-barber', 'barber'], ['+998931110001', '+998931110002']],
        [['aziza-tortlari', 'tort'], ['+998932220001']],
        [['sanatrix', 'klinika'], ['+998933330001', '+998933330002']],
        [['serenada', 'ijara'], ['+998934440001']],
    ];

    public $defaultAction = 'index';

    public function actionIndex(): int
    {
        $table = [];
        $failed = false;

        foreach (self::PLAN as [$slugs, $phones]) {
            $business = Business::find()->where(['slug' => $slugs])->orderBy(['id' => SORT_ASC])->all();
            $business = $this->pickBySlugOrder($business, $slugs);
            if ($business === null) {
                $this->stdout('skip: no business ' . implode('|', $slugs) . "\n", Console::FG_YELLOW);
                continue;
            }

            $tx = Yii::$app->db->beginTransaction();
            try {
                $rows = $this->seedBusiness($business, $phones);
                $tx->commit();
                $table = array_merge($table, $rows);
            } catch (\Throwable $e) {
                $tx->rollBack();
                $failed = true;
                $this->stderr("error: {$business->slug}: {$e->getMessage()}\n", Console::FG_RED);
            }
        }

        $this->printTable($table);
        return $failed ? ExitCode::UNSPECIFIED_ERROR : ExitCode::OK;
    }

    /**
     * @param string[] $phones
     * @return array<int, array<string, string>>
     */
    private function seedBusiness(Business $business, array $phones): array
    {
        $bid = (int) $business->id;
        $need = count($phones);

        $staffRows = Staff::find()
            ->andWhere(['business_id' => $bid, 'is_active' => 1])
            ->orderBy(['id' => SORT_ASC])
            ->limit($need)
            ->all();

        // Fill up to N with demo rows so every planned login has a staff profile.
        for ($i = count($staffRows); $i < $need; $i++) {
            $staff = new Staff([
                'business_id' => $bid,
                'name' => $i === 0 ? 'Demo xodim' : 'Demo xodim ' . ($i + 1),
                'specialization' => 'Xodim',
                'is_active' => true,
            ]);
            if (!$staff->save()) {
                throw new \RuntimeException('staff: ' . json_encode($staff->getFirstErrors(), JSON_UNESCAPED_UNICODE));
            }
            $this->stdout("  {$business->slug}: created staff #{$staff->id} {$staff->name}\n");
            $staffRows[] = $staff;
        }

        $out = [];
        foreach ($phones as $i => $rawPhone) {
            $staff = $staffRows[$i];
            $phone = Phone::normalize($rawPhone) ?? $rawPhone;

            $user = User::findOne(['phone' => $phone]) ?? new User();
            $user->phone = $phone;
            $user->name = (string) $staff->name;
            $user->status = User::STATUS_ACTIVE;
            $user->setPassword(self::PASSWORD);
            if (!$user->save()) {
                throw new \RuntimeException("user {$phone}: " . json_encode($user->getFirstErrors(), JSON_UNESCAPED_UNICODE));
            }
            $uid = (int) $user->id;

            $membership = BusinessUser::findOne(['business_id' => $bid, 'user_id' => $uid]);
            if ($membership === null) {
                $membership = new BusinessUser([
                    'business_id' => $bid,
                    'user_id' => $uid,
                    'role' => Business::ROLE_STAFF,
                ]);
                if (!$membership->save()) {
                    throw new \RuntimeException("membership {$phone}: " . json_encode($membership->getFirstErrors(), JSON_UNESCAPED_UNICODE));
                }
            }

            $status = $this->link($business, $staff, $uid, $phone);

            $out[] = [
                'business' => (string) $business->slug,
                'staff_id' => (string) $staff->id,
                'staff' => (string) $staff->name,
                'phone' => $phone,
                'role' => (string) $membership->role,
                'link' => $status,
            ];
        }
        return $out;
    }

    /** Link $staff to $uid unless either side is already linked elsewhere. */
    private function link(Business $business, Staff $staff, int $uid, string $phone): string
    {
        if ($staff->user_id !== null && (int) $staff->user_id === $uid) {
            return 'linked (kept)';
        }
        if ($staff->user_id !== null) {
            $this->stdout("  warning: {$business->slug} staff #{$staff->id} is linked to user #{$staff->user_id}; {$phone} not linked\n", Console::FG_YELLOW);
            return 'skip: staff linked to another user';
        }
        $other = Staff::find()
            ->andWhere(['business_id' => (int) $business->id, 'user_id' => $uid])
            ->one();
        if ($other !== null) {
            $this->stdout("  warning: {$phone} is already linked to {$business->slug} staff #{$other->id}; staff #{$staff->id} left unlinked\n", Console::FG_YELLOW);
            return "skip: user linked to staff #{$other->id}";
        }

        $staff->user_id = $uid;
        if (!$staff->save(true, ['user_id', 'updated_at'])) {
            throw new \RuntimeException("link {$phone}: " . json_encode($staff->getFirstErrors(), JSON_UNESCAPED_UNICODE));
        }
        return 'linked';
    }

    /**
     * @param Business[] $found
     * @param string[] $slugs in preference order
     */
    private function pickBySlugOrder(array $found, array $slugs): ?Business
    {
        foreach ($slugs as $slug) {
            foreach ($found as $b) {
                if ($b->slug === $slug) {
                    return $b;
                }
            }
        }
        return null;
    }

    /** @param array<int, array<string, string>> $rows */
    private function printTable(array $rows): void
    {
        if ($rows === []) {
            $this->stdout("Nothing seeded.\n");
            return;
        }
        $cols = array_keys($rows[0]);
        $w = [];
        foreach ($cols as $c) {
            $w[$c] = mb_strlen($c);
            foreach ($rows as $r) {
                $w[$c] = max($w[$c], mb_strlen($r[$c]));
            }
        }
        $line = static function (array $cells) use ($cols, $w): string {
            $parts = [];
            foreach ($cols as $c) {
                $v = $cells[$c];
                $parts[] = $v . str_repeat(' ', $w[$c] - mb_strlen($v));
            }
            return implode('  ', $parts) . "\n";
        };
        $this->stdout("\n" . $line(array_combine($cols, $cols)));
        foreach ($rows as $r) {
            $this->stdout($line($r));
        }
        $this->stdout("\nPassword for every staff login: " . self::PASSWORD . "\n", Console::FG_GREEN);
    }
}
