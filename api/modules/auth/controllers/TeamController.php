<?php

namespace api\modules\auth\controllers;

use common\helpers\Phone;
use common\models\Business;
use common\models\BusinessUser;
use common\models\User;
use common\rest\Controller;
use Yii;
use yii\web\BadRequestHttpException;
use yii\web\ConflictHttpException;
use yii\web\NotFoundHttpException;

/**
 * Team / roles management for the active business: list members, invite/add a
 * member, change a member's role, remove a member. The last remaining
 * business_owner can never be demoted or removed, so a business can't be locked out.
 */
class TeamController extends Controller
{
    /**
     * GET v1/team -> [{user_id, name, phone, role}] for the active business.
     * Any authenticated member may read.
     */
    public function actionIndex()
    {
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

        return array_map(static fn (array $r): array => [
            'user_id' => (int) $r['user_id'],
            'name' => (string) $r['name'],
            'phone' => (string) $r['phone'],
            'role' => (string) $r['role'],
        ], $rows);
    }

    /**
     * POST v1/team {phone, name?, role, password?} (owner only).
     * Normalizes phone; reuses the User if it exists, else creates it (password
     * required for a new user). Adds a business_user row (409 if already a member).
     */
    public function actionCreate()
    {
        $this->requireRole(Business::ROLE_OWNER);
        $businessId = Yii::$app->tenant->require();

        $phone = Phone::normalize((string) $this->body('phone', ''));
        if ($phone === null) {
            throw new BadRequestHttpException('Telefon raqam noto\'g\'ri.');
        }

        $role = (string) $this->body('role', '');
        if (!in_array($role, [Business::ROLE_OWNER, Business::ROLE_ADMIN, Business::ROLE_STAFF], true)) {
            throw new BadRequestHttpException('Noto\'g\'ri rol.');
        }

        $transaction = Yii::$app->db->beginTransaction();
        try {
            $user = User::findOne(['phone' => $phone]);
            if ($user === null) {
                $password = (string) $this->body('password', '');
                if ($password === '') {
                    $transaction->rollBack();
                    throw new BadRequestHttpException('Yangi foydalanuvchi uchun parol talab qilinadi.');
                }
                $user = new User();
                $user->phone = $phone;
                $user->name = (string) $this->body('name', '');
                $user->status = User::STATUS_ACTIVE;
                $user->setPassword($password);
                if (!$user->save()) {
                    $transaction->rollBack();
                    return $this->fail422($user);
                }
            }

            if (BusinessUser::findOne(['business_id' => $businessId, 'user_id' => $user->id]) !== null) {
                $transaction->rollBack();
                throw new ConflictHttpException('Bu foydalanuvchi allaqachon jamoa a\'zosi.');
            }

            $membership = new BusinessUser();
            $membership->business_id = $businessId;
            $membership->user_id = $user->id;
            $membership->role = $role;
            if (!$membership->save()) {
                $transaction->rollBack();
                return $this->fail422($membership);
            }

            $transaction->commit();
        } catch (BadRequestHttpException | ConflictHttpException $e) {
            throw $e;
        } catch (\Throwable $e) {
            $transaction->rollBack();
            throw $e;
        }

        return $this->created([
            'user_id' => (int) $user->id,
            'name' => (string) $user->name,
            'phone' => (string) $user->phone,
            'role' => $role,
        ]);
    }

    /**
     * PATCH v1/team/<userId> {role} (owner only). Changes the member's role.
     * Refuses to demote the last remaining business_owner.
     */
    public function actionUpdate(int $userId)
    {
        $this->requireRole(Business::ROLE_OWNER);
        $businessId = Yii::$app->tenant->require();

        $role = (string) $this->body('role', '');
        if (!in_array($role, [Business::ROLE_OWNER, Business::ROLE_ADMIN, Business::ROLE_STAFF], true)) {
            throw new BadRequestHttpException('Noto\'g\'ri rol.');
        }

        $membership = BusinessUser::findOne(['business_id' => $businessId, 'user_id' => $userId]);
        if ($membership === null) {
            throw new NotFoundHttpException('Jamoa a\'zosi topilmadi.');
        }

        // Guard: never demote the last remaining owner.
        if ($membership->role === Business::ROLE_OWNER
            && $role !== Business::ROLE_OWNER
            && $this->ownerCount($businessId) <= 1) {
            Yii::$app->response->statusCode = 422;
            return [['field' => 'role', 'message' => 'Oxirgi egani rolini o\'zgartirib bo\'lmaydi.']];
        }

        $membership->role = $role;
        if (!$membership->save()) {
            return $this->fail422($membership);
        }

        return [
            'user_id' => (int) $membership->user_id,
            'role' => (string) $membership->role,
        ];
    }

    /**
     * DELETE v1/team/<userId> (owner only). Removes the membership.
     * Refuses to remove the last remaining business_owner.
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

        $membership->delete();

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
}
