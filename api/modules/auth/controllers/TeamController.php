<?php

namespace api\modules\auth\controllers;

use common\helpers\Phone;
use common\models\Business;
use common\models\BusinessUser;
use common\models\Staff;
use common\models\User;
use common\rest\Controller;
use Yii;
use yii\db\Query;
use yii\web\BadRequestHttpException;
use yii\web\ConflictHttpException;
use yii\web\NotFoundHttpException;

/**
 * Team / roles management for the active business: list members, invite/add a
 * member, change a member's role and staff link, remove a member. The last
 * remaining business_owner can never be demoted or removed, so a business
 * can't be locked out.
 *
 * A member may be linked to one Staff row of the business (`staff_id`); that
 * link powers the staff self-service API (/v1/me/*).
 */
class TeamController extends Controller
{
    private const ROLES = [Business::ROLE_OWNER, Business::ROLE_ADMIN, Business::ROLE_STAFF];

    /**
     * GET v1/team -> [{user_id, name, phone, role, staff_id}] for the active business.
     * Owner/admin only.
     */
    public function actionIndex()
    {
        $this->requireRole(Business::ROLE_OWNER, Business::ROLE_ADMIN);
        $businessId = Yii::$app->tenant->require();

        $rows = BusinessUser::find()
            ->alias('bu')
            ->innerJoinWith('user u', false)
            ->where(['bu.business_id' => $businessId])
            ->orderBy(['bu.id' => SORT_ASC])
            ->select([
                'user_id' => 'bu.user_id',
                'role' => 'bu.role',
                'name' => 'u.name',
                'phone' => 'u.phone',
            ])
            ->asArray()
            ->all();

        // Lowest-id staff row per linked user in this business.
        $links = (new Query())
            ->select(['user_id', 'staff_id' => 'MIN(id)'])
            ->from(Staff::tableName())
            ->where(['business_id' => $businessId])
            ->andWhere(['not', ['user_id' => null]])
            ->groupBy(['user_id'])
            ->all();
        $staffByUser = [];
        foreach ($links as $l) {
            $staffByUser[(int) $l['user_id']] = (int) $l['staff_id'];
        }

        return array_map(static fn (array $r): array => [
            'user_id' => (int) $r['user_id'],
            'name' => (string) $r['name'],
            'phone' => (string) $r['phone'],
            'role' => (string) $r['role'],
            'staff_id' => $staffByUser[(int) $r['user_id']] ?? null,
        ], $rows);
    }

    /**
     * POST v1/team {phone, name?, role, password?, staff_id?} (owner only).
     * Normalizes phone; reuses the User if it exists, else creates it (password
     * required for a new user). Adds a business_user row (409 if already a
     * member) and, when staff_id is given, links that staff row — all in one
     * transaction.
     */
    public function actionCreate()
    {
        $this->requireRole(Business::ROLE_OWNER);
        $businessId = Yii::$app->tenant->require();

        $rawPhone = $this->body('phone', '');
        $phone = is_scalar($rawPhone) ? Phone::normalize((string) $rawPhone) : null;
        if ($phone === null) {
            throw new BadRequestHttpException('Telefon raqam noto\'g\'ri.');
        }

        $rawRole = $this->body('role', '');
        $role = is_string($rawRole) ? $rawRole : '';
        if (!in_array($role, self::ROLES, true)) {
            throw new BadRequestHttpException('Noto\'g\'ri rol.');
        }

        $user = User::findOne(['phone' => $phone]);
        $rawPassword = $this->body('password', '');
        $password = is_scalar($rawPassword) ? (string) $rawPassword : '';
        if ($user === null && $password === '') {
            throw new BadRequestHttpException('Yangi foydalanuvchi uchun parol talab qilinadi.');
        }
        if ($user !== null && BusinessUser::findOne(['business_id' => $businessId, 'user_id' => $user->id]) !== null) {
            throw new ConflictHttpException('Bu foydalanuvchi allaqachon jamoa a\'zosi.');
        }

        // Optional staff link: validate before writing anything.
        $staff = null;
        $body = $this->body();
        if (is_array($body) && array_key_exists('staff_id', $body) && $body['staff_id'] !== null && $body['staff_id'] !== '') {
            $staff = $this->findLinkableStaff($businessId, $body['staff_id']);
            if ($staff === null) {
                return $this->staffNotFound();
            }
            $this->assertStaffFree($staff, $user !== null ? (int) $user->id : null);
        }

        $transaction = Yii::$app->db->beginTransaction();
        try {
            if ($user === null) {
                $user = new User();
                $user->phone = $phone;
                $rawName = $this->body('name', '');
                $user->name = is_scalar($rawName) ? (string) $rawName : '';
                $user->status = User::STATUS_ACTIVE;
                $user->setPassword($password);
                if (!$user->save()) {
                    $transaction->rollBack();
                    return $this->fail422($user);
                }
            }

            $membership = new BusinessUser();
            $membership->business_id = $businessId;
            $membership->user_id = $user->id;
            $membership->role = $role;
            if (!$membership->save()) {
                $transaction->rollBack();
                return $this->fail422($membership);
            }

            if ($staff !== null) {
                $this->linkStaff($businessId, (int) $user->id, $staff);
            }

            $transaction->commit();
        } catch (\Throwable $e) {
            if ($transaction->isActive) {
                $transaction->rollBack();
            }
            throw $e;
        }
        // afterSave busted the key inside the open transaction; bust again after
        // commit so a concurrent request cannot keep a stale "no membership".
        BusinessUser::forgetRole($businessId, (int) $user->id);

        return $this->created([
            'user_id' => (int) $user->id,
            'name' => (string) $user->name,
            'phone' => (string) $user->phone,
            'role' => $role,
            'staff_id' => $staff !== null ? (int) $staff->id : null,
        ]);
    }

    /**
     * PATCH v1/team/<userId> {role?, staff_id?} (owner only). At least one key.
     * `staff_id: null` unlinks; an id links that staff row (clearing any other
     * staff row of this business linked to the member). Refuses to demote the
     * last remaining business_owner.
     */
    public function actionUpdate(int $userId)
    {
        $this->requireRole(Business::ROLE_OWNER);
        $businessId = Yii::$app->tenant->require();

        $body = $this->body();
        $body = is_array($body) ? $body : [];
        $hasRole = array_key_exists('role', $body);
        $hasStaff = array_key_exists('staff_id', $body);
        if (!$hasRole && !$hasStaff) {
            throw new BadRequestHttpException('role yoki staff_id talab qilinadi.');
        }

        $role = null;
        if ($hasRole) {
            $rawRole = $body['role'];
            if (!is_string($rawRole) || !in_array($rawRole, self::ROLES, true)) {
                throw new BadRequestHttpException('Noto\'g\'ri rol.');
            }
            $role = $rawRole;
        }

        $membership = BusinessUser::findOne(['business_id' => $businessId, 'user_id' => $userId]);
        if ($membership === null) {
            throw new NotFoundHttpException('Jamoa a\'zosi topilmadi.');
        }

        // Guard: never demote the last remaining owner.
        if ($role !== null
            && $membership->role === Business::ROLE_OWNER
            && $role !== Business::ROLE_OWNER
            && $this->ownerCount($businessId) <= 1) {
            Yii::$app->response->statusCode = 422;
            return [['field' => 'role', 'message' => 'Oxirgi egani rolini o\'zgartirib bo\'lmaydi.']];
        }

        $staff = null;
        $unlink = false;
        if ($hasStaff) {
            if ($body['staff_id'] === null || $body['staff_id'] === '') {
                $unlink = true;
            } else {
                $staff = $this->findLinkableStaff($businessId, $body['staff_id']);
                if ($staff === null) {
                    return $this->staffNotFound();
                }
                $this->assertStaffFree($staff, $userId);
            }
        }

        $transaction = Yii::$app->db->beginTransaction();
        try {
            if ($role !== null && $role !== $membership->role) {
                $membership->role = $role;
                if (!$membership->save()) {
                    $transaction->rollBack();
                    return $this->fail422($membership);
                }
            }
            if ($unlink) {
                Staff::updateAll(['user_id' => null, 'updated_at' => time()], ['business_id' => $businessId, 'user_id' => $userId]);
            } elseif ($staff !== null) {
                $this->linkStaff($businessId, $userId, $staff);
            }
            $transaction->commit();
        } catch (\Throwable $e) {
            if ($transaction->isActive) {
                $transaction->rollBack();
            }
            throw $e;
        }
        // afterSave busted the key before commit; a concurrent request may have
        // re-cached the old (higher) role from the still-committed row since.
        BusinessUser::forgetRole($businessId, $userId);

        return [
            'user_id' => (int) $membership->user_id,
            'role' => (string) $membership->role,
            'staff_id' => $this->linkedStaffId($businessId, $userId),
        ];
    }

    /**
     * DELETE v1/team/<userId> (owner only). Removes the membership and unlinks
     * the member's staff rows. Refuses to remove the last remaining business_owner.
     */
    public function actionDelete(int $userId)
    {
        $this->requireRole(Business::ROLE_OWNER);
        $businessId = Yii::$app->tenant->require();

        $membership = BusinessUser::findOne(['business_id' => $businessId, 'user_id' => $userId]);
        if ($membership === null) {
            throw new NotFoundHttpException('Jamoa a\'zosi topilmadi.');
        }

        // Guard: never remove the last remaining owner.
        if ($membership->role === Business::ROLE_OWNER && $this->ownerCount($businessId) <= 1) {
            Yii::$app->response->statusCode = 422;
            return [['field' => 'user_id', 'message' => 'Oxirgi egani jamoadan chiqarib bo\'lmaydi.']];
        }

        $transaction = Yii::$app->db->beginTransaction();
        try {
            $membership->delete(); // afterDelete busts the cached role
            Staff::updateAll(['user_id' => null, 'updated_at' => time()], ['business_id' => $businessId, 'user_id' => $userId]);
            $transaction->commit();
        } catch (\Throwable $e) {
            if ($transaction->isActive) {
                $transaction->rollBack();
            }
            throw $e;
        }
        // Bust again after commit so a concurrent request cannot re-cache the old role.
        BusinessUser::forgetRole($businessId, $userId);

        Yii::$app->response->statusCode = 204;
        return null;
    }

    /** Number of business_owner memberships in the given business. */
    private function ownerCount(int $businessId): int
    {
        return (int) BusinessUser::find()
            ->where(['business_id' => $businessId, 'role' => Business::ROLE_OWNER])
            ->count();
    }

    /** Staff row of this business by a raw id from the body, or null. */
    private function findLinkableStaff(int $businessId, $rawId): ?Staff
    {
        if (!(is_int($rawId) || (is_string($rawId) && ctype_digit($rawId))) || (int) $rawId <= 0) {
            return null;
        }
        return Staff::find()
            ->andWhere([Staff::tableName() . '.id' => (int) $rawId, Staff::tableName() . '.business_id' => $businessId])
            ->one();
    }

    /** 409 when the staff row is already linked to a different account. */
    private function assertStaffFree(Staff $staff, ?int $userId): void
    {
        if ($staff->user_id !== null && ($userId === null || (int) $staff->user_id !== $userId)) {
            throw new ConflictHttpException('Bu xodim boshqa hisobga bog\'langan.');
        }
    }

    /** Link $staff to $userId, clearing any other staff row of the business linked to the same user. */
    private function linkStaff(int $businessId, int $userId, Staff $staff): void
    {
        Staff::updateAll(
            ['user_id' => null, 'updated_at' => time()],
            ['and', ['business_id' => $businessId, 'user_id' => $userId], ['<>', 'id', (int) $staff->id]]
        );
        if ((int) $staff->user_id !== $userId) {
            $staff->user_id = $userId;
            // Membership and uniqueness were checked above; skip the model rule.
            $staff->save(false, ['user_id', 'updated_at']);
        }
    }

    /** Lowest-id staff row of this business linked to $userId, or null. */
    private function linkedStaffId(int $businessId, int $userId): ?int
    {
        $id = (new Query())
            ->select(['MIN(id)'])
            ->from(Staff::tableName())
            ->where(['business_id' => $businessId, 'user_id' => $userId])
            ->scalar();
        return $id !== false && $id !== null ? (int) $id : null;
    }

    /** 422 with pointer staff_id. */
    private function staffNotFound(): array
    {
        Yii::$app->response->statusCode = 422;
        return [['field' => 'staff_id', 'message' => 'Xodim topilmadi.']];
    }
}
