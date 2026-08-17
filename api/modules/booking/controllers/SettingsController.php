<?php

namespace api\modules\booking\controllers;

use api\modules\notify\services\TelegramBotService;
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

        // Business profile: name (required — blank is rejected), phone, tagline.
        if (($v = $this->body('name')) !== null) {
            $model->name = trim((string) $v);
        }
        if (array_key_exists('phone', $this->body())) {
            $v = $this->body('phone');
            $model->phone = ($v === null || trim((string) $v) === '') ? null : trim((string) $v);
        }
        if (array_key_exists('tagline', $this->body())) {
            $v = $this->body('tagline');
            $model->tagline = ($v === null || trim((string) $v) === '') ? null : trim((string) $v);
        }

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
        // Branding: logo / cover URLs (empty string clears) + brand colors.
        foreach (['logo', 'cover', 'brand_color', 'brand_color_2'] as $attr) {
            if (array_key_exists($attr, $this->body())) {
                $v = $this->body($attr);
                $model->$attr = ($v === null || trim((string) $v) === '') ? null : trim((string) $v);
            }
        }
        // Telegram bot connect / disconnect.
        //  - empty token -> disconnect: drop the webhook on Telegram, clear creds
        //  - a token     -> validate live via getMe (reject 422 if bad) and store
        //                   it; the webhook is (re)registered after save() below.
        $connect = false;
        $tok = $this->body('telegram_bot_token');
        if ($tok !== null) {
            $tok = trim((string) $tok);
            if ($tok === '') {
                $old = (string) ($model->telegram_bot_token ?? '');
                if ($old !== '') {
                    TelegramBotService::deleteWebhook($old);
                }
                $model->telegram_bot_token = null;
                $model->telegram_bot_username = null;
            } else {
                $me = TelegramBotService::getMe($tok);
                if (!$me['ok']) {
                    $model->addError('telegram_bot_token', 'Bot token noto‘g‘ri: ' . ($me['error'] ?? 'Telegram bilan bog‘lanib bo‘lmadi'));
                    return $this->fail422($model);
                }
                $model->telegram_bot_token = $tok;
                $model->telegram_bot_username = $me['username'];
                $connect = true;
            }
        }

        if (!$model->save()) {
            return $this->fail422($model);
        }

        // Register/refresh the webhook only after the token is persisted, so a
        // failed save never leaves a live webhook pointing at unsaved state.
        $webhook = null;
        if ($connect) {
            $webhook = TelegramBotService::setWebhook((string) $model->telegram_bot_token, (int) $model->id);
            // Persistent menu button that opens the catalog Mini App.
            if ($model->slug) {
                TelegramBotService::setChatMenuButton(
                    (string) $model->telegram_bot_token,
                    '🛍 Katalog',
                    TelegramBotService::publicUrl((string) $model->slug)
                );
            }
        }

        return $this->payload($model, $webhook);
    }

    private function payload(Business $b, ?array $webhook = null): array
    {
        $data = [
            'name' => $b->name,
            'phone' => $b->phone,
            'tagline' => $b->tagline,
            'slug' => $b->slug,
            'online_booking_enabled' => (bool) $b->online_booking_enabled,
            'booking_lead_min' => (int) $b->booking_lead_min,
            'booking_horizon_days' => (int) $b->booking_horizon_days,
            'logo' => $b->logo,
            'cover' => $b->cover,
            'brand_color' => $b->brand_color,
            'brand_color_2' => $b->brand_color_2,
            // Never echo the raw token back to the client — expose only status.
            'telegram_connected' => $b->telegram_bot_token !== null && $b->telegram_bot_token !== '',
            'telegram_bot_username' => $b->telegram_bot_username,
        ];
        // Present only right after a (re)connect: did webhook registration stick?
        if ($webhook !== null) {
            $data['telegram_webhook_ok'] = (bool) $webhook['ok'];
            $data['telegram_error'] = $webhook['error'] ?? null;
        }
        return $data;
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
