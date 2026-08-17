<?php

namespace api\modules\notify\controllers;

use common\helpers\TelegramWebApp;
use common\models\Business;
use common\models\Order;
use common\models\TelegramLink;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;
use yii\web\UnauthorizedHttpException;

/**
 * Endpoints the catalog Mini App calls while running inside Telegram. The client
 * authenticates every call with the signed `initData` (verified against the
 * business's bot token) instead of a JWT — so we know the Telegram user without
 * a separate login.
 */
class WebappController extends Controller
{
    protected function authOptional(): array
    {
        return ['auth', 'orders'];
    }

    /**
     * POST v1/telegram/webapp-auth  { slug, init_data }
     * Verify the Mini App session and return the Telegram user plus any phone
     * they previously shared with this bot (for pre-filling checkout).
     */
    public function actionAuth(): array
    {
        [, $data] = $this->authenticate(
            (string) $this->body('slug', ''),
            (string) $this->body('init_data', '')
        );

        $user = $data['user'];
        $tgUserId = (int) $user['id'];
        $link = TelegramLink::find()
            ->where(['tg_user_id' => $tgUserId])
            ->andWhere(['not', ['phone' => null]])
            ->orderBy(['id' => SORT_DESC])
            ->one();

        return [
            'user' => [
                'id' => $tgUserId,
                'first_name' => $user['first_name'] ?? null,
                'last_name' => $user['last_name'] ?? null,
                'username' => $user['username'] ?? null,
            ],
            'phone' => $link?->phone,
            'name' => $link?->first_name ?: ($user['first_name'] ?? null),
        ];
    }

    /**
     * GET v1/telegram/orders?slug=...   (initData in X-Telegram-Init-Data header)
     * The signed-in Telegram user's own order history for this business.
     */
    public function actionOrders(): array
    {
        $initData = (string) Yii::$app->request->getHeaders()->get('X-Telegram-Init-Data', '');
        [$business, $data] = $this->authenticate(
            (string) Yii::$app->request->get('slug', ''),
            $initData
        );

        $orders = Order::find()
            ->with('items')
            ->where(['business_id' => $business->id, 'tg_user_id' => (int) $data['user']['id']])
            ->orderBy(['id' => SORT_DESC])
            ->limit(50)
            ->all();

        return ['items' => $orders];
    }

    /**
     * Resolve the business by slug and verify initData against its bot token.
     * @return array{0: Business, 1: array}
     */
    private function authenticate(string $slug, string $initData): array
    {
        $business = Business::find()
            ->where(['slug' => $slug, 'status' => Business::STATUS_ACTIVE])
            ->one();
        if ($business === null) {
            throw new NotFoundHttpException('Biznes topilmadi.');
        }
        $token = (string) ($business->telegram_bot_token ?? '');
        if ($token === '') {
            throw new UnauthorizedHttpException('Bu biznesda Telegram bot ulanmagan.');
        }
        $data = TelegramWebApp::verify($initData, $token);
        if ($data === null) {
            throw new UnauthorizedHttpException('Telegram sessiyasi yaroqsiz.');
        }
        return [$business, $data];
    }
}
