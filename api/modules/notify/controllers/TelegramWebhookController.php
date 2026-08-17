<?php

namespace api\modules\notify\controllers;

use api\modules\notify\services\TelegramBotService;
use common\models\Business;
use common\models\TelegramLink;
use common\rest\Controller;
use Yii;

/**
 * Receives Telegram Bot API webhook updates for a specific business bot.
 *
 * The route carries the business id (`v1/webhooks/telegram/<biz>`) so we know
 * which bot token to reply with. On `/start` we greet the user and offer a
 * button that opens the business's catalog; `/start <token>` additionally binds
 * the chat to a client/user (see {@see TelegramLink}).
 *
 * The endpoint is public (Telegram calls it) and always answers 200 quickly so
 * Telegram does not retry; failures are logged, never surfaced.
 */
class TelegramWebhookController extends Controller
{
    protected function authOptional(): array
    {
        return ['update'];
    }

    public function actionUpdate(int $biz = 0): array
    {
        $business = $biz > 0 ? Business::findOne($biz) : null;

        // Authenticate the caller. For a per-business bot we verify Telegram's
        // secret header against the value we derived when calling setWebhook.
        if ($business !== null) {
            $expected = TelegramBotService::webhookSecret($biz);
            $provided = (string) Yii::$app->request->getHeaders()->get('X-Telegram-Bot-Api-Secret-Token', '');
            if (!hash_equals($expected, $provided)) {
                Yii::warning("Telegram webhook secret mismatch for business $biz; ignored.", 'notify');
                return ['ok' => true, 'ignored' => true];
            }
        } else {
            // Legacy no-id route: optional shared secret from the environment.
            $secret = getenv('TELEGRAM_WEBHOOK_SECRET');
            if ($secret !== false && $secret !== '') {
                $provided = (string) Yii::$app->request->getHeaders()->get('X-Telegram-Bot-Api-Secret-Token', '');
                if (!hash_equals((string) $secret, $provided)) {
                    return ['ok' => true, 'ignored' => true];
                }
            }
        }

        try {
            $update = Yii::$app->request->getBodyParams();
            $this->handle(is_array($update) ? $update : [], $business);
        } catch (\Throwable $e) {
            // Never fail the webhook — Telegram would retry indefinitely.
            Yii::error('Telegram webhook error: ' . $e->getMessage(), 'notify');
        }
        return ['ok' => true];
    }

    private function handle(array $update, ?Business $business): void
    {
        $message = $update['message'] ?? $update['edited_message'] ?? null;
        if (!is_array($message)) {
            return;
        }

        $chatId = isset($message['chat']['id']) ? (int) $message['chat']['id'] : 0;
        $text = isset($message['text']) ? trim((string) $message['text']) : '';
        if ($chatId === 0) {
            return;
        }

        // /start <token> binds this chat to a client/user.
        if (preg_match('/^\/start(?:@\w+)?\s+(\S+)/', $text, $m)) {
            $parsed = TelegramLink::parseStartToken($m[1]);
            if ($parsed !== null) {
                $this->linkChat($chatId, $parsed['client_id'], $parsed['user_id']);
                $this->reply($business, $chatId, $this->linkedText($business), true);
                return;
            }
            Yii::warning("Telegram /start with invalid token from chat $chatId.", 'notify');
        }

        // Plain /start (or any message) → greet and offer the catalog.
        if ($business !== null) {
            $this->reply($business, $chatId, $this->welcomeText($business), true);
        }
    }

    /** Send a reply through the business's own bot token, if configured. */
    private function reply(?Business $business, int $chatId, string $text, bool $withCatalog): void
    {
        if ($business === null) {
            return;
        }
        $token = (string) ($business->telegram_bot_token ?? '');
        if ($token === '') {
            return;
        }

        $markup = null;
        if ($withCatalog && $business->slug) {
            $markup = ['inline_keyboard' => [[
                ['text' => '🛍 Katalogni ochish', 'url' => TelegramBotService::publicUrl($business->slug)],
            ]]];
        }
        TelegramBotService::sendMessage($token, $chatId, $text, $markup);
    }

    private function welcomeText(Business $b): string
    {
        $name = htmlspecialchars((string) $b->name, ENT_QUOTES, 'UTF-8');
        $line = "Assalomu alaykum! <b>$name</b> ga xush kelibsiz.";
        if ($b->tagline) {
            $line .= "\n" . htmlspecialchars((string) $b->tagline, ENT_QUOTES, 'UTF-8');
        }
        return $line . "\n\nKatalogni ko‘rish va buyurtma berish uchun quyidagi tugmani bosing.";
    }

    private function linkedText(Business $b): string
    {
        $name = htmlspecialchars((string) $b->name, ENT_QUOTES, 'UTF-8');
        return "✅ Ulandingiz! Endi <b>$name</b> dan bildirishnomalarni shu yerda olasiz.";
    }

    /**
     * Create or update the (chat -> client/user) binding and mark it verified.
     * Idempotent: a repeated /start for the same chat + target does not duplicate.
     */
    private function linkChat(int $chatId, ?int $clientId, ?int $userId): void
    {
        $condition = ['tg_chat_id' => $chatId];
        if ($clientId !== null) {
            $condition['client_id'] = $clientId;
        }
        if ($userId !== null) {
            $condition['user_id'] = $userId;
        }

        $link = TelegramLink::find()->where($condition)->one();
        if ($link === null) {
            $link = new TelegramLink();
            $link->tg_chat_id = $chatId;
            $link->client_id = $clientId;
            $link->user_id = $userId;
        }
        $link->verified_at = time();

        if (!$link->save()) {
            Yii::warning('Failed to save TelegramLink: ' . json_encode($link->getErrors()), 'notify');
        }
    }
}
