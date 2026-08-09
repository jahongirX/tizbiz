<?php

namespace api\modules\auth\controllers;

use common\components\Jwt;
use common\models\Business;
use common\models\BusinessUser;
use common\models\User;
use common\rest\Controller;
use Yii;
use yii\web\ConflictHttpException;
use yii\web\ForbiddenHttpException;
use yii\web\ServerErrorHttpException;
use yii\web\UnauthorizedHttpException;

/**
 * Accounts, tenants and sessions: login, register, me, switch tenant.
 */
class AuthController extends Controller
{
    protected function authOptional(): array
    {
        return ['login', 'register'];
    }

    /**
     * POST v1/auth/login {phone, password}
     */
    public function actionLogin()
    {
        $phone = \common\helpers\Phone::normalize((string) $this->body('phone', ''));
        $password = (string) $this->body('password', '');

        $user = $phone !== null ? User::findOne(['phone' => $phone, 'status' => User::STATUS_ACTIVE]) : null;
        if ($user === null || $password === '' || !$user->validatePassword($password)) {
            throw new UnauthorizedHttpException('Telefon yoki parol noto\'g\'ri.');
        }

        $memberships = $this->memberships($user->id);

        // Pick the first membership whose business is active; skip inactive ones.
        $active = null;
        if ($memberships !== []) {
            $businessIds = array_map(static fn (BusinessUser $m): int => (int) $m->business_id, $memberships);
            $businesses = Business::find()
                ->where(['id' => $businessIds])
                ->indexBy('id')
                ->all();
            foreach ($memberships as $m) {
                $business = $businesses[$m->business_id] ?? null;
                if ($business !== null && (int) $business->status === Business::STATUS_ACTIVE) {
                    $active = $m;
                    break;
                }
            }
        }

        $activeBusinessId = $active !== null ? (int) $active->business_id : null;
        $activeRole = $active !== null ? (string) $active->role : null;

        $token = Jwt::issue($user->id, $activeBusinessId, $activeRole);

        return [
            'token' => $token,
            'user' => $user,
            'businesses' => $this->serializeMemberships($memberships),
            'active' => [
                'business_id' => $activeBusinessId,
                'role' => $activeRole,
            ],
        ];
    }

    /**
     * POST v1/auth/register {business:{name,slug,category?,phone?}, owner:{phone,name,password}}
     */
    public function actionRegister()
    {
        $businessInput = (array) $this->body('business', []);
        $ownerInput = (array) $this->body('owner', []);

        $ownerPhone = (string) (\common\helpers\Phone::normalize((string) ($ownerInput['phone'] ?? '')) ?? '');
        $ownerPassword = (string) ($ownerInput['password'] ?? '');

        if ($ownerPhone === '' || $ownerPassword === '') {
            throw new \yii\web\BadRequestHttpException('Telefon raqam va parol talab qilinadi.');
        }

        $transaction = Yii::$app->db->beginTransaction();
        try {
            $user = User::findOne(['phone' => $ownerPhone]);
            if ($user !== null) {
                // Reuse existing account only if credentials match.
                if ($user->status !== User::STATUS_ACTIVE || !$user->validatePassword($ownerPassword)) {
                    throw new ConflictHttpException('Bu telefon raqam bilan hisob allaqachon mavjud.');
                }
            } else {
                $user = new User();
                $user->phone = $ownerPhone;
                $user->name = (string) ($ownerInput['name'] ?? '');
                $user->status = User::STATUS_ACTIVE;
                $user->setPassword($ownerPassword);
                if (!$user->save()) {
                    $transaction->rollBack();
                    return $this->fail422($user);
                }
            }

            $business = new Business();
            $business->name = (string) ($businessInput['name'] ?? '');
            $business->slug = (string) ($businessInput['slug'] ?? '');
            $business->category = isset($businessInput['category']) ? (string) $businessInput['category'] : null;
            $business->phone = isset($businessInput['phone']) ? (string) $businessInput['phone'] : null;
            if (!$business->save()) {
                $transaction->rollBack();
                return $this->fail422($business);
            }

            $membership = new BusinessUser();
            $membership->business_id = $business->id;
            $membership->user_id = $user->id;
            $membership->role = Business::ROLE_OWNER;
            if (!$membership->save()) {
                $transaction->rollBack();
                return $this->fail422($membership);
            }

            $transaction->commit();
        } catch (ConflictHttpException $e) {
            $transaction->rollBack();
            throw $e;
        } catch (\Throwable $e) {
            $transaction->rollBack();
            throw new ServerErrorHttpException('Ro\'yxatdan o\'tishda xatolik yuz berdi.');
        }

        $token = Jwt::issue($user->id, (int) $business->id, Business::ROLE_OWNER);

        return $this->created([
            'token' => $token,
            'user' => $user,
            'business' => $business,
        ]);
    }

    /**
     * GET v1/auth/me
     */
    public function actionMe()
    {
        $user = $this->currentUser();
        if ($user === null) {
            throw new UnauthorizedHttpException();
        }

        return [
            'user' => $user,
            'active' => [
                'business_id' => $user->activeTenantId,
                'role' => $user->activeRole,
            ],
            'businesses' => $this->serializeMemberships($this->memberships($user->id)),
        ];
    }

    /**
     * POST v1/auth/switch/<businessId:\d+>
     */
    public function actionSwitch(int $businessId)
    {
        $user = $this->currentUser();
        if ($user === null) {
            throw new UnauthorizedHttpException();
        }

        $membership = BusinessUser::findOne(['business_id' => $businessId, 'user_id' => $user->id]);
        if ($membership === null) {
            throw new ForbiddenHttpException('Siz bu biznesning a\'zosi emassiz.');
        }

        $business = Business::findOne(['id' => $businessId]);
        if ($business === null || (int) $business->status !== Business::STATUS_ACTIVE) {
            throw new ForbiddenHttpException('Bu biznes faol emas.');
        }

        $token = Jwt::issue($user->id, (int) $membership->business_id, (string) $membership->role);

        return [
            'token' => $token,
            'active' => [
                'business_id' => (int) $membership->business_id,
                'role' => (string) $membership->role,
            ],
        ];
    }

    /**
     * @return BusinessUser[]
     */
    private function memberships(int $userId): array
    {
        return BusinessUser::find()
            ->where(['user_id' => $userId])
            ->orderBy(['id' => SORT_ASC])
            ->all();
    }

    /**
     * @param BusinessUser[] $memberships
     * @return array<int, array{id:int,name:string,slug:string,role:string}>
     */
    private function serializeMemberships(array $memberships): array
    {
        if ($memberships === []) {
            return [];
        }

        $businessIds = array_map(static fn (BusinessUser $m): int => (int) $m->business_id, $memberships);
        $businesses = Business::find()
            ->where(['id' => $businessIds])
            ->indexBy('id')
            ->all();

        $out = [];
        foreach ($memberships as $m) {
            $business = $businesses[$m->business_id] ?? null;
            if ($business === null) {
                continue;
            }
            $out[] = [
                'id' => (int) $business->id,
                'name' => $business->name,
                'slug' => $business->slug,
                'role' => (string) $m->role,
            ];
        }
        return $out;
    }
}
