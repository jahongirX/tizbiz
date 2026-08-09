<?php

namespace api\modules\loyalty\controllers;

use api\modules\loyalty\services\LoyaltyService;
use common\models\Client;
use common\models\Referral;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;
use yii\web\UnprocessableEntityHttpException;

/**
 * Referral tracking. Listing/creating a referral is open to any authed user;
 * granting a bonus requires owner/admin.
 */
class ReferralController extends Controller
{
    /** GET /v1/referrals — referrals for the active business. */
    public function actionIndex(): array
    {
        return Referral::find()
            ->orderBy(['id' => SORT_DESC])
            ->all();
    }

    /** POST /v1/referrals { referrer_client_id, referred_client_id? } */
    public function actionCreate()
    {
        $businessId = Yii::$app->tenant->require();

        $referrer = (int) $this->body('referrer_client_id');
        if ($referrer <= 0) {
            throw new UnprocessableEntityHttpException('referrer_client_id talab qilinadi.');
        }
        $this->requireClient($businessId, $referrer);

        $referred = $this->body('referred_client_id');
        $referredId = $referred !== null && $referred !== '' ? (int) $referred : null;
        if ($referredId !== null) {
            $this->requireClient($businessId, $referredId);
        }

        $referral = new Referral();
        $referral->business_id = $businessId;
        $referral->referrer_client_id = $referrer;
        $referral->referred_client_id = $referredId;
        $referral->bonus_status = Referral::STATUS_PENDING;
        if (!$referral->save()) {
            return $this->fail422($referral);
        }
        return $this->created($referral);
    }

    /** POST /v1/referrals/<id>/credit — grant the referral bonus once (idempotent). */
    public function actionCredit(int $id): Referral
    {
        $this->requireRole('business_owner', 'business_admin');
        $businessId = Yii::$app->tenant->require();

        return (new LoyaltyService())->creditReferral($businessId, $id);
    }

    /** Ensure the client exists within the active business. */
    private function requireClient(int $businessId, int $clientId): void
    {
        $exists = Client::find()
            ->where(['id' => $clientId, 'business_id' => $businessId])
            ->exists();
        if (!$exists) {
            throw new NotFoundHttpException('Mijoz topilmadi.');
        }
    }
}
