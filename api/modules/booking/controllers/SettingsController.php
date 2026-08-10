<?php

namespace api\modules\booking\controllers;

use common\models\Business;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * Online-booking settings for the active business.
 * Read: any authed member. Write: owner/admin.
 */
class SettingsController extends Controller
{
    public function actionView(): array
    {
        return $this->payload($this->business());
    }

    public function actionUpdate(): array
    {
        $this->requireRole('business_owner', 'business_admin');

        $model = $this->business();

        // Slug (public subdomain). The Business `unique` rule excludes self, so
        // saving the same slug is a no-op; a taken one returns 422.
        if (($v = $this->body('slug')) !== null) {
            $model->slug = strtolower(trim((string) $v));
        }
        if (($v = $this->body('online_booking_enabled')) !== null) {
            $model->online_booking_enabled = (bool) $v;
        }
        if (($v = $this->body('booking_lead_min')) !== null) {
            $model->booking_lead_min = (int) $v;
        }
        if (($v = $this->body('booking_horizon_days')) !== null) {
            $model->booking_horizon_days = (int) $v;
        }
        // Telegram bot token: empty string clears it; otherwise the model rule
        // validates the @BotFather token format.
        $tok = $this->body('telegram_bot_token');
        if ($tok !== null) {
            $tok = trim((string) $tok);
            if ($tok === '') {
                $model->telegram_bot_token = null;
                $model->telegram_bot_username = null;
            } else {
                $model->telegram_bot_token = $tok;
            }
        }

        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $this->payload($model);
    }

    private function payload(Business $b): array
    {
        return [
            'slug' => $b->slug,
            'online_booking_enabled' => (bool) $b->online_booking_enabled,
            'booking_lead_min' => (int) $b->booking_lead_min,
            'booking_horizon_days' => (int) $b->booking_horizon_days,
            // Never echo the raw token back to the client — expose only status.
            'telegram_connected' => $b->telegram_bot_token !== null && $b->telegram_bot_token !== '',
            'telegram_bot_username' => $b->telegram_bot_username,
        ];
    }

    private function business(): Business
    {
        $model = Business::findOne(Yii::$app->tenant->require());
        if ($model === null) {
            throw new NotFoundHttpException('Biznes topilmadi.');
        }
        return $model;
    }
}
