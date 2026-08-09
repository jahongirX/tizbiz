<?php

namespace api\modules\loyalty\controllers;

use api\modules\loyalty\services\LoyaltyService;
use common\models\Client;
use common\models\LoyaltyAccount;
use common\models\LoyaltyTransaction;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;
use yii\web\UnprocessableEntityHttpException;

/**
 * Loyalty balances and manual earn/redeem. All actions require auth; earn and
 * redeem additionally require an owner/admin role.
 */
class LoyaltyController extends Controller
{
    private const RECENT_LEDGER = 20;

    /** GET /v1/loyalty/<clientId> — account balance plus recent ledger rows. */
    public function actionView(int $clientId): array
    {
        $businessId = Yii::$app->tenant->require();
        $this->requireClient($businessId, $clientId);

        $service = new LoyaltyService();
        $account = $service->findAccount($businessId, $clientId);

        // A GET must not have side effects: when no account exists yet, return a
        // zeroed representation instead of creating one. Account creation stays
        // in the earn/redeem paths only.
        if ($account === null) {
            $zeroed = new LoyaltyAccount();
            $zeroed->business_id = $businessId;
            $zeroed->client_id = $clientId;
            $zeroed->points = 0;
            $zeroed->cashback_tiyin = 0;
            return [
                'account' => $zeroed,
                'ledger' => [],
            ];
        }

        $ledger = LoyaltyTransaction::find()
            ->where(['account_id' => $account->id])
            ->orderBy(['id' => SORT_DESC])
            ->limit(self::RECENT_LEDGER)
            ->all();

        return [
            'account' => $account,
            'ledger' => $ledger,
        ];
    }

    /** POST /v1/loyalty/earn — credit cashback/points for a paid amount. */
    public function actionEarn(): array
    {
        $this->requireRole('business_owner', 'business_admin');
        $businessId = Yii::$app->tenant->require();

        $clientId = (int) $this->body('client_id');
        $amount = (int) $this->body('amount_tiyin');
        $ref = $this->body('ref');
        $ref = $ref !== null ? (string) $ref : null;

        if ($clientId <= 0) {
            throw new UnprocessableEntityHttpException('client_id talab qilinadi.');
        }
        if ($amount <= 0) {
            throw new UnprocessableEntityHttpException('amount_tiyin musbat bo\'lishi kerak.');
        }
        $this->requireClient($businessId, $clientId);

        $account = (new LoyaltyService())->earn($businessId, $clientId, $amount, $ref);
        return ['account' => $account];
    }

    /** POST /v1/loyalty/redeem — spend cashback. */
    public function actionRedeem(): array
    {
        $this->requireRole('business_owner', 'business_admin');
        $businessId = Yii::$app->tenant->require();

        $clientId = (int) $this->body('client_id');
        $amount = (int) $this->body('amount_tiyin');

        if ($clientId <= 0) {
            throw new UnprocessableEntityHttpException('client_id talab qilinadi.');
        }
        if ($amount <= 0) {
            throw new UnprocessableEntityHttpException('amount_tiyin musbat bo\'lishi kerak.');
        }
        $this->requireClient($businessId, $clientId);

        $account = (new LoyaltyService())->redeem($businessId, $clientId, $amount);
        return ['account' => $account];
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
